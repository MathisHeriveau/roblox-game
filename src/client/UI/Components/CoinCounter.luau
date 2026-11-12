--!strict
--[[
	CoinCounter — HUD widget showing the player's coins and pickups.

	Responsive by construction: sizes are scale-based with min/max pixel constraints, text uses
	TextScaled with a size cap, and the widget anchors to the top-right inside the safe area.
	Pure Instance construction (no services), so it is testable headlessly.
]]

local Create = require(script.Parent.Parent.Create)

export type CoinCounter = {
	root: Frame,
	setState: (coins: number, collected: number) -> (),
}

local CoinCounter = {}

-- 1234567 -> "1,234,567". Non-finite or negative input renders as "0" (display never throws).
function CoinCounter.formatNumber(value: number): string
	if value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return "0"
	end
	local digits = tostring(math.floor(value))
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

function CoinCounter.new(): CoinCounter
	local coinsLabel = Create("TextLabel", {
		Name = "Coins",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.6),
		Position = UDim2.fromScale(0, 0),
		Font = Enum.Font.GothamBold,
		Text = "0",
		TextColor3 = Color3.fromRGB(255, 214, 64),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, {
		Create("UITextSizeConstraint", { MaxTextSize = 36 }),
	}) :: TextLabel

	local collectedLabel = Create("TextLabel", {
		Name = "Collected",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.4),
		Position = UDim2.fromScale(0, 0.6),
		Font = Enum.Font.Gotham,
		Text = "0 pickups",
		TextColor3 = Color3.fromRGB(235, 235, 235),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, {
		Create("UITextSizeConstraint", { MaxTextSize = 20 }),
	}) :: TextLabel

	local root = Create("Frame", {
		Name = "CoinCounter",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromScale(0.22, 0.1),
		BackgroundColor3 = Color3.fromRGB(20, 20, 28),
		BackgroundTransparency = 0.25,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		-- Keeps the widget legible on phones and unobtrusive on large monitors.
		Create("UISizeConstraint", {
			MinSize = Vector2.new(140, 52),
			MaxSize = Vector2.new(320, 96),
		}),
		coinsLabel,
		collectedLabel,
	}) :: Frame

	local function setState(coins: number, collected: number)
		coinsLabel.Text = CoinCounter.formatNumber(coins)
		collectedLabel.Text = `{CoinCounter.formatNumber(collected)} pickups`
	end

	return {
		root = root,
		setState = setState,
	}
end

return table.freeze(CoinCounter)
