--!strict
--[[
	PlayerStateService — replicates each player's PlayerState snapshot to that player only.

	  - Changes (data, carried shards) mark the player dirty; a single loop pushes at most every
	    StatePushIntervalSeconds, so per-second income ticks don't flood the network.
	  - GetPlayerState (validated, rate-limited) lets a client that boots late sync immediately.

	The snapshot is a projection: clients see only what toState() exposes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Guard = require(ReplicatedStorage.Shared.Utils.Guard)
local PlayerStateTypes = require(ReplicatedStorage.Shared.Types.PlayerState)
local Server = ServerScriptService.Server
local PlayerDataSchema = require(Server.Systems.Persistence.PlayerDataSchema)
local PlayerDataService = require(Server.Services.PlayerDataService)
local RaidService = require(Server.Services.RaidService)
local ServerConfig = require(Server.ServerConfig)
local ServerNet = require(Server.Systems.ServerNet)
local ShardService = require(Server.Services.ShardService)

type PlayerState = PlayerStateTypes.PlayerState

local PlayerStateService = {
	name = "PlayerStateService",
}

local dirty: { [Player]: boolean } = {}

function PlayerStateService.toState(
	data: PlayerDataSchema.PlayerData,
	carrying: number,
	carryingStarling: number
): PlayerState
	local level, progress, goal = Economy.levelFromXp(data.xp)
	local indexCount = Economy.indexCount(data.discovered)
	local discovered = {}
	for key, found in data.discovered do
		if found then
			table.insert(discovered, key)
		end
	end
	local now = os.time()
	local canClaim, wait = Economy.dailyStatus(data.dailyLastClaim, now)
	return {
		coins = data.coins,
		vault = data.vault,
		incomePerSecond = Economy.baseIncome(data),
		xp = data.xp,
		level = level,
		levelProgress = progress,
		levelGoal = goal,
		rebirths = data.rebirths,
		multiplier = Economy.multiplier(data.rebirths, indexCount),
		rebirthCost = Economy.rebirthCost(data.rebirths),
		zoneTier = data.zoneTier,
		upgrades = {
			speed = data.upgrades.speed,
			carry = data.upgrades.carry,
			magnet = data.upgrades.magnet,
			slots = data.upgrades.slots,
		},
		carrying = carrying,
		capacity = Economy.capacity(data.upgrades.carry),
		carryingStarling = carryingStarling,
		starlings = #data.starlings,
		slots = Economy.slots(data.upgrades.slots),
		shardsDelivered = data.stats.shardsDelivered,
		bumpsLanded = data.stats.bumpsLanded,
		cometsCaught = data.stats.cometsCaught,
		discovered = discovered,
		indexCount = indexCount,
		dailyNextClaimAt = if canClaim then 0 else now + wait,
		dailyNextDay = Economy.nextDailyDay(data.dailyLastClaim, data.dailyStreak, now),
	}
end

local function snapshot(player: Player): PlayerState?
	local data = PlayerDataService.peek(player)
	return if data
		then PlayerStateService.toState(data, ShardService.getCarryCount(player), RaidService.carriedRarity(player))
		else nil
end

local function markDirty(player: Player)
	dirty[player] = true
end

function PlayerStateService.init(_self: any)
	ServerNet.onInvoke("GetPlayerState", {
		-- No arguments accepted: any payload is rejected.
		validate = Guard.tuple(),
		rateLimit = ServerConfig.Network.GetPlayerStateRateLimit,
	}, function(player: Player): PlayerState?
		return snapshot(player)
	end)
end

function PlayerStateService.start(_self: any)
	PlayerDataService.loaded:connect(markDirty)
	PlayerDataService.changed:connect(markDirty)
	ShardService.carryChanged:connect(markDirty)
	RaidService.changed:connect(markDirty)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)

	while true do
		task.wait(ServerConfig.Network.StatePushIntervalSeconds)
		for player in dirty do
			dirty[player] = nil
			if player.Parent == Players then
				local state = snapshot(player)
				if state then
					ServerNet.fireClient("PlayerStateChanged", player, state)
				end
			end
		end
	end
end

return PlayerStateService
