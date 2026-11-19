--!strict
--[[
	BumpService — the playful PvP: bump a nearby carrier to make them drop their top shard.

	The client only says "bump" (no target, no position). The server picks the nearest valid
	carrier in range (ShardRules.bumpTarget), enforces the attacker cooldown, the victim's
	immunity and the safe zones (bases), then drops the shard and asks the victim's client to
	apply the knockback (characters are physically owned by their client).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Guard = require(ReplicatedStorage.Shared.Utils.Guard)
local Server = ServerScriptService.Server
local BaseService = require(Server.Services.BaseService)
local Notifier = require(Server.Systems.Notifier)
local PlayerDataService = require(Server.Services.PlayerDataService)
local ServerConfig = require(Server.ServerConfig)
local ServerNet = require(Server.Systems.ServerNet)
local ShardRules = require(Server.Systems.Shards.ShardRules)
local ShardService = require(Server.Services.ShardService)

local bump = GameConfig.Bump

local BumpService = {
	name = "BumpService",
}

local lastBumpAt: { [Player]: number } = {}
local immuneUntil: { [number]: number } = {}

local function rootOf(player: Player): (BasePart?, boolean)
	local character = player.Character
	if character == nil then
		return nil, false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local alive = humanoid ~= nil and humanoid.Health > 0
	return if root and root:IsA("BasePart") then root else nil, alive
end

local function onBump(attacker: Player)
	local now = os.clock()
	local attackerRoot, attackerAlive = rootOf(attacker)
	if
		attackerRoot == nil or not ShardRules.canBump(lastBumpAt[attacker], now, bump.CooldownSeconds, attackerAlive)
	then
		return
	end

	local candidates: { ShardRules.BumpCandidate } = {}
	local rootsByUserId: { [number]: BasePart } = {}
	for _, other in Players:GetPlayers() do
		local root, alive = rootOf(other)
		if root then
			rootsByUserId[other.UserId] = root
			table.insert(candidates, {
				userId = other.UserId,
				position = root.Position,
				alive = alive,
				carrying = ShardService.getCarryCount(other),
				immuneUntil = immuneUntil[other.UserId] or 0,
				inSafeZone = BaseService.isInAnyPlot(root.Position),
			})
		end
	end

	local targetId = ShardRules.bumpTarget(attacker.UserId, attackerRoot.Position, candidates, now, bump.Range)
	local target = if targetId then Players:GetPlayerByUserId(targetId) else nil
	local targetRoot = if targetId then rootsByUserId[targetId] else nil
	if target == nil or targetRoot == nil then
		-- A miss only costs a short cooldown.
		lastBumpAt[attacker] = now - bump.CooldownSeconds + 0.4
		return
	end

	lastBumpAt[attacker] = now
	immuneUntil[target.UserId] = now + bump.ImmunitySeconds

	local flat = (targetRoot.Position - attackerRoot.Position) * Vector3.new(1, 0, 1)
	local direction = if flat.Magnitude > 0.05 then flat.Unit else attackerRoot.CFrame.LookVector
	ShardService.dropTop(target, targetRoot.Position + direction * 3, target.UserId)

	ServerNet.fireClient("Knockback", target, direction)
	ServerNet.fireAllClients("WorldEvent", { kind = "bump", position = targetRoot.Position })
	PlayerDataService.update(attacker, function(draft)
		draft.stats.bumpsLanded += 1
	end)
	Notifier.send(attacker, `💥 You bumped {target.DisplayName}!`, "success")
	Notifier.send(target, `💥 {attacker.DisplayName} bumped you: shard dropped!`, "warning")
end

function BumpService.init(_self: any)
	ServerNet.onEvent("RequestBump", {
		validate = Guard.tuple(),
		rateLimit = ServerConfig.Network.RequestBumpRateLimit,
	}, onBump)
end

function BumpService.start(_self: any)
	Players.PlayerRemoving:Connect(function(player)
		lastBumpAt[player] = nil
		immuneUntil[player.UserId] = nil
	end)
end

return BumpService
