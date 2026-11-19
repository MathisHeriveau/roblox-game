--!strict
--[[
	RaidService — stealing Starlings from other players' bases, and defending your own.

	Flow:
	  1. A thief holds the Steal prompt on an unlocked base (BaseService.stealRequested).
	  2. RaidRules.canSteal decides. On success the Starling leaves its pedestal (hidden, still in
	     the owner's data) and floats above the thief, who is slowed and cannot grab shards.
	  3. The theft ends when:
	       - the thief reaches their own base  -> the Starling moves from the victim's data to the
	         thief's (removal first, then placement; rolled back if placement fails);
	       - the thief is bumped (BumpService -> recover), dies, respawns or leaves, or the owner
	         leaves -> the Starling flies home: no data changes at all.
	Data only ever changes at a successful delivery, so an interrupted raid can never duplicate or
	lose a Starling.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Log = require(ReplicatedStorage.Shared.Utils.Log)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local ShardVisuals = require(ReplicatedStorage.Shared.Game.ShardVisuals)
local Signal = require(ReplicatedStorage.Shared.Utils.Signal)
local Server = ServerScriptService.Server
local BaseService = require(Server.Services.BaseService)
local CharacterService = require(Server.Services.CharacterService)
local Notifier = require(Server.Systems.Notifier)
local PlayerDataService = require(Server.Services.PlayerDataService)
local RaidRules = require(Server.Systems.Raid.RaidRules)
local ServerConfig = require(Server.ServerConfig)
local ServerNet = require(Server.Systems.ServerNet)
local ShardRules = require(Server.Systems.Shards.ShardRules)
local ShardService = require(Server.Services.ShardService)
local StarlingBuilder = require(Server.Systems.Base.StarlingBuilder)

local raid = GameConfig.Raid
local log = Log.scope("RaidService")

type Transit = {
	thief: Player,
	owner: Player,
	index: number,
	rarity: number,
	shiny: boolean,
	model: Model,
	startedAt: number,
	startPosition: Vector3,
}

local RaidService = {
	name = "RaidService",
	-- Fires for the thief whenever they start or stop carrying a Starling.
	changed = Signal.new() :: Signal.Signal<Player>,
}

local transits: { [Player]: Transit } = {}
local container: Folder

local REFUSALS: { [string]: string } = {
	Locked = "🔒 This base is locked by its shield",
	Protected = "🛡️ Beginners with fewer than 2 Starlings are protected",
	Busy = "Your hands are full: deliver what you carry first",
	TooFar = "Get closer to the Starling",
	InTransit = "Someone is already stealing that one!",
}

local function rootOf(player: Player): (BasePart?, Humanoid?, BasePart?)
	local character = player.Character
	if character == nil then
		return nil, nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	return if root and root:IsA("BasePart") then root else nil,
		character:FindFirstChildOfClass("Humanoid"),
		if head and head:IsA("BasePart") then head else nil
end

local function refreshHidden(owner: Player)
	local set: { [number]: boolean } = {}
	for _, transit in transits do
		if transit.owner == owner then
			set[transit.index] = true
		end
	end
	BaseService.setHiddenSet(owner, set)
end

local function label(transit: Transit): string
	return `{if transit.shiny then "Shiny " else ""}{Rarities.get(transit.rarity).name} Starling`
end

-- Builds the stolen Starling welded above the thief's head.
local function carryModel(rarity: number, shiny: boolean, head: BasePart): Model
	local model = StarlingBuilder.build(rarity, shiny, head.CFrame * CFrame.new(0, 4.2, 0))
	model.Name = "StolenStarling"
	-- Not animated by clients like pedestal Starlings: physics owns it now.
	model:RemoveTag(ShardVisuals.STARLING_TAG)
	local core = model.PrimaryPart :: BasePart
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			if descendant ~= core then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = core
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end
	local toHead = Instance.new("WeldConstraint")
	toHead.Part0 = head
	toHead.Part1 = core
	toHead.Parent = core
	model.Parent = container
	return model
end

local function finish(transit: Transit)
	transits[transit.thief] = nil
	if transit.model.Parent then
		transit.model:Destroy()
	end
	CharacterService.setModifier(transit.thief, "raid", nil)
	ShardService.setPickupBlocked(transit.thief, false)
	refreshHidden(transit.owner)
	RaidService.changed:fire(transit.thief)
end

-- The Starling flies home: nothing changes in anyone's data.
local function sendHome(transit: Transit, thiefMessage: string, ownerMessage: string?)
	finish(transit)
	if transit.thief.Parent == Players then
		Notifier.send(transit.thief, thiefMessage, "warning")
	end
	if ownerMessage and transit.owner.Parent == Players then
		Notifier.send(transit.owner, ownerMessage, "success")
	end
end

local function complete(transit: Transit, root: BasePart)
	local thiefData = PlayerDataService.peek(transit.thief)
	local maxSpeed = (if thiefData then Economy.walkSpeed(thiefData.upgrades.speed) else 18) * raid.CarrySpeedFactor
	local distance = ((transit.startPosition - root.Position) * Vector3.new(1, 0, 1)).Magnitude
	if not ShardRules.deliveryPlausible(distance, os.clock() - transit.startedAt, maxSpeed) then
		log:warn(`implausible raid delivery by {transit.thief.UserId}`)
		sendHome(transit, "The Starling escaped and flew home!", nil)
		return
	end

	-- 1. Take it from the victim (matched by kind: indices may have shifted meanwhile).
	local removed = false
	PlayerDataService.update(transit.owner, function(draft)
		local index = RaidRules.findStarling(draft.starlings, transit.rarity, transit.shiny)
		if index then
			table.remove(draft.starlings, index)
			removed = true
		end
	end)
	finish(transit)
	if not removed then
		Notifier.send(transit.thief, "That Starling vanished before you got home…", "warning")
		return
	end

	-- 2. Give it to the thief; roll back to the victim if that fails.
	local placements = BaseService.deliver(transit.thief, {
		{ rarity = transit.rarity, shiny = transit.shiny, isComet = false },
	})
	if placements == nil then
		PlayerDataService.update(transit.owner, function(draft)
			table.insert(draft.starlings, { rarity = transit.rarity, shiny = transit.shiny })
		end)
		log:error(`raid placement failed for {transit.thief.UserId}; Starling returned to {transit.owner.UserId}`)
		return
	end
	Notifier.send(
		transit.thief,
		`😈 You stole a {label(transit)} from {transit.owner.DisplayName}!`,
		"rarity",
		transit.rarity
	)
	if transit.owner.Parent == Players then
		Notifier.send(
			transit.owner,
			`💔 {transit.thief.DisplayName} stole your {label(transit)}! Lock your base!`,
			"alarm",
			transit.rarity
		)
	end
	ServerNet.fireAllClients("WorldEvent", { kind = "raid", position = root.Position, rarity = transit.rarity })
end

local function onStealRequested(thief: Player, owner: Player, index: number)
	local root, humanoid, head = rootOf(thief)
	local ownerData = PlayerDataService.peek(owner)
	local pedestal = BaseService.pedestalPosition(owner, index)
	if root == nil or humanoid == nil or head == nil or ownerData == nil or pedestal == nil then
		return
	end
	local starling = ownerData.starlings[index]
	local ok, refusal = RaidRules.canSteal({
		thiefUserId = thief.UserId,
		ownerUserId = owner.UserId,
		thiefAlive = humanoid.Health > 0,
		thiefLoaded = PlayerDataService.isLoaded(thief),
		thiefCarryingShards = ShardService.getCarryCount(thief),
		thiefCarryingStarling = transits[thief] ~= nil,
		baseLocked = BaseService.isLocked(owner),
		victimStarlings = #ownerData.starlings,
		minVictimStarlings = raid.MinVictimStarlings,
		pedestalOccupied = starling ~= nil,
		pedestalInTransit = BaseService.isHidden(owner, index),
		distance = (root.Position - pedestal).Magnitude,
		maxDistance = raid.StealMaxDistance,
	})
	if not ok or starling == nil then
		local message = if refusal then REFUSALS[refusal] else nil
		if message then
			Notifier.send(thief, message, "warning")
		end
		return
	end

	local transit: Transit = {
		thief = thief,
		owner = owner,
		index = index,
		rarity = starling.rarity,
		shiny = starling.shiny,
		model = carryModel(starling.rarity, starling.shiny, head),
		startedAt = os.clock(),
		startPosition = root.Position,
	}
	transits[thief] = transit
	refreshHidden(owner)
	CharacterService.setModifier(thief, "raid", raid.CarrySpeedFactor)
	ShardService.setPickupBlocked(thief, true)
	RaidService.changed:fire(thief)

	Notifier.send(thief, `😈 Run home with the {label(transit)}! Don't get bumped!`, "warning")
	Notifier.send(
		owner,
		`🚨 {thief.DisplayName} is stealing your {label(transit)}! Bump them!`,
		"alarm",
		starling.rarity
	)
end

local function tick()
	for thief, transit in transits do
		local root, humanoid = rootOf(thief)
		if root == nil or humanoid == nil or humanoid.Health <= 0 then
			sendHome(transit, "You dropped the Starling: it flew home", `🛡️ Your {label(transit)} came back home`)
		elseif BaseService.isInOwnPlot(thief, root.Position) then
			complete(transit, root)
		end
	end
end

function RaidService.isCarrying(player: Player): boolean
	return transits[player] ~= nil
end

function RaidService.carriedRarity(player: Player): number
	local transit = transits[player]
	return if transit then transit.rarity else 0
end

-- A bump knocked the Starling out of the thief's hands: it flies home.
function RaidService.recover(thief: Player, by: Player)
	local transit = transits[thief]
	if transit == nil then
		return
	end
	local ownerMessage = if by == transit.owner
		then `🛡️ You took back your {label(transit)}!`
		else `🛡️ {by.DisplayName} knocked your {label(transit)} back home!`
	sendHome(transit, `💥 {by.DisplayName} bumped you: the Starling flew home!`, ownerMessage)
end

function RaidService.init(_self: any)
	container = Instance.new("Folder")
	container.Name = "Raids"
	container.Parent = Workspace
end

function RaidService.start(_self: any)
	BaseService.stealRequested:connect(onStealRequested)
	Players.PlayerRemoving:Connect(function(player)
		local carrying = transits[player]
		if carrying then
			sendHome(carrying, "", nil)
		end
		for _, transit in transits do
			if transit.owner == player then
				sendHome(transit, "The owner left: their Starling vanished", nil)
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function()
			local transit = transits[player]
			if transit then
				sendHome(
					transit,
					"You dropped the Starling: it flew home",
					`🛡️ Your {label(transit)} came back home`
				)
			end
		end)
	end)

	while true do
		task.wait(ServerConfig.Gameplay.ShardTickSeconds)
		local ok, err = pcall(tick :: any)
		if not ok then
			log:error(`tick failed: {err}`)
		end
	end
end

return RaidService
