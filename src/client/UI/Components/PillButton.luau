--!strict
--[[
	PillButton — the wide candy button of the style sheet ("⭐ Play", "🛒 Shop"): rounded gradient
	pill, glossy top, dark outline, icon on the left and a chunky outlined label.
	`setBadge` shows a red "!" bubble (something to claim).

	Colour emoji ignore TextColor3 and UIStroke: they keep their own colours. On a pill of the same
	colour (⭐ on gold) pass a monochrome glyph instead (★), which gets the light fill and dark
	cartoon outline below.
]]

local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

export type PillButton = {
	root: TextButton,
	label: TextLabel,
	icon: TextLabel,
	badge: TextLabel,
	setText: (text: string) -> (),
	setBadge: (visible: boolean) -> (),
	setColors: (top: Color3, bottom: Color3) -> (),
}

local PillButton = {}

-- Fill of monochrome icon glyphs (the style sheet's pale yellow star).
local ICON_FILL = Color3.fromRGB(255, 236, 110)

function PillButton.new(icon: string, text: string, top: Color3, bottom: Color3, size: Vector2?): PillButton
	local dimensions = size or Vector2.new(190, 64)
	local iconLabel = Create("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(dimensions.Y - 16, dimensions.Y - 16),
		Font = Theme.Font.Body,
		Text = icon,
		TextColor3 = ICON_FILL,
		TextScaled = true,
		ZIndex = 3,
	}) :: TextLabel
	Theme.textOutline(iconLabel, 3)

	local label = Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, dimensions.Y - 2, 0.5, 0),
		Size = UDim2.new(1, -(dimensions.Y + 10), 0.62, 0),
		Font = Theme.Font.Title,
		Text = text,
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}) :: TextLabel
	Theme.textOutline(label, 2.5)

	local badge = Create("TextLabel", {
		Name = "Badge",
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Theme.Color.Red,
		Font = Theme.Font.Title,
		Text = "!",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
		ZIndex = 4,
	}) :: TextLabel
	Theme.corner(badge)
	Theme.border(badge, 2)

	local root = Create("TextButton", {
		Name = text,
		Size = UDim2.fromOffset(dimensions.X, dimensions.Y),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		AutoButtonColor = true,
		ZIndex = 2,
	}, { iconLabel :: Instance, label, badge }) :: TextButton
	Theme.corner(root, math.floor(dimensions.Y * 0.32))
	Theme.border(root, 3.5)
	local gradient = Theme.gradient(root, top, bottom)
	Theme.gloss(root, math.floor(dimensions.Y * 0.22))

	return {
		root = root,
		label = label,
		icon = iconLabel,
		badge = badge,
		setText = function(value: string)
			label.Text = value
		end,
		setBadge = function(visible: boolean)
			badge.Visible = visible
		end,
		setColors = function(newTop: Color3, newBottom: Color3)
			gradient.Color = ColorSequence.new(newTop, newBottom)
		end,
	}
end

return table.freeze(PillButton)
