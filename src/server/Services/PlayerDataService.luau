--!strict
--[[
	PlayerDataService — owns every player's persisted data for the lifetime of their session.

	Public API (server only):
	  PlayerDataService.isLoaded(player) -> boolean
	  PlayerDataService.get(player) -> PlayerData?            -- deep copy, read-only by contract
	  PlayerDataService.update(player, mutator) -> boolean    -- the ONLY way to change data
	  PlayerDataService.loaded:connect(fn(player, data))
	  PlayerDataService.changed:connect(fn(player, data))

	Lifecycle: load + lock on join (kick if impossible), autosave on an interval, save + release on
	leave, flush everything on shutdown (BindToClose). See docs/ARCHITECTURE.md#persistence.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local Signal = require(ReplicatedStorage.Shared.Utils.Signal)

local Persistence = ServerScriptService.Server.Systems.Persistence
local InMemoryStore = require(Persistence.InMemoryStore)
local PlayerDataSchema = require(Persistence.PlayerDataSchema)
local RobloxDataStore = require(Persistence.RobloxDataStore)
local ServerConfig = require(ServerScriptService.Server.ServerConfig)
local SessionStore = require(Persistence.SessionStore)
local StoreTypes = require(Persistence.StoreTypes)

type PlayerData = PlayerDataSchema.PlayerData

type Profile = {
	data: PlayerData,
	dirty: boolean,
}

local config = ServerConfig.Persistence
local log = Log.scope("PlayerDataService")

local KICK_MESSAGE = "We could not load your progress safely. Please rejoin in a moment."

local PlayerDataService = {
	name = "PlayerDataService",
	loaded = Signal.new() :: Signal.Signal<Player, PlayerData>,
	changed = Signal.new() :: Signal.Signal<Player, PlayerData>,
}

local sessionStore: SessionStore.SessionStore
local profiles: { [Player]: Profile } = {}
-- Users whose previous session on this server is still being saved/released.
local releasing: { [number]: boolean } = {}
local shuttingDown = false

local function keyFor(player: Player): string
	return config.KeyPrefix .. tostring(player.UserId)
end

local function createStore(): StoreTypes.Store
	if RunService:IsStudio() and config.UseInMemoryStoreInStudio then
		log:info("Studio session: using InMemoryStore (progress is not persisted)")
		return InMemoryStore.new() :: any
	end
	return RobloxDataStore.new(config.DataStoreName, {
		maxAttempts = config.RequestMaxAttempts,
		retryBaseSeconds = config.RequestRetryBaseSeconds,
	}) :: any
end

local function saveProfile(player: Player, profile: Profile, release: boolean): boolean
	local ok, failure, message = sessionStore:save(keyFor(player), profile.data, release, { player.UserId })
	if ok then
		profile.dirty = false
		return true
	end
	log:error(`save failed for {player.UserId} ({failure}): {message}`)
	return false
end

local function onPlayerAdded(player: Player)
	-- Wait for a previous session of the same user on THIS server to finish releasing.
	local waited = 0
	while releasing[player.UserId] and waited < 30 do
		waited += task.wait(0.25)
	end

	local ok, result, message = sessionStore:load(keyFor(player), { player.UserId })
	if not ok then
		log:error(`load failed for {player.UserId} ({result}): {message}`)
		if player.Parent == Players then
			player:Kick(KICK_MESSAGE)
		end
		return
	end

	local data = result :: PlayerData
	data.stats.sessions += 1
	local profile: Profile = { data = data, dirty = true }

	if player.Parent ~= Players then
		-- The player left while we were loading: release immediately, keep the session count.
		saveProfile(player, profile, true)
		return
	end

	profiles[player] = profile
	PlayerDataService.loaded:fire(player, PlayerDataSchema.deepCopy(data))
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile == nil then
		return
	end
	profiles[player] = nil
	releasing[player.UserId] = true
	saveProfile(player, profile, true)
	releasing[player.UserId] = nil
end

function PlayerDataService.init(_self: any)
	local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
	sessionStore = SessionStore.new({
		store = createStore(),
		jobId = jobId,
		lockExpirySeconds = config.SessionLockExpirySeconds,
		maxLoadAttempts = config.MaxLoadAttempts,
		retryDelaySeconds = config.LoadRetryDelaySeconds,
		now = os.time,
		sleep = function(seconds: number)
			task.wait(seconds)
		end,
	})
end

function PlayerDataService.start(_self: any)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		shuttingDown = true
		local pending = 0
		for player, profile in profiles do
			pending += 1
			task.spawn(function()
				saveProfile(player, profile, true)
				pending -= 1
			end)
		end
		table.clear(profiles)
		-- BindToClose gives us ~30 s in total; stop waiting a little before that.
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	while not shuttingDown do
		task.wait(config.AutosaveIntervalSeconds)
		for player, profile in profiles do
			-- Autosave also refreshes the session lock, even when nothing changed.
			task.spawn(saveProfile, player, profile, false)
		end
	end
end

function PlayerDataService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function PlayerDataService.get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then PlayerDataSchema.deepCopy(profile.data) else nil
end

--[[
	Applies `mutator` to a copy of the player's data, validates the result and commits it
	atomically. Returns false (and changes nothing) if data is not loaded, the mutator errors, or
	the result is invalid. The mutator must not yield.
]]
function PlayerDataService.update(player: Player, mutator: (data: PlayerData) -> ()): boolean
	local profile = profiles[player]
	if profile == nil then
		return false
	end
	local draft = PlayerDataSchema.deepCopy(profile.data)
	local ok, err = pcall(mutator :: any, draft)
	if not ok then
		log:error(`update mutator failed for {player.UserId}: {err}`)
		return false
	end
	local valid, reason = PlayerDataSchema.validate(draft)
	if not valid then
		log:error(`update rejected for {player.UserId}: {reason}`)
		return false
	end
	profile.data = draft
	profile.dirty = true
	PlayerDataService.changed:fire(player, PlayerDataSchema.deepCopy(draft))
	return true
end

return PlayerDataService
