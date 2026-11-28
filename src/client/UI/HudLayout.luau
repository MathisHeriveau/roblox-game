--!strict
--[[
	HudLayout — the left HUD column, top to bottom: coins + level (HudController), the base lock
	pill (BaseController) and the round menu rail (MenuController). Three ScreenGuis share these
	numbers so the column stays one stack.

	Why not the top-left corner: the Roblox chat window lives there (legacy chat and
	TextChatService alike) and covered the coin counter whenever chat was visible (playtest
	2026-11-28). The column is centred a little below the middle of the safe area instead.

	Offsets are design pixels: every HUD ScreenGui's UIScale (Theme.scaleFor) scales offsets and
	sizes but not the scale part of a position. Every item uses AnchorPoint (0, 0).

	API: coinsPosition(), lockPosition(), railPosition() -> UDim2; columnSpan(height, scale) ->
	(top, bottom) in pixels of the safe area; the size constants below.
]]

local HudLayout = {
	-- Fraction of the safe-area height where the column's centre sits.
	COLUMN_CENTER = 0.66,
	LEFT = 18,
	RAIL_LEFT = 14,
	COINS_HEIGHT = 150,
	LOCK_HEIGHT = 40,
	RAIL_HEIGHT = 170,
	GAP = 8,
}

local function columnHeight(): number
	return HudLayout.COINS_HEIGHT + HudLayout.GAP + HudLayout.LOCK_HEIGHT + HudLayout.GAP + HudLayout.RAIL_HEIGHT
end

-- Offsets (design px) of each item's top edge from the column centre.
local function coinsTop(): number
	return -columnHeight() / 2
end

local function lockTop(): number
	return coinsTop() + HudLayout.COINS_HEIGHT + HudLayout.GAP
end

local function railTop(): number
	return lockTop() + HudLayout.LOCK_HEIGHT + HudLayout.GAP
end

function HudLayout.coinsPosition(): UDim2
	return UDim2.new(0, HudLayout.LEFT, HudLayout.COLUMN_CENTER, coinsTop())
end

function HudLayout.lockPosition(): UDim2
	return UDim2.new(0, HudLayout.LEFT, HudLayout.COLUMN_CENTER, lockTop())
end

function HudLayout.railPosition(): UDim2
	return UDim2.new(0, HudLayout.RAIL_LEFT, HudLayout.COLUMN_CENTER, railTop())
end

-- Top and bottom of the whole column, in pixels of a safe area `height` tall at UI `scale`.
function HudLayout.columnSpan(height: number, scale: number): (number, number)
	local center = height * HudLayout.COLUMN_CENTER
	return center + coinsTop() * scale, center + (railTop() + HudLayout.RAIL_HEIGHT) * scale
end

return table.freeze(HudLayout)
