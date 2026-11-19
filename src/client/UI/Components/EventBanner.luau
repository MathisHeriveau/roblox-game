--!strict
--[[
	EventBanner — sky event UI: a small countdown pill (next meteor shower / comet) and the big
	purple "COMET INCOMING" banner from the art style sheet.
]]

local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

export type EventBanner = {
	root: Frame,
	setCountdowns: (meteorText: string, cometText: string) -> (),
	showComet: (title: string, subtitle: string) -> (),
	hideComet: () -> (),
}

local EventBanner = {}

function EventBanner.new(): EventBanner
	local meteorLine = Create("TextLabel", {
		Name = "Meteor",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.5),
		Font = Theme.Font.Body,
		Text = "",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
	}) :: TextLabel
	Theme.textOutline(meteorLine, 2)
	local cometLine = Create("TextLabel", {
		Name = "Comet",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 0.5),
		Font = Theme.Font.Body,
		Text = "",
		TextColor3 = Theme.Color.TextDim,
		TextScaled = true,
	}) :: TextLabel
	Theme.textOutline(cometLine, 2)

	local pill = Create("Frame", {
		Name = "Countdowns",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(300, 54),
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 0.15,
	}, { meteorLine, cometLine }) :: Frame
	Theme.corner(pill, 16)
	Theme.border(pill, 3)
	Theme.padding(pill, 5)

	local title = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(92, 6),
		Size = UDim2.new(1, -104, 0.55, -6),
		Font = Theme.Font.Title,
		Text = "",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}) :: TextLabel
	Theme.textOutline(title, 3)
	local subtitle = Create("TextLabel", {
		Name = "Subtitle",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 92, 0.55, 0),
		Size = UDim2.new(1, -104, 0.45, -8),
		Font = Theme.Font.Body,
		Text = "",
		TextColor3 = Theme.Color.Gold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}) :: TextLabel
	Theme.textOutline(subtitle, 2)
	local icon = Create("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(74, 74),
		Font = Theme.Font.Body,
		Text = "☄️",
		TextScaled = true,
	})

	local banner = Create("Frame", {
		Name = "CometBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(520, 92),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
	}, { icon, title, subtitle }) :: Frame
	Theme.corner(banner, 22)
	Theme.border(banner, 4)
	Theme.gradient(banner, Theme.Color.Purple, Theme.Color.PurpleDark)

	local root = Create("Frame", {
		Name = "EventBanner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(520, 160),
	}, { pill, banner }) :: Frame

	return {
		root = root,
		setCountdowns = function(meteorText: string, cometText: string)
			meteorLine.Text = meteorText
			cometLine.Text = cometText
		end,
		showComet = function(titleText: string, subtitleText: string)
			title.Text = titleText
			subtitle.Text = subtitleText
			banner.Visible = true
		end,
		hideComet = function()
			banner.Visible = false
		end,
	}
end

return table.freeze(EventBanner)
