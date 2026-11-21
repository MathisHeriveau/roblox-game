--!strict
--[[
	LevelBadge — star badge with the player level and an XP progress bar.
	Pure Instance construction: testable headlessly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(script.Parent.Parent.Create)
local Format = require(ReplicatedStorage.Shared.Game.Format)
local Theme = require(script.Parent.Parent.Theme)

export type LevelBadge = {
	root: Frame,
	setLevel: (level: number, progress: number, goal: number) -> (),
}

local LevelBadge = {}

function LevelBadge.new(): LevelBadge
	local fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}) :: Frame
	Theme.corner(fill)
	Theme.gradient(fill, Theme.Color.Gold, Theme.Color.GoldDark)

	local progressText = Create("TextLabel", {
		Name = "Progress",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Font.Body,
		Text = "0 / 0",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
		ZIndex = 2,
	}) :: TextLabel
	Theme.textOutline(progressText, 2)

	local bar = Create("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(40, 12),
		Size = UDim2.new(1, -44, 0, 26),
		BackgroundColor3 = Theme.Color.PanelDark,
	}, { fill :: Instance, progressText }) :: Frame
	Theme.corner(bar)
	Theme.border(bar, 3)

	local levelText = Create("TextLabel", {
		Name = "Level",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Font.Title,
		Text = "1",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
	}) :: TextLabel
	Theme.textOutline(levelText)

	-- Gold star behind the level number (style sheet), drawn with the star emoji.
	local starGlyph = Create("TextLabel", {
		Name = "StarGlyph",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(1.35, 1.35),
		Font = Theme.Font.Body,
		Text = "⭐",
		TextScaled = true,
		ZIndex = 1,
	}) :: TextLabel
	levelText.ZIndex = 2
	levelText.AnchorPoint = Vector2.new(0.5, 0.5)
	levelText.Position = UDim2.fromScale(0.5, 0.56)
	levelText.Size = UDim2.fromScale(0.62, 0.5)
	local star = Create("Frame", {
		Name = "Star",
		Position = UDim2.fromOffset(-6, -6),
		Size = UDim2.fromOffset(62, 62),
		BackgroundTransparency = 1,
	}, { starGlyph :: Instance, levelText }) :: Frame

	local root = Create("Frame", {
		Name = "LevelBadge",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(270, 50),
	}, { bar :: Instance, star }) :: Frame

	return {
		root = root,
		setLevel = function(level: number, progress: number, goal: number)
			levelText.Text = tostring(math.max(1, math.floor(level)))
			local ratio = if goal > 0 then math.clamp(progress / goal, 0, 1) else 0
			fill.Size = UDim2.fromScale(ratio, 1)
			progressText.Text = `{Format.compact(progress)} / {Format.compact(goal)} XP`
		end,
	}
end

return table.freeze(LevelBadge)
