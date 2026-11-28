--!strict
--[[
	Panel — modal window in the Comet Raiders style: dimmed backdrop, rounded purple panel with a
	gold title, a red close button and a scrolling body. Pure construction (testable headlessly).
	Only one modal is open at a time (UI/Modal).
]]

local Create = require(script.Parent.Parent.Create)
local Layers = require(script.Parent.Parent.Layers)
local Modal = require(script.Parent.Parent.Modal)
local Motion = require(script.Parent.Parent.Motion)
local Theme = require(script.Parent.Parent.Theme)

export type Panel = {
	gui: ScreenGui,
	body: ScrollingFrame,
	header: TextLabel,
	closeButton: TextButton,
	dim: TextButton,
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
}

local Panel = {}

function Panel.new(name: string, title: string, size: Vector2): Panel
	local scale = Instance.new("UIScale")
	scale.Name = "Scale"

	local header = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(28, 14),
		Size = UDim2.new(1, -120, 0, 54),
		Font = Theme.Font.Title,
		Text = title,
		TextColor3 = Theme.Color.Gold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}) :: TextLabel
	Theme.textOutline(header, 3)

	local closeButton = Create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 16),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = Theme.Font.Title,
		Text = "X",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
	}) :: TextButton
	Theme.corner(closeButton)
	Theme.border(closeButton, 3)
	Theme.gradient(closeButton, Theme.Color.Red, Theme.Color.RedDark)
	Theme.textOutline(closeButton, 2)
	Theme.padding(closeButton, 10)

	local body = Create("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(22, 80),
		Size = UDim2.new(1, -44, 1, -100),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Color.Gold,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}) :: ScrollingFrame

	local panel = Create("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Theme.Color.Panel,
	}, { scale :: Instance, header, closeButton, body }) :: Frame
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

	local gui = Create("ScreenGui", {
		Name = name,
		Enabled = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = Layers.Panels,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, { dim :: Instance, panel }) :: ScreenGui

	local function close()
		gui.Enabled = false
		Modal.closed(name)
	end

	Motion.bindPress(closeButton)

	return {
		gui = gui,
		body = body,
		header = header,
		closeButton = closeButton,
		dim = dim,
		open = function()
			Modal.opened(name, close)
			local wasOpen = gui.Enabled
			gui.Enabled = true
			if not wasOpen then
				Motion.popIn(scale)
			end
		end,
		close = close,
		isOpen = function()
			return gui.Enabled
		end,
	}
end

-- Wires the X button and the dimmed backdrop to close the panel (controllers call this; the
-- construction above stays free of engine connections so it can be tested headlessly).
function Panel.connect(panel: Panel): { RBXScriptConnection }
	return {
		panel.closeButton.Activated:Connect(panel.close),
		panel.dim.Activated:Connect(panel.close),
	}
end

-- A rounded row/card inside a panel body.
function Panel.card(height: number, order: number): Frame
	local card = Create("Frame", {
		Name = "Card",
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = Theme.Color.PanelDark,
	}) :: Frame
	Theme.corner(card, 16)
	Theme.border(card, 2)
	return card
end

-- A label with the house style.
function Panel.text(props: { [string]: any }, outline: number?): TextLabel
	local label = Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Font.Body,
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
	}) :: TextLabel
	for key, value in props do
		(label :: any)[key] = value
	end
	Theme.textOutline(label, outline or 2)
	return label
end

return table.freeze(Panel)
