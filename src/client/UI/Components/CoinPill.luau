--!strict
--[[
	CoinPill — the gold coin counter with its "+" (open shop) button and the income line below.
	Pure Instance construction: testable headlessly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(script.Parent.Parent.Create)
local Format = require(ReplicatedStorage.Shared.Game.Format)
local Theme = require(script.Parent.Parent.Theme)

export type CoinPill = {
	root: Frame,
	plusButton: TextButton,
	setCoins: (coins: number) -> (),
	setIncome: (perSecond: number, vault: number) -> (),
}

local CoinPill = {}

function CoinPill.new(): CoinPill
	local value = Create("TextLabel", {
		Name = "Value",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(66, 6),
		Size = UDim2.new(1, -122, 1, -12),
		Font = Theme.Font.Title,
		Text = "0",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}) :: TextLabel
	Theme.textOutline(value)

	local symbol = Create("TextLabel", {
		Name = "Symbol",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Font.Title,
		Text = "$",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
	}) :: TextLabel
	Theme.textOutline(symbol)
	local coin = Create("Frame", {
		Name = "Coin",
		Size = UDim2.fromOffset(62, 62),
		Position = UDim2.fromOffset(-6, -2),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, { symbol }) :: Frame
	Theme.corner(coin)
	Theme.border(coin, 3)
	Theme.gradient(coin, Theme.Color.Gold, Theme.Color.GoldDark)
	Theme.padding(coin, 10)

	local plusButton = Create("TextButton", {
		Name = "Plus",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = Theme.Font.Title,
		Text = "+",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
		AutoButtonColor = true,
	}) :: TextButton
	Theme.corner(plusButton)
	Theme.border(plusButton, 2)
	Theme.gradient(plusButton, Theme.Color.Gold, Theme.Color.GoldDark)
	Theme.textOutline(plusButton)

	local pill = Create("Frame", {
		Name = "Pill",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = Theme.Color.Panel,
	}, { value :: Instance, coin, plusButton }) :: Frame
	Theme.corner(pill)
	Theme.border(pill, 3)

	local income = Create("TextLabel", {
		Name = "Income",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(66, 62),
		Size = UDim2.new(1, -66, 0, 24),
		Font = Theme.Font.Body,
		Text = "",
		TextColor3 = Theme.Color.Income,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}) :: TextLabel
	Theme.textOutline(income, 2)

	local root = Create("Frame", {
		Name = "CoinPill",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(270, 90),
	}, { pill :: Instance, income }) :: Frame

	return {
		root = root,
		plusButton = plusButton,
		setCoins = function(coins: number)
			value.Text = Format.compact(coins)
		end,
		setIncome = function(perSecond: number, vault: number)
			if perSecond <= 0 then
				income.Text = "Bring shards to your base!"
			elseif vault > 0 then
				income.Text = `+{Format.compact(perSecond)}/s · 💰{Format.compact(vault)} at base`
			else
				income.Text = `+{Format.compact(perSecond)}/s`
			end
		end,
	}
end

return table.freeze(CoinPill)
