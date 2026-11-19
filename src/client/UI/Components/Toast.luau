--!strict
--[[
	Toast — a single notification bubble (text + colour accent). Sized to its text.
]]

local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

local Toast = {}

function Toast.new(text: string, accent: Color3): Frame
	local label = Create("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		Font = Theme.Font.Body,
		Text = text,
		TextColor3 = Theme.Color.Text,
		TextSize = 26,
	}) :: TextLabel
	Theme.textOutline(label, 2)

	local frame = Create("Frame", {
		Name = "Toast",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 46),
		BackgroundColor3 = Theme.Color.Panel,
	}, { label }) :: Frame
	Theme.corner(frame)
	local border = Theme.border(frame, 3, accent)
	border.Name = "Accent"
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = frame
	return frame
end

return table.freeze(Toast)
