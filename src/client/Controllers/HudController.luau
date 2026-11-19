--!strict
--[[
	HudController — the always-visible HUD: coins & income, level & XP, carried shards, the Shop /
	Rebirth buttons and the big zone title shown when entering a new zone.

	Display only: everything shown comes from the server's PlayerState.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CarryIndicator = require(script.Parent.Parent.UI.Components.CarryIndicator)
local CoinPill = require(script.Parent.Parent.UI.Components.CoinPill)
local Create = require(script.Parent.Parent.UI.Create)
local IconButton = require(script.Parent.Parent.UI.Components.IconButton)
local LevelBadge = require(script.Parent.Parent.UI.Components.LevelBadge)
local PlayerStateTypes = require(ReplicatedStorage.Shared.Types.PlayerState)
local ShopController = require(script.Parent.ShopController)
local StateController = require(script.Parent.StateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

type PlayerState = PlayerStateTypes.PlayerState

local HudController = {
	name = "HudController",
}

local gui: ScreenGui
local scale: UIScale
local coinPill: CoinPill.CoinPill
local levelBadge: LevelBadge.LevelBadge
local carry: CarryIndicator.CarryIndicator
local shopButton: IconButton.IconButton
local rebirthButton: IconButton.IconButton
local zoneTitle: TextLabel
local zoneSubtitle: TextLabel
local zoneToken = 0

local function render(state: PlayerState)
	coinPill.setCoins(state.coins)
	coinPill.setIncome(state.incomePerSecond, state.vault)
	levelBadge.setLevel(state.level, state.levelProgress, state.levelGoal)
	carry.setCarry(state.carrying, state.capacity, state.carryingStarling)
end

local function showZone(tier: number)
	zoneToken += 1
	local token = zoneToken
	local state = StateController.get()
	if tier == 0 then
		zoneTitle.Text = Zones.HUB_NAME
		zoneTitle.TextColor3 = Theme.Color.Gold
		zoneSubtitle.Text = "Your base is here: deliver shards to hatch Starlings"
	else
		local zone = Zones.get(tier)
		zoneTitle.Text = `{zone.icon} {string.upper(zone.name)}`
		zoneTitle.TextColor3 = zone.color
		if state and tier > state.zoneTier then
			zoneSubtitle.Text = "🔒 Locked: unlock it in the shop to grab shards here"
		else
			zoneSubtitle.Text = `Shards drop here · zone {tier}`
		end
	end
	for _, label in { zoneTitle, zoneSubtitle } do
		label.TextTransparency = 0
		label.Visible = true
	end
	task.delay(2.6, function()
		if token ~= zoneToken then
			return
		end
		for _, label in { zoneTitle, zoneSubtitle } do
			TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	end)
end

local function watchZones()
	local lastTier: number? = nil
	while true do
		task.wait(0.3)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local tier = Zones.tierAt(root.Position.X, root.Position.Z)
			if tier ~= nil and tier ~= lastTier then
				if lastTier ~= nil then
					showZone(tier)
				end
				lastTier = tier
			end
		end
	end
end

function HudController.init(_self: any)
	scale = Instance.new("UIScale")
	coinPill = CoinPill.new()
	levelBadge = LevelBadge.new()
	levelBadge.root.Position = UDim2.fromOffset(0, 96)
	carry = CarryIndicator.new()
	carry.root.Position = UDim2.new(0.5, 0, 1, -16)
	shopButton = IconButton.new("🛒", "SHOP", Theme.Color.Blue, Theme.Color.BlueDark)
	shopButton.root.LayoutOrder = 1
	rebirthButton = IconButton.new("🌟", "REBIRTH", Theme.Color.Purple, Theme.Color.PurpleDark)
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
		Size = UDim2.fromOffset(80, 220),
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		shopButton.root,
		rebirthButton.root,
	}) :: Frame

	zoneTitle = Create("TextLabel", {
		Name = "ZoneTitle",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(900, 76),
		Font = Theme.Font.Title,
		Text = "",
		TextScaled = true,
		Visible = false,
	}) :: TextLabel
	Theme.textOutline(zoneTitle, 4)
	zoneSubtitle = Create("TextLabel", {
		Name = "ZoneSubtitle",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.3, 42),
		Size = UDim2.fromOffset(800, 30),
		Font = Theme.Font.Body,
		Text = "",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
		Visible = false,
	}) :: TextLabel
	Theme.textOutline(zoneSubtitle, 2)

	gui = Create("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	}, { scale :: Instance, topLeft, right, carry.root, zoneTitle, zoneSubtitle }) :: ScreenGui
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
	shopButton.button.Activated:Connect(ShopController.open)
	rebirthButton.button.Activated:Connect(ShopController.open)

	StateController.changed:connect(render)
	local state = StateController.get()
	if state then
		render(state)
	end
	watchZones()
end

return HudController
