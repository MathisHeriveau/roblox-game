--!strict
--[[
	CarryIndicator — "✦ 2 / 3" pill above the bottom of the screen, gold when full, plus the
	contextual hint telling the player what to do next.
]]

local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

export type CarryIndicator = {
	root: Frame,
	setCarry: (carrying: number, capacity: number) -> (),
}

local CarryIndicator = {}

function CarryIndicator.new(): CarryIndicator
	local count = Create("TextLabel", {
		Name = "Count",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Font.Title,
		Text = "✦ 0 / 1",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
	}) :: TextLabel
	Theme.textOutline(count)

	local pill = Create("Frame", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(170, 48),
		BackgroundColor3 = Theme.Color.Panel,
	}, { count }) :: Frame
	Theme.corner(pill)
	local border = Theme.border(pill, 3)
	Theme.padding(pill, 7)

	local hint = Create("TextLabel", {
		Name = "Hint",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 26),
		Font = Theme.Font.Body,
		Text = "Grab glowing shards!",
		TextColor3 = Theme.Color.TextDim,
		TextScaled = true,
	}) :: TextLabel
	Theme.textOutline(hint, 2)

	local root = Create("Frame", {
		Name = "CarryIndicator",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(420, 80),
	}, { pill :: Instance, hint }) :: Frame

	return {
		root = root,
		setCarry = function(carrying: number, capacity: number)
			count.Text = `✦ {carrying} / {capacity}`
			local full = carrying >= capacity and capacity > 0
			border.Color = if full then Theme.Color.Gold else Theme.Color.Outline
			if carrying == 0 then
				hint.Text = "Grab glowing shards! · [F] bump carriers"
			elseif full then
				hint.Text = "Hands full! Run back to your base"
			else
				hint.Text = "Bring them home to hatch Starlings"
			end
		end,
	}
end

return table.freeze(CarryIndicator)
