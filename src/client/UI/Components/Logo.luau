--!strict
--[[
	Logo — the COMET RAIDERS title of the style sheet, built from text: a gold "COMET" over a white
	"RAIDERS", each with a thick dark outline and a 3D drop, a purple orbit ring, a big star and
	sparkles. Each word is three stacked labels (depth, outline, gradient face) so the gradient
	never tints the outline. Once the style sheet's logo image is uploaded (UI/Art) it is shown
	instead.
]]

local Art = require(script.Parent.Parent.Art)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

export type Logo = {
	root: Frame,
}

local Logo = {}

local DEPTH_COLOR = Color3.fromRGB(64, 22, 120)

local function word(name: string, text: string, top: Color3, bottom: Color3, position: UDim2, size: UDim2): Frame
	local function layer(layerName: string, offset: number, color: Color3, stroke: number?): TextLabel
		local label = Create("TextLabel", {
			Name = layerName,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, offset),
			Size = UDim2.fromScale(1, 1),
			Font = Theme.Font.Title,
			Text = text,
			TextColor3 = color,
			TextScaled = true,
		}) :: TextLabel
		if stroke then
			local outline = Instance.new("UIStroke")
			outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
			outline.Thickness = stroke
			outline.Color = if layerName == "Depth" then DEPTH_COLOR else Theme.Color.Outline
			outline.Parent = label
		end
		return label
	end
	local face = layer("Face", 0, Color3.new(1, 1, 1))
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Parent = face
	return Create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
	}, {
		layer("Depth", 9, DEPTH_COLOR, 7) :: Instance,
		layer("Outline", 0, Theme.Color.Outline, 7),
		face,
	}) :: Frame
end

local function sparkle(position: UDim2, size: number, rotation: number, glyph: string): TextLabel
	return Create("TextLabel", {
		Name = "Sparkle",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		Rotation = rotation,
		Font = Theme.Font.Body,
		Text = glyph,
		TextScaled = true,
	}) :: TextLabel
end

function Logo.new(): Logo
	local art = Art.label("logo")
	if art then
		local width = 580
		return {
			root = Create("Frame", {
				Name = "Logo",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(width, math.floor(width / Art.aspect("logo"))),
			}, { art }) :: Frame,
		}
	end
	local ring = Create("Frame", {
		Name = "Orbit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(1.08, 0.5),
		Rotation = -10,
		BackgroundTransparency = 1,
	}) :: Frame
	Theme.corner(ring)
	local ringStroke = Theme.border(ring, 7, Theme.Color.Purple)
	ringStroke.Transparency = 0.15
	local glow = Theme.border(ring, 16, Theme.Color.Purple)
	glow.Transparency = 0.75

	local comet = word(
		"Comet",
		"COMET",
		Color3.fromRGB(255, 244, 140),
		Color3.fromRGB(255, 150, 20),
		UDim2.fromScale(0.5, 0.3),
		UDim2.fromScale(0.86, 0.44)
	)
	comet.Rotation = -4
	local raiders = word(
		"Raiders",
		"RAIDERS",
		Color3.new(1, 1, 1),
		Color3.fromRGB(176, 206, 255),
		UDim2.fromScale(0.5, 0.72),
		UDim2.fromScale(0.98, 0.46)
	)
	raiders.Rotation = -4

	local root = Create("Frame", {
		Name = "Logo",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(620, 320),
	}, {
		ring :: Instance,
		comet,
		raiders,
		sparkle(UDim2.fromScale(0.62, 0.02), 92, 14, "⭐"),
		sparkle(UDim2.fromScale(0.86, 0.0), 54, -20, "☄️"),
		sparkle(UDim2.fromScale(0.05, 0.22), 34, 0, "✨"),
		sparkle(UDim2.fromScale(0.97, 0.62), 30, 0, "✨"),
		sparkle(UDim2.fromScale(0.1, 0.92), 26, 12, "⭐"),
		sparkle(UDim2.fromScale(0.9, 0.95), 34, -8, "💎"),
	}) :: Frame
	return { root = root }
end

return table.freeze(Logo)
