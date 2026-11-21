--!strict
--[[
	Theme — the Comet Raiders UI look (art style sheet): chunky Luckiest Guy titles, Fredoka One
	body text, gold / blue / purple candy buttons with dark outlines, rounded panels.
	Helpers decorate an existing GuiObject; they never create layout.
]]

local Theme = {
	Font = table.freeze({
		Title = Enum.Font.LuckiestGuy,
		Body = Enum.Font.FredokaOne,
	}),
	Color = table.freeze({
		Gold = Color3.fromRGB(255, 205, 64),
		GoldDark = Color3.fromRGB(240, 146, 16),
		Blue = Color3.fromRGB(54, 168, 255),
		BlueDark = Color3.fromRGB(18, 98, 226),
		Purple = Color3.fromRGB(150, 92, 255),
		PurpleDark = Color3.fromRGB(86, 40, 196),
		Navy = Color3.fromRGB(70, 78, 170),
		NavyDark = Color3.fromRGB(30, 30, 96),
		Green = Color3.fromRGB(70, 226, 120),
		GreenDark = Color3.fromRGB(24, 160, 84),
		Red = Color3.fromRGB(255, 84, 96),
		RedDark = Color3.fromRGB(196, 32, 58),
		Grey = Color3.fromRGB(150, 146, 172),
		GreyDark = Color3.fromRGB(96, 92, 120),
		Panel = Color3.fromRGB(38, 28, 84),
		PanelDark = Color3.fromRGB(24, 16, 58),
		Outline = Color3.fromRGB(20, 11, 52),
		Text = Color3.new(1, 1, 1),
		TextDim = Color3.fromRGB(206, 196, 246),
		Income = Color3.fromRGB(120, 255, 160),
	}),
}

function Theme.corner(target: GuiObject, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0)
	corner.Parent = target
	return corner
end

-- Outline around a frame/button border.
function Theme.border(target: GuiObject, thickness: number?, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = thickness or 3
	stroke.Color = color or Theme.Color.Outline
	stroke.Parent = target
	return stroke
end

-- Cartoon outline around text.
function Theme.textOutline(target: TextLabel | TextButton, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Thickness = thickness or 2.5
	stroke.Color = Theme.Color.Outline
	stroke.Parent = target
	return stroke
end

-- Vertical candy gradient (light at the top, dark at the bottom).
function Theme.gradient(target: GuiObject, top: Color3, bottom: Color3): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	gradient.Parent = target
	return gradient
end

-- Candy shine: a soft white highlight over the top half of a button.
function Theme.gloss(target: GuiObject, radius: number?): Frame
	local shine = Instance.new("Frame")
	shine.Name = "Gloss"
	shine.AnchorPoint = Vector2.new(0.5, 0)
	shine.Position = UDim2.fromScale(0.5, 0.06)
	shine.Size = UDim2.fromScale(0.86, 0.42)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.72
	shine.BorderSizePixel = 0
	shine.ZIndex = target.ZIndex
	local corner = Instance.new("UICorner")
	corner.CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0)
	corner.Parent = shine
	shine.Parent = target
	return shine
end

function Theme.padding(target: GuiObject, pixels: number)
	local padding = Instance.new("UIPadding")
	local value = UDim.new(0, pixels)
	padding.PaddingTop = value
	padding.PaddingBottom = value
	padding.PaddingLeft = value
	padding.PaddingRight = value
	padding.Parent = target
end

-- Picks the scale so a UI designed for 1400x800 fits phones to 4K.
function Theme.scaleFor(viewport: Vector2): number
	if viewport.X <= 0 or viewport.Y <= 0 then
		return 1
	end
	return math.clamp(math.min(viewport.X / 1400, viewport.Y / 800), 0.55, 1.25)
end

return table.freeze(Theme)
