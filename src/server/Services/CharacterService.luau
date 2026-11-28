--!strict
--[[
	CharacterService — applies movement stats to characters: walk speed from the Speed upgrade,
	slowed down by every shard carried, times named modifiers (stolen Starling, escape boost).
	Server-set WalkSpeed replicates to the owning client.

	API: targetSpeed(player), setModifier(player, key, factor?), boost(player, key, factor, seconds).
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

-- Extra multiplicative speed factors set by other services (e.g. carrying a stolen Starling).
local modifiers: { [Player]: { [string]: number } } = {}
-- Latest timed boost per player and key: an older boost's timer never clears a newer one.
local boostTokens: { [Player]: { [string]: number } } = {}

function CharacterService.targetSpeed(player: Player): number
	local data = PlayerDataService.peek(player)
	local base = if data then Economy.walkSpeed(data.upgrades.speed) else GameConfig.Economy.BaseWalkSpeed
	local speed = base * Economy.carrySpeedFactor(ShardService.getCarryCount(player))
	local factors = modifiers[player]
	if factors then
		for _, factor in factors do
			speed *= factor
		end
	end
	return speed
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

-- Sets (or clears with nil) a named speed factor and re-applies the walk speed.
function CharacterService.setModifier(player: Player, key: string, factor: number?)
	local set = modifiers[player] or {}
	set[key] = factor
	modifiers[player] = set
	apply(player)
end

-- Applies `factor` under `key` for `seconds`, then clears it (unless boosted again meanwhile).
function CharacterService.boost(player: Player, key: string, factor: number, seconds: number)
	local tokens = boostTokens[player] or {}
	boostTokens[player] = tokens
	local token = (tokens[key] or 0) + 1
	tokens[key] = token
	CharacterService.setModifier(player, key, factor)
	task.delay(seconds, function()
		local current = boostTokens[player]
		if current and current[key] == token and player.Parent ~= nil then
			CharacterService.setModifier(player, key, nil)
		end
	end)
end

function CharacterService.init(_self: any)
	-- Event-driven: everything is wired in start().
end

function CharacterService.start(_self: any)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		modifiers[player] = nil
		boostTokens[player] = nil
	end)
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
