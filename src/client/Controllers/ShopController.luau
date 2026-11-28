--!strict
--[[
	ShopController — the shop panel: upgrades, zone unlocks and rebirth.

	Displays prices and effects computed with Shared/Game/Economy from the server-sent state, and
	sends purchase *requests*; the server re-checks everything. Opens with the HUD buttons, the
	"+" on the coin pill, or the B key; B, the X, a click outside, gamepad B or Escape close it.
	Purchase results show on the shop's own status line: toasts are drawn under the shop
	(UI/Layers).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ClientNet = require(ReplicatedStorage.Shared.Net.ClientNet)
local Create = require(script.Parent.Parent.UI.Create)
local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Format = require(ReplicatedStorage.Shared.Game.Format)
local Layers = require(script.Parent.Parent.UI.Layers)
local Modal = require(script.Parent.Parent.UI.Modal)
local PlayerStateTypes = require(ReplicatedStorage.Shared.Types.PlayerState)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local ShopCard = require(script.Parent.Parent.UI.Components.ShopCard)
local StateController = require(script.Parent.StateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local TitleController = require(script.Parent.TitleController)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local STATUS_SECONDS = 3

type PlayerState = PlayerStateTypes.PlayerState

local ShopController = {
	name = "ShopController",
}

type CardEntry = {
	card: ShopCard.ShopCard,
	view: (state: PlayerState) -> ShopCard.CardView,
}

local gui: ScreenGui
local scale: UIScale
local list: ScrollingFrame
local status: TextLabel
local statusToken = 0
local entries: { CardEntry } = {}
local busy = false

local function number(value: number): string
	-- Magnet radius has decimals; everything else is whole.
	return if value == math.floor(value) then Format.compact(value) else string.format("%.1f", value)
end

local function costButton(cost: number, coins: number): (string, string)
	return `💰 {Format.compact(cost)}`, if coins >= cost then "buy" else "poor"
end

local function upgradeView(upgrade: Upgrades.Upgrade): (PlayerState) -> ShopCard.CardView
	return function(state)
		local level = (state.upgrades :: any)[upgrade.id] :: number
		local current = Economy.upgradeEffect(upgrade.id, level)
		local cost = Economy.upgradeCost(upgrade.id, level)
		if cost == nil then
			return {
				icon = upgrade.icon,
				title = upgrade.name,
				description = `{upgrade.description}: {number(current)}`,
				level = `Level {level} / {upgrade.maxLevel} · MAXED`,
				buttonText = "MAX",
				state = "max",
			}
		end
		local text, buttonState = costButton(cost, state.coins)
		return {
			icon = upgrade.icon,
			title = upgrade.name,
			description = `{upgrade.description}: {number(current)} → {number(
				Economy.upgradeEffect(upgrade.id, level + 1)
			)}`,
			level = `Level {level} / {upgrade.maxLevel}`,
			buttonText = text,
			state = buttonState,
		}
	end
end

local function bestRarity(zone: Zones.Zone): string
	local best = 1
	for id, weight in zone.weights do
		if weight > 0 then
			best = id
		end
	end
	return Rarities.get(best).name
end

local function zoneView(zone: Zones.Zone): (PlayerState) -> ShopCard.CardView
	return function(state)
		local base = {
			icon = zone.icon,
			title = zone.name,
			description = `Shards up to {bestRarity(zone)} rarity`,
			level = `Zone {zone.tier}`,
		}
		if zone.tier <= state.zoneTier then
			return {
				icon = base.icon,
				title = base.title,
				description = base.description,
				level = base.level,
				buttonText = "UNLOCKED",
				state = "owned",
			}
		elseif zone.tier > state.zoneTier + 1 then
			return {
				icon = base.icon,
				title = base.title,
				description = `Unlock {Zones.get(zone.tier - 1).name} first`,
				level = base.level,
				buttonText = "🔒",
				state = "locked",
			}
		end
		local text, buttonState = costButton(zone.unlockCost, state.coins)
		return {
			icon = base.icon,
			title = base.title,
			description = base.description,
			level = base.level,
			buttonText = text,
			state = buttonState,
		}
	end
end

local function rebirthView(state: PlayerState): ShopCard.CardView
	local nextMultiplier = Economy.multiplier(state.rebirths + 1, state.indexCount)
	local lastZone = Zones.get(Zones.COUNT)
	if state.zoneTier < Zones.COUNT then
		return {
			icon = "🌟",
			title = "Rebirth",
			description = `Unlock {lastZone.name} to rebirth`,
			level = `Rebirths: {state.rebirths} · income x{state.multiplier}`,
			buttonText = "🔒",
			state = "locked",
		}
	end
	local text, buttonState = costButton(state.rebirthCost, state.coins)
	return {
		icon = "🌟",
		title = "Rebirth",
		description = `Reset progress, earn x{nextMultiplier} income forever`,
		level = `Rebirths: {state.rebirths} · income x{state.multiplier}`,
		buttonText = text,
		state = buttonState,
	}
end

local function render(state: PlayerState?)
	if state == nil then
		return
	end
	for _, entry in entries do
		entry.card.render(entry.view(state))
	end
end

local function showStatus(text: string, success: boolean)
	statusToken += 1
	local token = statusToken
	status.Text = string.sub(text, 1, 120)
	status.TextColor3 = if success then Theme.Color.Green else Theme.Color.Red
	status.Visible = true
	task.delay(STATUS_SECONDS, function()
		if token == statusToken then
			status.Visible = false
		end
	end)
end

local function buy(kind: string, id: string?)
	if busy then
		return
	end
	busy = true
	Sfx.play(Sfx.CLICK, 0.4)
	local ok, result = ClientNet.invoke("RequestPurchase", kind, id)
	busy = false
	local response = if type(result) == "table" then result :: any else nil
	if not ok or response == nil or type(response.message) ~= "string" then
		showStatus("Shop unavailable, try again", false)
	else
		showStatus(response.message, response.ok == true)
	end
end

-- Section headers by key, so a caller can open the shop on its section (REBIRTH → rebirth card).
local sections: { [string]: TextLabel } = {}

local function section(key: string, text: string, order: number)
	local label = Create("TextLabel", {
		Name = "Section",
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 36),
		Font = Theme.Font.Title,
		Text = text,
		TextColor3 = Theme.Color.Gold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}) :: TextLabel
	Theme.textOutline(label, 2)
	label.Parent = list
	sections[key] = label
end

-- Scrolls the list so the `key` section header sits at the top (once the layout has run).
local function scrollTo(key: string?)
	local header = if key then sections[key] else nil
	if header == nil then
		list.CanvasPosition = Vector2.zero
		return
	end
	task.defer(function()
		local offset = header.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y
		list.CanvasPosition = Vector2.new(0, math.max(0, offset))
	end)
end

local function addCard(order: number, view: (PlayerState) -> ShopCard.CardView, onBuy: () -> ())
	local card = ShopCard.new()
	card.root.LayoutOrder = order
	card.root.Parent = list
	card.button.Activated:Connect(onBuy)
	table.insert(entries, { card = card, view = view })
end

function ShopController.isOpen(): boolean
	return gui.Enabled
end

-- Opens the shop, scrolled to a section: "upgrades" (default), "zones" or "rebirth".
function ShopController.open(focus: string?)
	render(StateController.get())
	Modal.opened("Shop", ShopController.close)
	gui.Enabled = true
	scrollTo(focus)
end

function ShopController.openAt(focus: string): () -> ()
	return function()
		ShopController.open(focus)
	end
end

function ShopController.close()
	gui.Enabled = false
	status.Visible = false
	Modal.closed("Shop")
end

function ShopController.toggle()
	if ShopController.isOpen() then
		ShopController.close()
	else
		ShopController.open()
	end
end

function ShopController.init(_self: any)
	scale = Instance.new("UIScale")
	list = Create("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(22, 86),
		Size = UDim2.new(1, -44, 1, -106),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Color.Gold,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	}) :: ScrollingFrame

	local title = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(28, 14),
		Size = UDim2.new(1, -120, 0, 58),
		Font = Theme.Font.Title,
		Text = "COMET SHOP",
		TextColor3 = Theme.Color.Gold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}) :: TextLabel
	Theme.textOutline(title, 3)

	status = Create("TextLabel", {
		Name = "Status",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -86, 0, 26),
		Size = UDim2.new(0.5, -40, 0, 34),
		Font = Theme.Font.Body,
		Text = "",
		TextColor3 = Theme.Color.Green,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
	}) :: TextLabel
	Theme.textOutline(status, 1.5)

	local close = Create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 16),
		Size = UDim2.fromOffset(54, 54),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = Theme.Font.Title,
		Text = "X",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
	}) :: TextButton
	Theme.corner(close)
	Theme.border(close, 3)
	Theme.gradient(close, Theme.Color.Red, Theme.Color.RedDark)
	Theme.textOutline(close, 2)
	Theme.padding(close, 10)
	close.Activated:Connect(ShopController.close)

	local panel = Create("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(820, 600),
		BackgroundColor3 = Theme.Color.Panel,
	}, { scale :: Instance, title, status, close, list }) :: Frame
	Theme.corner(panel, 30)
	Theme.border(panel, 4)

	local dim = Create("TextButton", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Text = "",
		AutoButtonColor = false,
	}) :: TextButton
	dim.Activated:Connect(ShopController.close)

	gui = Create("ScreenGui", {
		Name = "Shop",
		Enabled = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = Layers.Shop,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, { dim :: Instance, panel }) :: ScreenGui

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	section("upgrades", "⚡ UPGRADES", nextOrder())
	for _, upgrade in Upgrades.list do
		addCard(nextOrder(), upgradeView(upgrade), function()
			buy("upgrade", upgrade.id)
		end)
	end
	section("zones", "🗺️ ZONES", nextOrder())
	for _, zone in Zones.list do
		if zone.tier > 1 then
			addCard(nextOrder(), zoneView(zone), function()
				buy("zone", zone.key)
			end)
		end
	end
	section("rebirth", "🌟 REBIRTH", nextOrder())
	addCard(nextOrder(), rebirthView, function()
		buy("rebirth", nil)
	end)
end

function ShopController.start(_self: any)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local camera = Workspace.CurrentCamera
	if camera then
		local function rescale()
			scale.Scale = Theme.scaleFor(camera.ViewportSize)
		end
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		rescale()
	end
	StateController.changed:connect(function(state)
		if gui.Enabled then
			render(state)
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or TitleController.isShowing() then
			return
		end
		-- Escape is reserved by Roblox: InputController closes modals when the Roblox menu opens.
		if input.KeyCode == Enum.KeyCode.B then
			ShopController.toggle()
		end
	end)
end

return ShopController
