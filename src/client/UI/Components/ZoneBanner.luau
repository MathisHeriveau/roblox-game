--!strict
--[[
	ZoneBanner — compact "you entered a zone" card shown under the sky event countdowns: zone
	name in the zone colour, light subtitle with a dark outline, on its own panel so it stays
	readable over the bright sky and the dark base signs alike.

	API:
	  local banner = ZoneBanner.new()
	  banner.show(title, subtitle, color)   opaque and visible
	  banner.setFade(alpha)                 0 = opaque … 1 = gone (texts, outlines and panel together)
]]

local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

local PANEL_TRANSPARENCY = 0.15

export type ZoneBanner = {
	root: Frame,
	show: (title: string, subtitle: string, color: Color3) -> (),
	setFade: (alpha: number) -> (),
}

local ZoneBanner = {}

function ZoneBanner.new(): ZoneBanner
	local title = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.58),
		Font = Theme.Font.Title,
		Text = "",
		TextColor3 = Theme.Color.Gold,
		TextScaled = true,
	}) :: TextLabel
	local titleOutline = Theme.textOutline(title, 2.5)
	local subtitle = Create("TextLabel", {
		Name = "Subtitle",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.fromScale(1, 0.4),
		Font = Theme.Font.Body,
		Text = "",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
	}) :: TextLabel
	-- Thin outline: thick strokes swallow small scaled text.
	local subtitleOutline = Theme.textOutline(subtitle, 1.5)

	local root = Create("Frame", {
		Name = "ZoneBanner",
		Size = UDim2.fromOffset(380, 62),
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = PANEL_TRANSPARENCY,
		Visible = false,
	}, { title :: Instance, subtitle }) :: Frame
	Theme.corner(root, 16)
	local border = Theme.border(root, 3)
	Theme.padding(root, 6)

	local function setFade(alpha: number)
		local value = math.clamp(alpha, 0, 1)
		title.TextTransparency = value
		subtitle.TextTransparency = value
		titleOutline.Transparency = value
		subtitleOutline.Transparency = value
		border.Transparency = value
		root.BackgroundTransparency = PANEL_TRANSPARENCY + (1 - PANEL_TRANSPARENCY) * value
		root.Visible = value < 1
	end

	return {
		root = root,
		show = function(titleText: string, subtitleText: string, color: Color3)
			title.Text = titleText
			title.TextColor3 = color
			subtitle.Text = subtitleText
			border.Color = color
			setFade(0)
		end,
		setFade = setFade,
	}
end

return table.freeze(ZoneBanner)
