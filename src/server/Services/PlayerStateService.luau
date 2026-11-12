--!strict
--[[
	PlayerStateService — replicates each player's PlayerState snapshot to that player only.

	  - Pushes PlayerStateChanged whenever data loads or changes.
	  - Answers GetPlayerState (validated, rate-limited) so a client that boots late can sync.

	The snapshot is a projection: clients see only what toState() exposes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Guard = require(ReplicatedStorage.Shared.Utils.Guard)
local PlayerStateTypes = require(ReplicatedStorage.Shared.Types.PlayerState)
local Server = ServerScriptService.Server
local PlayerDataSchema = require(Server.Systems.Persistence.PlayerDataSchema)
local PlayerDataService = require(Server.Services.PlayerDataService)
local ServerConfig = require(Server.ServerConfig)
local ServerNet = require(Server.Systems.ServerNet)

type PlayerState = PlayerStateTypes.PlayerState

local PlayerStateService = {
	name = "PlayerStateService",
}

function PlayerStateService.toState(data: PlayerDataSchema.PlayerData): PlayerState
	return {
		coins = data.coins,
		collectiblesCollected = data.stats.collectiblesCollected,
	}
end

function PlayerStateService.init(_self: any)
	ServerNet.setup()

	ServerNet.onInvoke("GetPlayerState", {
		-- No arguments accepted: any payload is rejected.
		validate = Guard.tuple(),
		rateLimit = ServerConfig.Network.GetPlayerStateRateLimit,
	}, function(player: Player): PlayerState?
		local data = PlayerDataService.get(player)
		return if data then PlayerStateService.toState(data) else nil
	end)
end

function PlayerStateService.start(_self: any)
	local function push(player: Player, data: PlayerDataSchema.PlayerData)
		ServerNet.fireClient("PlayerStateChanged", player, PlayerStateService.toState(data))
	end
	PlayerDataService.loaded:connect(push)
	PlayerDataService.changed:connect(push)
end

return PlayerStateService
