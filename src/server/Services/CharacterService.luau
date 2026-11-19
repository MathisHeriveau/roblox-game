--!strict
--[[
	CharacterService — applies movement stats to characters: walk speed from the Speed upgrade,
	slowed down by every shard carried. Server-set WalkSpeed replicates to the owning client.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Server = ServerScriptService.Server
local PlayerDataService = require(Server.Services.PlayerDataService)
local ShardService = require(Server.Services.ShardService)

local CharacterService = {
	name = "CharacterService",
}

function CharacterService.targetSpeed(player: Player): number
	local data = PlayerDataService.peek(player)
	local base = if data then Economy.walkSpeed(data.upgrades.speed) else GameConfig.Economy.BaseWalkSpeed
	return base * Economy.carrySpeedFactor(ShardService.getCarryCount(player))
end

local function apply(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local speed = CharacterService.targetSpeed(player)
	if math.abs(humanoid.WalkSpeed - speed) > 0.01 then
		humanoid.WalkSpeed = speed
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		apply(player)
	end)
	if player.Character then
		apply(player)
	end
end

function CharacterService.init(_self: any)
	-- Event-driven: everything is wired in start().
end

function CharacterService.start(_self: any)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	PlayerDataService.loaded:connect(function(player)
		apply(player)
	end)
	PlayerDataService.changed:connect(function(player)
		apply(player)
	end)
	ShardService.carryChanged:connect(function(player)
		apply(player)
	end)
end

return CharacterService
