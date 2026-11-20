--!strict
--[[
	BaseService — player bases: plot assignment, Starling display, passive income, the collect pad
	and offline earnings.

	Income model: every second each player's Starlings add income to their base *vault*; stepping
	onto the collect pad banks the vault into coins, once per visit (CollectPadRules). Offline time also fills the vault (capped and
	reduced, see GameConfig.Economy). All amounts are computed by Shared/Game/Economy.

	Public API (server only):
	  BaseService.getPlot(player) -> PlotRefs?
	  BaseService.isInOwnPlot(player, position) -> boolean
	  BaseService.isInAnyPlot(position) -> boolean   -- safe zones (no bumping)
	  BaseService.deliver(player, shards) -> { Placement }?
	  BaseService.isLocked(owner) / BaseService.lock(owner, seconds)
	  BaseService.setHiddenSet(owner, { [index]: true })  -- Starlings currently being stolen
	  BaseService.stealRequested:connect(fn(thief, owner, pedestalIndex))

	Raids: an owner locks their base at its console (shield dome, GameConfig.Raid.LockSeconds).
	While unlocked, other players can hold the Steal prompt on a pedestal; BaseService only
	forwards the request (RaidService decides and runs the theft).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Format = require(ReplicatedStorage.Shared.Game.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Log = require(ReplicatedStorage.Shared.Utils.Log)
local Server = ServerScriptService.Server
local BaseBuilder = require(Server.Systems.Base.BaseBuilder)
local BaseLayout = require(Server.Systems.Base.BaseLayout)
local CollectPadRules = require(Server.Systems.Base.CollectPadRules)
local Notifier = require(Server.Systems.Notifier)
local PlayerDataSchema = require(Server.Systems.Persistence.PlayerDataSchema)
local PlayerDataService = require(Server.Services.PlayerDataService)
local RaidRules = require(Server.Systems.Raid.RaidRules)
local ServerConfig = require(Server.ServerConfig)
local Signal = require(ReplicatedStorage.Shared.Utils.Signal)
local StarlingBuilder = require(Server.Systems.Base.StarlingBuilder)

type PlayerData = PlayerDataSchema.PlayerData

local settings = GameConfig.Base
local raid = GameConfig.Raid
local log = Log.scope("BaseService")

local BaseService = {
	name = "BaseService",
	stealRequested = Signal.new() :: Signal.Signal<Player, Player, number>,
}

local plots: { BaseBuilder.PlotRefs } = {}
local owners: { [Player]: BaseBuilder.PlotRefs } = {}
-- Last rendered Starling layout per player, to rebuild models only when it changes.
local signatures: { [Player]: string } = {}
-- Server time until which each owner's base is locked.
local lockedUntil: { [Player]: number } = {}
-- Pedestal indices whose Starling is currently being carried away by a thief.
local hidden: { [Player]: { [number]: boolean } } = {}
-- Whether each owner stood on their collect pad at the previous collect tick.
local onPad: { [Player]: boolean } = {}

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function ownerOf(refs: BaseBuilder.PlotRefs): Player?
	for player, owned in owners do
		if owned == refs then
			return player
		end
	end
	return nil
end

local function signatureOf(player: Player, data: PlayerData): string
	local hiddenSet = hidden[player] or {}
	local parts = { tostring(Economy.slots(data.upgrades.slots)) }
	for index, starling in data.starlings do
		table.insert(
			parts,
			`{starling.rarity}{if starling.shiny then "s" else ""}{if hiddenSet[index] then "h" else ""}`
		)
	end
	return table.concat(parts, ",")
end

-- Steal prompts are enabled only where a theft could succeed (other rules re-checked on use).
local function updatePrompts(player: Player, data: PlayerData?)
	local refs = owners[player]
	if refs == nil then
		return
	end
	local locked = RaidRules.isLocked(lockedUntil[player] or 0, serverNow())
	local hiddenSet = hidden[player] or {}
	local count = if data then #data.starlings else 0
	for index, prompt in refs.stealPrompts do
		prompt.Enabled = data ~= nil
			and not locked
			and count >= raid.MinVictimStarlings
			and data.starlings[index] ~= nil
			and not hiddenSet[index]
	end
end

local function updateLock(player: Player)
	local refs = owners[player]
	if refs == nil then
		return
	end
	local remaining = (lockedUntil[player] or 0) - serverNow()
	local locked = remaining > 0
	BaseBuilder.setShield(refs, locked)
	refs.lockLabel.Text = if locked then `🔒 LOCKED {math.ceil(remaining)}s` else "🔓 OPEN TO RAIDS"
	refs.lockLabel.TextColor3 = if locked then Color3.fromRGB(140, 220, 255) else Color3.fromRGB(255, 110, 120)
end

local function resetPlot(refs: BaseBuilder.PlotRefs)
	refs.model:SetAttribute("OwnerUserId", 0)
	refs.model:SetAttribute("LockedUntil", 0)
	refs.ownerLabel.Text = "Free Base"
	refs.incomeLabel.Text = ""
	refs.lockLabel.Text = ""
	refs.vaultLabel.Text = "💰 0"
	refs.starlings:ClearAllChildren()
	BaseBuilder.setUnlockedSlots(refs, 0)
	BaseBuilder.setShield(refs, false)
	for _, prompt in refs.stealPrompts do
		prompt.Enabled = false
	end
end

local function syncVisuals(player: Player, data: PlayerData)
	local refs = owners[player]
	if refs == nil then
		return
	end
	local signature = signatureOf(player, data)
	if signatures[player] ~= signature then
		signatures[player] = signature
		local hiddenSet = hidden[player] or {}
		refs.starlings:ClearAllChildren()
		for index, starling in data.starlings do
			local anchor = refs.starlingAnchors[index]
			if anchor and not hiddenSet[index] then
				StarlingBuilder.build(starling.rarity, starling.shiny, anchor).Parent = refs.starlings
			end
		end
		BaseBuilder.setUnlockedSlots(refs, Economy.slots(data.upgrades.slots))
	end
	updatePrompts(player, data)
	local income = Economy.incomePerSecond(data.starlings, data.rebirths)
	refs.incomeLabel.Text = if income > 0 then `+{Format.compact(income)}/s` else "Bring shards home!"
	refs.vaultLabel.Text = `💰 {Format.compact(data.vault)}`
end

local function assign(player: Player)
	if owners[player] then
		return
	end
	for _, refs in plots do
		if refs.model:GetAttribute("OwnerUserId") == 0 then
			owners[player] = refs
			refs.model:SetAttribute("OwnerUserId", player.UserId)
			refs.ownerLabel.Text = `{player.DisplayName}'s Base`
			player.RespawnLocation = refs.spawn
			-- Grace period: nobody is raided while loading in.
			BaseService.lock(player, raid.JoinGraceSeconds)
			local data = PlayerDataService.peek(player)
			if data then
				syncVisuals(player, data)
			end
			return
		end
	end
	log:warn(`no free plot for {player.UserId}`)
	Notifier.send(player, "Every base is taken on this server: you can explore, but not store Starlings.", "warning")
end

local function release(player: Player)
	local refs = owners[player]
	owners[player] = nil
	signatures[player] = nil
	lockedUntil[player] = nil
	hidden[player] = nil
	onPad[player] = nil
	if refs then
		resetPlot(refs)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function onLoaded(player: Player, data: PlayerData)
	local income = Economy.incomePerSecond(data.starlings, data.rebirths)
	local offline = if data.lastSeen > 0 then Economy.offlineEarnings(income, os.time() - data.lastSeen) else 0
	if offline > 0 then
		PlayerDataService.update(player, function(draft)
			draft.vault += offline
		end)
		Notifier.send(player, `Your Starlings earned 💰{Format.compact(offline)} while you were away!`, "coins")
	end
	local current = PlayerDataService.peek(player)
	if current then
		syncVisuals(player, current)
	end
end

local function incomeTick()
	for _, player in Players:GetPlayers() do
		local data = PlayerDataService.peek(player)
		if data then
			local income = Economy.incomePerSecond(data.starlings, data.rebirths)
			if income > 0 then
				PlayerDataService.update(player, function(draft)
					draft.vault += income
				end)
			end
		end
	end
end

local function isOnOwnPad(player: Player, refs: BaseBuilder.PlotRefs): boolean
	local root = rootOf(player)
	if root == nil then
		return false
	end
	local position = root.Position
	return position.Y < 10 and BaseLayout.isOnCollectPad(refs.plot, position.X, position.Z, settings.CollectPadRadius)
end

local function collectTick()
	for player, refs in owners do
		local isOnPad = isOnOwnPad(player, refs)
		local wasOnPad = onPad[player] == true
		onPad[player] = isOnPad
		local data = PlayerDataService.peek(player)
		if data and CollectPadRules.shouldBank(wasOnPad, isOnPad, data.vault) then
			local amount = data.vault
			local banked = PlayerDataService.update(player, function(draft)
				draft.coins += draft.vault
				draft.vault = 0
			end)
			if banked then
				Notifier.send(player, `+💰{Format.compact(amount)}`, "coins")
			end
		end
	end
end

function BaseService.init(_self: any)
	local folder = Instance.new("Folder")
	folder.Name = "Bases"
	for _, plot in BaseLayout.generate(settings) do
		local refs = BaseBuilder.build(plot, folder)
		BaseBuilder.setUnlockedSlots(refs, 0)
		table.insert(plots, refs)

		refs.lockPrompt.Triggered:Connect(function(player: Player)
			if owners[player] ~= refs then
				Notifier.send(player, "Only the owner can lock this base", "warning")
				return
			end
			if not RaidRules.canLock(true, lockedUntil[player] or 0, serverNow()) then
				Notifier.send(player, "Your base is already locked", "info")
				return
			end
			BaseService.lock(player, raid.LockSeconds)
			Notifier.send(player, `🔒 Base locked for {raid.LockSeconds}s. Come back to re-lock!`, "success")
		end)
		for index, prompt in refs.stealPrompts do
			prompt.Triggered:Connect(function(thief: Player)
				local owner = ownerOf(refs)
				if owner then
					BaseService.stealRequested:fire(thief, owner, index)
				end
			end)
		end
	end
	folder.Parent = Workspace
end

function BaseService.start(_self: any)
	Players.PlayerAdded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		assign(player)
	end
	PlayerDataService.loaded:connect(onLoaded)
	PlayerDataService.changed:connect(syncVisuals)

	task.spawn(function()
		while true do
			task.wait(ServerConfig.Gameplay.CollectTickSeconds)
			collectTick()
		end
	end)
	-- Lock countdowns, shield expiry and prompt refresh.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player in owners do
				updateLock(player)
				updatePrompts(player, PlayerDataService.peek(player))
			end
		end
	end)
	while true do
		task.wait(settings.IncomeTickSeconds)
		incomeTick()
	end
end

function BaseService.isLocked(owner: Player): boolean
	return RaidRules.isLocked(lockedUntil[owner] or 0, serverNow())
end

function BaseService.lock(owner: Player, seconds: number)
	local refs = owners[owner]
	if refs == nil then
		return
	end
	local untilTime = serverNow() + seconds
	lockedUntil[owner] = untilTime
	-- Replicated so clients can show the countdown.
	refs.model:SetAttribute("LockedUntil", untilTime)
	updateLock(owner)
	updatePrompts(owner, PlayerDataService.peek(owner))
end

-- Pedestals whose Starling is being carried away (not rendered, not stealable).
function BaseService.setHiddenSet(owner: Player, set: { [number]: boolean })
	hidden[owner] = set
	local data = PlayerDataService.peek(owner)
	if data then
		syncVisuals(owner, data)
	end
end

function BaseService.isHidden(owner: Player, index: number): boolean
	local set = hidden[owner]
	return set ~= nil and set[index] == true
end

function BaseService.pedestalPosition(owner: Player, index: number): Vector3?
	local refs = owners[owner]
	local anchor = refs and refs.starlingAnchors[index]
	return if anchor then anchor.Position else nil
end

function BaseService.getPlot(player: Player): BaseBuilder.PlotRefs?
	return owners[player]
end

function BaseService.isInOwnPlot(player: Player, position: Vector3): boolean
	local refs = owners[player]
	return refs ~= nil and position.Y < 14 and BaseLayout.isInside(refs.plot, position.X, position.Z, 1)
end

function BaseService.isInAnyPlot(position: Vector3): boolean
	if position.Y > 14 then
		return false
	end
	for _, refs in plots do
		if BaseLayout.isInside(refs.plot, position.X, position.Z, 1) then
			return true
		end
	end
	return false
end

-- Turns delivered shards into Starlings (or coins when the base is full). Nil if data is not loaded.
function BaseService.deliver(player: Player, shards: { Economy.DeliveredShard }): { Economy.Placement }?
	local placements: { Economy.Placement }? = nil
	local ok = PlayerDataService.update(player, function(draft)
		placements = Economy.deliver(draft, shards)
	end)
	return if ok then placements else nil
end

return BaseService
