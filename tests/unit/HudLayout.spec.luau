--!strict
--[[
	HudLayout: the left HUD column (coins + level, base lock pill, menu rail).

	Regression (playtest 2026-11-28): the coin counter and level badge sat in the top-left corner,
	under the Roblox chat window, which covers roughly the top third of the screen on desktop.
]]

local StarterPlayer = game:GetService("StarterPlayer")

local Client = StarterPlayer.StarterPlayerScripts.Client
local HudLayout = require(Client.UI.HudLayout)
local Theme = require(Client.UI.Theme)

-- Viewport (pixels) and the height left once Roblox's top bar is removed (CoreUISafeInsets).
local SCREENS = {
	{ name = "phone landscape", viewport = Vector2.new(844, 390), safeHeight = 354 },
	{ name = "Studio window", viewport = Vector2.new(1101, 751), safeHeight = 693 },
	{ name = "laptop", viewport = Vector2.new(1366, 768), safeHeight = 710 },
	{ name = "1080p", viewport = Vector2.new(1920, 1080), safeHeight = 1022 },
	{ name = "4K", viewport = Vector2.new(3840, 2160), safeHeight = 2102 },
}

-- The chat window's share of the screen height (legacy chat measured at ~31 % in Studio).
local CHAT_SHARE = 0.32

return function()
	describe("HudLayout", function()
		it("stacks coins, lock pill and rail top to bottom without overlap", function()
			local coins = HudLayout.coinsPosition()
			local lock = HudLayout.lockPosition()
			local rail = HudLayout.railPosition()
			expect(coins.Y.Scale).to.equal(lock.Y.Scale)
			expect(lock.Y.Scale).to.equal(rail.Y.Scale)
			expect(coins.Y.Offset + HudLayout.COINS_HEIGHT <= lock.Y.Offset).to.equal(true)
			expect(lock.Y.Offset + HudLayout.LOCK_HEIGHT <= rail.Y.Offset).to.equal(true)
		end)

		for _, screen in SCREENS do
			it(`stays on screen and below the chat window ({screen.name})`, function()
				local scale = Theme.scaleFor(screen.viewport)
				local top, bottom = HudLayout.columnSpan(screen.safeHeight, scale)
				-- The chat window starts right under the top bar, where the safe area starts too.
				local chatBottom = screen.viewport.Y * CHAT_SHARE
				expect(top >= chatBottom).to.equal(true)
				expect(bottom <= screen.safeHeight).to.equal(true)
			end)
		end
	end)
end
