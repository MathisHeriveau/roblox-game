--!strict
--[[
	HudController — the always-visible HUD: coins & income, the star level badge & XP, carried
	shards, the candy SHOP / REBIRTH buttons ("!" when something is affordable) and the zone banner
	shown when walking into another zone. Hidden behind the title screen until PLAY.

	Owns the top-centre column, a vertical stack where other controllers mount their banners
	(`HudController.mountTop(item, HudController.TopSlot.X)`, from their init()): sky event
	countdowns, then the zone banner, then the comet banner. Hidden items take no space, so banners
	never overlap each other.

	Display only: everything shown comes from the server's PlayerState.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CarryIndicator = require(script.Parent.Parent.UI.Components.CarryIndicator)
local CoinPill = require(script.Parent.Parent.UI.Components.CoinPill)
local Create = require(script.Parent.Parent.UI.Create)
local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Layers = require(script.Parent.Parent.UI.Layers)
local LevelBadge = require(script.Parent.Parent.UI.Components.LevelBadge)
local PillButton = require(script.Parent.Parent.UI.Components.PillButton)
local PlayerStateTypes = require(ReplicatedStorage.Shared.Types.PlayerState)
local ShopController = require(script.Parent.ShopController)
local StateController = require(script.Parent.StateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local TitleController = require(script.Parent.TitleController)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local ZoneAnnouncer = require(script.Parent.Parent.Hud.ZoneAnnouncer)
local ZoneBanner = require(script.Parent.Parent.UI.Components.ZoneBanner)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local ZONE_BANNER_SECONDS = 2.6
local ZONE_FADE_SECONDS = 0.6

type PlayerState = PlayerStateTypes.PlayerState

local HudController = {
	name = "HudController",
	-- Order of the banners in the top-centre column.
	TopSlot = table.freeze({
		Countdowns = 1,
		Zone = 2,
		Comet = 3,
	}),
}

local gui: ScreenGui
local scale: UIScale
local coinPill: CoinPill.CoinPill
local levelBadge: LevelBadge.LevelBadge
local carry: CarryIndicator.CarryIndicator
local shopButton: PillButton.PillButton
local rebirthButton: PillButton.PillButton
local topCenter: Frame? = nil
local zoneBanner: ZoneBanner.ZoneBanner
local zoneFade: NumberValue
local zoneTween: Tween? = nil
local zoneToken = 0

local function render(state: PlayerState)
	coinPill.setCoins(state.coins)
	coinPill.setIncome(state.incomePerSecond, state.vault)
	levelBadge.setLevel(state.level, state.levelProgress, state.levelGoal)
	carry.setCarry(state.carrying, state.capacity, state.carryingStarling)
	-- "!" bubbles: an affordable upgrade or next zone, a rebirth within reach.
	local affordable = false
	for _, upgrade in Upgrades.list do
		local level = (state.upgrades :: any)[upgrade.id]
		local cost = if type(level) == "number" then Economy.upgradeCost(upgrade.id, level) else nil
		if cost ~= nil and cost <= state.coins then
			affordable = true
			break
		end
	end
	local nextZone = state.zoneTier < Zones.COUNT and Zones.get(state.zoneTier + 1) or nil
	if nextZone and nextZone.unlockCost <= state.coins then
		affordable = true
	end
	shopButton.setBadge(affordable)
	rebirthButton.setBadge(state.coins >= state.rebirthCost)
end

local function showZone(tier: number)
	zoneToken += 1
	local token = zoneToken
	local state = StateController.get()
	local text = ZoneAnnouncer.describe(tier, if state then state.zoneTier else nil)
	if zoneTween then
		zoneTween:Cancel()
	end
	zoneFade.Value = 0
	zoneBanner.show(text.title, text.subtitle, text.color)
	task.delay(ZONE_BANNER_SECONDS, function()
		if token ~= zoneToken then
			return
		end
		local tween = TweenService:Create(zoneFade, TweenInfo.new(ZONE_FADE_SECONDS), { Value = 1 })
		zoneTween = tween
		tween:Play()
	end)
end

local function watchZones()
	local announcer = ZoneAnnouncer.new()
	-- The zone a character spawns in is never announced (respawning at the base after a fall).
	Players.LocalPlayer.CharacterAdded:Connect(function()
		announcer:reset()
	end)
	while true do
		task.wait(0.3)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local tier = announcer:observe(Zones.tierAt(root.Position.X, root.Position.Z))
			if tier ~= nil then
				showZone(tier)
			end
		end
	end
end

-- Adds a banner to the top-centre column. Call from init(), after HudController.init.
function HudController.mountTop(item: GuiObject, slot: number)
	local column = topCenter
	assert(column, "HudController.mountTop: HudController is not initialised yet")
	item.LayoutOrder = slot
	item.Parent = column
end

function HudController.init(_self: any)
	scale = Instance.new("UIScale")
	coinPill = CoinPill.new()
	levelBadge = LevelBadge.new()
	levelBadge.root.Position = UDim2.fromOffset(0, 96)
	carry = CarryIndicator.new()
	carry.root.Position = UDim2.new(0.5, 0, 1, -16)
	shopButton = PillButton.new("🛒", "SHOP", Theme.Color.Blue, Theme.Color.BlueDark, Vector2.new(196, 66))
	shopButton.root.LayoutOrder = 1
	rebirthButton = PillButton.new("🌟", "REBIRTH", Theme.Color.Purple, Theme.Color.PurpleDark, Vector2.new(196, 66))
	rebirthButton.root.LayoutOrder = 2

	local topLeft = Create("Frame", {
		Name = "TopLeft",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.fromOffset(280, 150),
	}, { coinPill.root :: Instance, levelBadge.root }) :: Frame

	local right = Create("Frame", {
		Name = "RightButtons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -20, 0.5, 0),
		Size = UDim2.fromOffset(200, 150),
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 14),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
		shopButton.root,
		rebirthButton.root,
	}) :: Frame

	zoneBanner = ZoneBanner.new()
	zoneFade = Instance.new("NumberValue")
	zoneFade.Value = 1
	zoneFade.Changed:Connect(function(value: number)
		zoneBanner.setFade(value)
	end)
	local column = Create("Frame", {
		Name = "TopCenter",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(520, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
	}) :: Frame
	topCenter = column
	HudController.mountTop(zoneBanner.root, HudController.TopSlot.Zone)

	gui = Create("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		DisplayOrder = Layers.Hud,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	}, { scale :: Instance, topLeft, right, carry.root, column }) :: ScreenGui
	TitleController.hideWhileShowing(gui)
end

function HudController.start(_self: any)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local camera = Workspace.CurrentCamera
	if camera then
		local function rescale()
			scale.Scale = Theme.scaleFor(camera.ViewportSize)
		end
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		rescale()
	end

	coinPill.plusButton.Activated:Connect(ShopController.open)
	shopButton.root.Activated:Connect(ShopController.open)
	rebirthButton.root.Activated:Connect(ShopController.open)

	StateController.changed:connect(render)
	local state = StateController.get()
	if state then
		render(state)
	end
	watchZones()
end

return HudController
