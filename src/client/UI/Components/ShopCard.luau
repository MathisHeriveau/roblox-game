--!strict
--[[
	ShopCard — one row of the shop: icon, title, description, level and a buy button whose look
	reflects its state (buy / unaffordable / locked / max / owned).
]]

local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

export type ButtonState = "buy" | "poor" | "locked" | "max" | "owned"

export type CardView = {
	icon: string,
	title: string,
	description: string,
	level: string,
	buttonText: string,
	-- One of ButtonState; unknown values render as "locked".
	state: string,
}

export type ShopCard = {
	root: Frame,
	button: TextButton,
	render: (view: CardView) -> (),
}

local BUTTON_COLORS: { [string]: { Color3 } } = {
	buy = { Theme.Color.Gold, Theme.Color.GoldDark },
	poor = { Theme.Color.Grey, Theme.Color.GreyDark },
	locked = { Theme.Color.Grey, Theme.Color.GreyDark },
	max = { Theme.Color.Green, Theme.Color.GreenDark },
	owned = { Theme.Color.Green, Theme.Color.GreenDark },
}

local ShopCard = {}

function ShopCard.new(): ShopCard
	local icon = Create("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(66, 66),
		Font = Theme.Font.Body,
		Text = "",
		TextScaled = true,
	}) :: TextLabel
	local title = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(90, 8),
		Size = UDim2.new(1, -270, 0, 32),
		Font = Theme.Font.Title,
		Text = "",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}) :: TextLabel
	Theme.textOutline(title, 2)
	local description = Create("TextLabel", {
		Name = "Description",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(90, 42),
		Size = UDim2.new(1, -270, 0, 22),
		Font = Theme.Font.Body,
		Text = "",
		TextColor3 = Theme.Color.TextDim,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}) :: TextLabel
	local level = Create("TextLabel", {
		Name = "Level",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(90, 64),
		Size = UDim2.new(1, -270, 0, 18),
		Font = Theme.Font.Body,
		Text = "",
		TextColor3 = Theme.Color.Gold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}) :: TextLabel
	local button = Create("TextButton", {
		Name = "Buy",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(160, 56),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = Theme.Font.Title,
		Text = "",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
		AutoButtonColor = true,
	}) :: TextButton
	Theme.corner(button, 16)
	Theme.border(button, 3)
	local gradient = Theme.gradient(button, Theme.Color.Gold, Theme.Color.GoldDark)
	Theme.textOutline(button, 2)
	Theme.padding(button, 10)

	local root = Create("Frame", {
		Name = "ShopCard",
		Size = UDim2.new(1, -8, 0, 88),
		BackgroundColor3 = Theme.Color.PanelDark,
	}, { icon :: Instance, title, description, level, button }) :: Frame
	Theme.corner(root, 18)
	Theme.border(root, 2, Theme.Color.Outline)

	return {
		root = root,
		button = button,
		render = function(view: CardView)
			icon.Text = view.icon
			title.Text = view.title
			description.Text = view.description
			level.Text = view.level
			button.Text = view.buttonText
			local colors = BUTTON_COLORS[view.state] or BUTTON_COLORS["locked"]
			gradient.Color = ColorSequence.new(colors[1], colors[2])
			button.Active = view.state == "buy" or view.state == "poor"
		end,
	}
end

return table.freeze(ShopCard)
