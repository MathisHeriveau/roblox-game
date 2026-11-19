--!strict
--[[
	BaseService — player bases: plot assignment, Starling display, passive income, the collect pad
	and offline earnings.

	Income model: every second each player's Starlings add income to their base *vault*; walking
	onto the collect pad banks the vault into coins. Offline time also fills the vault (capped and
	reduced, see GameConfig.Economy). All amounts are computed by Shared/Game/Economy.

	Public API (server only):
	  BaseService.getPlot(player) -> PlotRefs?
	  BaseService.isInOwnPlot(player, position) -> boolean
	  BaseService.isInAnyPlot(position) -> boolean   -- safe zones (no bumping)
	  BaseService.deliver(player, shards) -> { Placement }?
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
local Notifier = require(Server.Systems.Notifier)
local PlayerDataSchema = require(Server.Systems.Persistence.PlayerDataSchema)
local PlayerDataService = require(Server.Services.PlayerDataService)
local ServerConfig = require(Server.ServerConfig)
local StarlingBuilder = require(Server.Systems.Base.StarlingBuilder)

type PlayerData = PlayerDataSchema.PlayerData

local settings = GameConfig.Base
local log = Log.scope("BaseService")

local BaseService = {
	name = "BaseService",
}

local plots: { BaseBuilder.PlotRefs } = {}
local owners: { [Player]: BaseBuilder.PlotRefs } = {}
-- Last rendered Starling layout per player, to rebuild models only when it changes.
local signatures: { [Player]: string } = {}

local function signatureOf(data: PlayerData): string
	local parts = { tostring(Economy.slots(data.upgrades.slots)) }
	for _, starling in data.starlings do
		table.insert(parts, `{starling.rarity}{if starling.shiny then "s" else ""}`)
	end
	return table.concat(parts, ",")
end

local function resetPlot(refs: BaseBuilder.PlotRefs)
	refs.model:SetAttribute("OwnerUserId", 0)
	refs.ownerLabel.Text = "Free Base"
	refs.incomeLabel.Text = ""
	refs.vaultLabel.Text = "💰 0"
	refs.starlings:ClearAllChildren()
	BaseBuilder.setUnlockedSlots(refs, 0)
end

local function syncVisuals(player: Player, data: PlayerData)
	local refs = owners[player]
	if refs == nil then
		return
	end
	local signature = signatureOf(data)
	if signatures[player] ~= signature then
		signatures[player] = signature
		refs.starlings:ClearAllChildren()
		for index, starling in data.starlings do
			local anchor = refs.starlingAnchors[index]
			if anchor then
				StarlingBuilder.build(starling.rarity, starling.shiny, anchor).Parent = refs.starlings
			end
		end
		BaseBuilder.setUnlockedSlots(refs, Economy.slots(data.upgrades.slots))
	end
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

local function collectTick()
	for player, refs in owners do
		local root = rootOf(player)
		local data = PlayerDataService.peek(player)
		if root and data and data.vault > 0 then
			local position = root.Position
			if
				BaseLayout.isOnCollectPad(refs.plot, position.X, position.Z, settings.CollectPadRadius)
				and position.Y < 10
			then
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
end

function BaseService.init(_self: any)
	local folder = Instance.new("Folder")
	folder.Name = "Bases"
	for _, plot in BaseLayout.generate(settings) do
		local refs = BaseBuilder.build(plot, folder)
		BaseBuilder.setUnlockedSlots(refs, 0)
		table.insert(plots, refs)
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
	while true do
		task.wait(settings.IncomeTickSeconds)
		incomeTick()
	end
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
