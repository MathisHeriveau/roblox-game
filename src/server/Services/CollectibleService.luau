--!strict
--[[
	CollectibleService — server-authoritative pickups.

	Detection uses server-side Touched events; the client never reports "I collected X". Every
	pickup is re-validated on the server (CollectibleRules): item active, character alive, data
	loaded, distance sanity check, per-player cooldown. Rewards come from GameConfig only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Cleaner = require(ReplicatedStorage.Shared.Utils.Cleaner)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Log = require(ReplicatedStorage.Shared.Utils.Log)
local Server = ServerScriptService.Server
local CollectibleRules = require(Server.Systems.Collectibles.CollectibleRules)
local MapService = require(Server.Services.MapService)
local PlayerDataService = require(Server.Services.PlayerDataService)

local settings = GameConfig.Collectibles
local log = Log.scope("CollectibleService")

local CollectibleService = {
	name = "CollectibleService",
}

local cleaner = Cleaner.new()
local lastPickupAt: { [Player]: number } = {}

local function setActive(part: BasePart, active: boolean)
	part:SetAttribute("Active", active)
	part.Transparency = if active then 0 else 1
	part.CanTouch = active
end

local function resolvePlayer(hit: BasePart): (Player?, Humanoid?, BasePart?)
	local character = hit:FindFirstAncestorOfClass("Model")
	if character == nil then
		return nil, nil, nil
	end
	local player = Players:GetPlayerFromCharacter(character)
	if player == nil then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return player, humanoid, root
end

local function onTouched(part: BasePart, hit: BasePart)
	local player, humanoid, root = resolvePlayer(hit)
	if player == nil or humanoid == nil or root == nil then
		return
	end

	local now = os.clock()
	local allowed, reason = CollectibleRules.canCollect({
		itemActive = part:GetAttribute("Active") == true,
		playerAlive = humanoid.Health > 0,
		dataLoaded = PlayerDataService.isLoaded(player),
		distance = (root.Position - part.Position).Magnitude,
		maxDistance = settings.MaxPickupDistance,
		now = now,
		lastPickupAt = lastPickupAt[player],
		cooldownSeconds = settings.PlayerCooldownSeconds,
	})
	if not allowed then
		if reason == "TooFar" or reason == "InvalidDistance" then
			log:warn(`suspicious pickup by {player.UserId}: {reason}`)
		end
		return
	end

	-- Deactivate before awarding so a second touch in the same frame cannot double-collect.
	setActive(part, false)
	lastPickupAt[player] = now

	local awarded = PlayerDataService.update(player, function(data)
		data.coins += settings.Value
		data.stats.collectiblesCollected += 1
	end)
	if not awarded then
		setActive(part, true)
		return
	end

	task.delay(settings.RespawnSeconds, function()
		if part.Parent ~= nil then
			setActive(part, true)
		end
	end)
end

function CollectibleService.init(_self: any)
	-- No synchronous setup needed: parts are bound in start(), after MapService.init built them.
end

function CollectibleService.start(_self: any)
	for _, part in MapService.getCollectibleParts() do
		cleaner:add(part.Touched:Connect(function(hit: BasePart)
			onTouched(part, hit)
		end))
	end
	cleaner:add(Players.PlayerRemoving:Connect(function(player: Player)
		lastPickupAt[player] = nil
	end))
end

return CollectibleService
