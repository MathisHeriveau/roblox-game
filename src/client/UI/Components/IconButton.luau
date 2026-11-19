--!strict
--[[
	IconButton — round candy button with an emoji icon and a caption (Shop, Rebirth...).
]]

local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

export type IconButton = {
	root: Frame,
	button: TextButton,
}

local IconButton = {}

function IconButton.new(icon: string, caption: string, top: Color3, bottom: Color3): IconButton
	local button = Create("TextButton", {
		Name = "Button",
		Size = UDim2.fromOffset(74, 74),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = Theme.Font.Body,
		Text = icon,
		TextScaled = true,
		AutoButtonColor = true,
	}) :: TextButton
	Theme.corner(button)
	Theme.border(button, 3)
	Theme.gradient(button, top, bottom)
	Theme.padding(button, 14)

	local label = Create("TextLabel", {
		Name = "Caption",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-13, 74),
		Size = UDim2.fromOffset(100, 24),
		Font = Theme.Font.Title,
		Text = caption,
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
	}) :: TextLabel
	Theme.textOutline(label, 2)

	local root = Create("Frame", {
		Name = caption,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(74, 100),
	}, { button :: Instance, label }) :: Frame

	return { root = root, button = button }
end

return table.freeze(IconButton)
