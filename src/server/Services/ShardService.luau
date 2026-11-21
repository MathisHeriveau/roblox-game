--!strict
--[[
	ShardService — the life of every star shard: spawn → land → pickup → carry → drop | deliver.

	Server-authoritative by design:
	  - pickups are detected by the server (distance from the character, 10 Hz), never reported by
	    clients; zone locks, capacity and drop-protection are checked by ShardRules;
	  - delivery happens when a carrier stands in their own base; each shard's trip must be
	    physically plausible (anti-teleport), otherwise it is discarded and logged;
	  - carried shards fall to the ground on death, on bumps and when the player leaves.

	Public API (server only):
	  ShardService.spawnAt(tile, rarity, shiny, isComet, delaySeconds) -> number?
	  ShardService.isTileFree(tile) -> boolean
	  ShardService.getCarryCount(player) -> number
	  ShardService.dropTop(player, position, blockUserId) -> boolean
	  ShardService.carryChanged:connect(fn(player, count))
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Format = require(ReplicatedStorage.Shared.Game.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Log = require(ReplicatedStorage.Shared.Utils.Log)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Signal = require(ReplicatedStorage.Shared.Utils.Signal)
local Server = ServerScriptService.Server
local BaseService = require(Server.Services.BaseService)
local MapLayout = require(Server.Systems.Map.MapLayout)
local MapService = require(Server.Services.MapService)
local Notifier = require(Server.Systems.Notifier)
local PlayerDataService = require(Server.Services.PlayerDataService)
local ServerConfig = require(Server.ServerConfig)
local ShardBuilder = require(Server.Systems.Shards.ShardBuilder)
local ShardRules = require(Server.Systems.Shards.ShardRules)

local events = GameConfig.Events
local carry = GameConfig.Carry
local log = Log.scope("ShardService")

type ShardState = {
	id: number,
	parts: ShardBuilder.ShardParts,
	rarity: number,
	shiny: boolean,
	isComet: boolean,
	tier: number,
	readyAt: number,
	expiresAt: number,
	holder: Player?,
	pickedAt: number,
	pickedPosition: Vector3,
	blockedUserId: number?,
	blockedUntil: number,
	tile: MapLayout.Tile?,
	weld: WeldConstraint?,
}

local ShardService = {
	name = "ShardService",
	carryChanged = Signal.new() :: Signal.Signal<Player, number>,
}

local shards: { [number]: ShardState } = {}
local activeCount = 0
local carried: { [Player]: { ShardState } } = {}
local occupiedTiles: { [MapLayout.Tile]: boolean } = {}
-- Players who cannot pick up shards right now (e.g. carrying a stolen Starling).
local pickupBlocked: { [Player]: true } = {}
local lastPositions: { [Player]: Vector3 } = {}
local nextId = 0
local container: Folder

local function rootOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return if root and root:IsA("BasePart") then root else nil, humanoid
end

local function destroyShard(shard: ShardState)
	if shards[shard.id] == nil then
		return
	end
	shards[shard.id] = nil
	activeCount -= 1
	if shard.tile then
		occupiedTiles[shard.tile] = nil
	end
	shard.parts.model:Destroy()
end

local function restack(player: Player)
	local list = carried[player]
	local character = player.Character
	local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	if list == nil or head == nil or not head:IsA("BasePart") then
		return
	end
	for index, shard in list do
		if shard.weld then
			shard.weld:Destroy()
		end
		shard.parts.crystal.CFrame = head.CFrame
			* CFrame.new(0, carry.StackOffset + (index - 1) * carry.StackSpacing, 0)
			* ShardBuilder.TILT
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = shard.parts.crystal
		weld.Parent = shard.parts.crystal
		shard.weld = weld
	end
end

local function attach(player: Player, shard: ShardState, root: BasePart, now: number)
	shard.holder = player
	shard.pickedAt = now
	shard.pickedPosition = root.Position
	if shard.tile then
		occupiedTiles[shard.tile] = nil
		shard.tile = nil
	end

	ShardBuilder.setBeaconVisible(shard.parts, false)
	-- The whole gem (welded to the crystal) becomes part of the character assembly.
	ShardBuilder.setAnchored(shard.parts, false)
	shard.parts.model:SetAttribute("HolderUserId", player.UserId)

	local list = carried[player] or {}
	carried[player] = list
	table.insert(list, shard)
	restack(player)

	local rarity = Rarities.get(shard.rarity)
	local prefix = if shard.isComet then "☄️ COMET CORE: " elseif shard.shiny then "✨ Shiny " else "+ "
	Notifier.send(player, `{prefix}{rarity.name} shard!`, "pickup", shard.rarity)
	ShardService.carryChanged:fire(player, #list)
end

-- Puts a carried shard back on the ground (or destroys it when the position is off-island).
local function dropShard(shard: ShardState, position: Vector3, blockUserId: number?)
	if shard.weld then
		shard.weld:Destroy()
		shard.weld = nil
	end
	shard.holder = nil
	shard.parts.model:SetAttribute("HolderUserId", 0)

	local tile = MapLayout.tileAt(MapService.getLayout(), position.X, position.Z)
	if tile == nil then
		destroyShard(shard)
		return
	end
	local now = os.clock()
	ShardBuilder.setAnchored(shard.parts, true)
	ShardBuilder.placeAt(shard.parts, Vector3.new(position.X, tile.height, position.Z))
	ShardBuilder.setBeaconVisible(shard.parts, true)
	shard.readyAt = now + 0.35
	shard.expiresAt = now + carry.DroppedLifetimeSeconds
	shard.blockedUserId = blockUserId
	shard.blockedUntil = now + carry.DropBlockSeconds
end

local function dropAll(player: Player, position: Vector3?)
	local list = carried[player]
	if list == nil or #list == 0 then
		return
	end
	carried[player] = {}
	local where = position or lastPositions[player]
	for index, shard in list do
		if where then
			-- Spread the pile a little so shards don't overlap.
			local angle = index * 2.4
			dropShard(shard, where + Vector3.new(math.cos(angle) * 2.5, 0, math.sin(angle) * 2.5), nil)
		else
			destroyShard(shard)
		end
	end
	ShardService.carryChanged:fire(player, 0)
end

local function deliver(player: Player, root: BasePart, maxSpeed: number, now: number)
	local list = carried[player]
	if list == nil or #list == 0 then
		return
	end
	carried[player] = {}

	local delivered: { Economy.DeliveredShard } = {}
	local here = root.Position * Vector3.new(1, 0, 1)
	for _, shard in list do
		local distance = (shard.pickedPosition * Vector3.new(1, 0, 1) - here).Magnitude
		if ShardRules.deliveryPlausible(distance, now - shard.pickedAt, maxSpeed) then
			table.insert(delivered, { rarity = shard.rarity, shiny = shard.shiny, isComet = shard.isComet })
		else
			log:warn(`implausible delivery by {player.UserId}: {math.floor(distance)} studs in {now - shard.pickedAt}s`)
		end
		destroyShard(shard)
	end
	ShardService.carryChanged:fire(player, 0)

	if #delivered == 0 then
		return
	end
	local placements = BaseService.deliver(player, delivered)
	if placements == nil then
		log:error(`delivery failed for {player.UserId}`)
		return
	end
	for index, placement in placements do
		local shard = delivered[index]
		local rarity = Rarities.get(shard.rarity)
		local label = `{if shard.shiny then "Shiny " else ""}{rarity.name} Starling`
		if placement.discovered then
			Notifier.send(
				player,
				`📖 NEW in your Index: {label}! +💰{Format.compact(placement.discoveryReward or 0)} · +2% income forever`,
				"rarity",
				shard.rarity
			)
		end
		if placement.outcome == "placed" then
			Notifier.send(player, `⭐ {label} joined your base!`, "rarity", shard.rarity)
		elseif placement.outcome == "replaced" then
			Notifier.send(
				player,
				`⭐ {label} took the place of a weaker one (+💰{Format.compact(placement.soldValue)})`,
				"rarity",
				shard.rarity
			)
		else
			Notifier.send(player, `Base full: sold a {label} for 💰{Format.compact(placement.soldValue)}`, "coins")
		end
	end
end

local function tick()
	local now = os.clock()

	for _, shard in shards do
		if shard.holder == nil and now > shard.expiresAt then
			destroyShard(shard)
		end
	end

	for _, player in Players:GetPlayers() do
		local root, humanoid = rootOf(player)
		local data = PlayerDataService.peek(player)
		if root and humanoid and data then
			lastPositions[player] = root.Position
			local alive = humanoid.Health > 0
			local list = carried[player] or {}
			local capacity = Economy.capacity(data.upgrades.carry)
			local radius = Economy.magnetRadius(data.upgrades.magnet)

			if alive and not pickupBlocked[player] and #list < capacity then
				for _, shard in shards do
					if shard.holder == nil then
						local ok = ShardRules.canPickup({
							tier = shard.tier,
							isComet = shard.isComet,
							readyAt = shard.readyAt,
							held = false,
							blockedUserId = shard.blockedUserId,
							blockedUntil = shard.blockedUntil,
						}, {
							userId = player.UserId,
							alive = alive,
							loaded = true,
							carrying = #(carried[player] or list),
							capacity = capacity,
							zoneTier = data.zoneTier,
							distance = (shard.parts.crystal.Position - root.Position).Magnitude,
							radius = radius,
						}, now)
						if ok then
							attach(player, shard, root, now)
						end
					end
				end
			end

			if alive and #(carried[player] or {}) > 0 and BaseService.isInOwnPlot(player, root.Position) then
				deliver(player, root, Economy.walkSpeed(data.upgrades.speed), now)
			end
		end
	end
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			local root = character:FindFirstChild("HumanoidRootPart")
			dropAll(player, if root and root:IsA("BasePart") then root.Position else nil)
		end)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		dropAll(player, nil)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
end

function ShardService.init(_self: any)
	container = Instance.new("Folder")
	container.Name = "Shards"
	container.Parent = Workspace
end

function ShardService.start(_self: any)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		dropAll(player, nil)
		carried[player] = nil
		lastPositions[player] = nil
		pickupBlocked[player] = nil
	end)

	-- Losing backpack levels (rebirth) drops what no longer fits.
	PlayerDataService.changed:connect(function(player, data)
		local list = carried[player]
		local capacity = Economy.capacity(data.upgrades.carry)
		if list and #list > capacity then
			local where = lastPositions[player]
			while #list > capacity do
				local shard = table.remove(list) :: ShardState
				if where then
					dropShard(shard, where, player.UserId)
				else
					destroyShard(shard)
				end
			end
			ShardService.carryChanged:fire(player, #list)
		end
	end)

	while true do
		task.wait(ServerConfig.Gameplay.ShardTickSeconds)
		local ok, err = pcall(tick :: any)
		if not ok then
			log:error(`tick failed: {err}`)
		end
	end
end

function ShardService.isTileFree(tile: MapLayout.Tile): boolean
	return occupiedTiles[tile] == nil and activeCount < events.MaxActiveShards
end

-- Creates a shard landing on `tile` after `delaySeconds` (meteor travel time). Nil when full.
function ShardService.spawnAt(
	tile: MapLayout.Tile,
	rarity: number,
	shiny: boolean,
	isComet: boolean,
	delaySeconds: number
): number?
	if activeCount >= events.MaxActiveShards then
		return nil
	end
	nextId += 1
	local id = nextId
	local parts = ShardBuilder.build(rarity, shiny, isComet, Vector3.new(tile.x, tile.height, tile.z))
	parts.model:SetAttribute("ShardId", id)
	parts.model:SetAttribute("Tier", tile.tier)
	parts.model:SetAttribute("HolderUserId", 0)
	local now = os.clock()
	local lifetime = if isComet then events.ShardLifetimeSeconds * 1.5 else events.ShardLifetimeSeconds

	local shard: ShardState = {
		id = id,
		parts = parts,
		rarity = rarity,
		shiny = shiny,
		isComet = isComet,
		tier = tile.tier,
		readyAt = now + delaySeconds,
		expiresAt = now + delaySeconds + lifetime,
		holder = nil,
		pickedAt = 0,
		pickedPosition = Vector3.zero,
		blockedUserId = nil,
		blockedUntil = 0,
		tile = tile,
		weld = nil,
	}
	shards[id] = shard
	activeCount += 1
	occupiedTiles[tile] = true

	if delaySeconds > 0 then
		ShardBuilder.setVisible(parts, false)
		task.delay(delaySeconds, function()
			if shards[id] ~= nil and shard.holder == nil then
				ShardBuilder.setVisible(parts, true)
			end
		end)
	end
	parts.model.Parent = container
	return id
end

function ShardService.setPickupBlocked(player: Player, blocked: boolean)
	if blocked then
		pickupBlocked[player] = true
	else
		pickupBlocked[player] = nil
	end
end

function ShardService.getCarryCount(player: Player): number
	local list = carried[player]
	return if list then #list else 0
end

-- Drops the most recently picked shard of `player` at `position`. False if they carry nothing.
function ShardService.dropTop(player: Player, position: Vector3, blockUserId: number?): boolean
	local list = carried[player]
	if list == nil or #list == 0 then
		return false
	end
	local shard = table.remove(list) :: ShardState
	dropShard(shard, position, blockUserId)
	ShardService.carryChanged:fire(player, #list)
	return true
end

return ShardService
