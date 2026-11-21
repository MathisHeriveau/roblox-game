--!strict
--[[
	RoundButton — the round icon buttons of the style sheet (⚙️ 📊 🎁 🐾 🏆 📅): glossy candy
	circle, dark outline, emoji icon, optional red "!" badge and a small caption under it.
]]

local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

export type RoundButton = {
	root: Frame,
	button: TextButton,
	badge: TextLabel,
	setBadge: (visible: boolean) -> (),
}

local RoundButton = {}

local SIZE = 62

function RoundButton.new(name: string, icon: string, caption: string, top: Color3, bottom: Color3): RoundButton
	local badge = Create("TextLabel", {
		Name = "Badge",
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Theme.Color.Red,
		Font = Theme.Font.Title,
		Text = "!",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
		ZIndex = 4,
	}) :: TextLabel
	Theme.corner(badge)
	Theme.border(badge, 2)

	local iconLabel = Create("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		Font = Theme.Font.Body,
		Text = icon,
		TextScaled = true,
		ZIndex = 3,
	}) :: TextLabel

	local button = Create("TextButton", {
		Name = "Button",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		AutoButtonColor = true,
		ZIndex = 2,
	}, { iconLabel :: Instance, badge }) :: TextButton
	Theme.corner(button)
	Theme.border(button, 3)
	Theme.gradient(button, top, bottom)
	Theme.gloss(button)

	local label = Create("TextLabel", {
		Name = "Caption",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, SIZE + 2),
		Size = UDim2.fromOffset(SIZE + 16, 16),
		Font = Theme.Font.Title,
		Text = caption,
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
	}) :: TextLabel
	Theme.textOutline(label, 1.5)

	local root = Create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(SIZE + 8, SIZE + 20),
	}, { button :: Instance, label }) :: Frame

	return {
		root = root,
		button = button,
		badge = badge,
		setBadge = function(visible: boolean)
			badge.Visible = visible
		end,
	}
end

return table.freeze(RoundButton)
