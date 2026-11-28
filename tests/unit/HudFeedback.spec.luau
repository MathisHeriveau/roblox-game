--!strict
--[[
	HudFeedback: which HUD celebrations a state change deserves.
	Playtest 2026-11-28: levelling up and earning coins happened in silence.
]]

local StarterPlayer = game:GetService("StarterPlayer")

local HudFeedback = require(StarterPlayer.StarterPlayerScripts.Client.Hud.HudFeedback)

return function()
	describe("HudFeedback.compare", function()
		it("never celebrates the first state of a session", function()
			local feedback = HudFeedback.compare(nil, { level = 7, coins = 5000 })
			expect(feedback.levelUp).to.equal(nil)
			expect(feedback.coinsGained).to.equal(0)
		end)

		it("reports a level up with the new level", function()
			local feedback = HudFeedback.compare({ level = 2, coins = 10 }, { level = 3, coins = 10 })
			expect(feedback.levelUp).to.equal(3)
		end)

		it("reports several levels at once as the last one", function()
			expect(HudFeedback.compare({ level = 2, coins = 0 }, { level = 5, coins = 0 }).levelUp).to.equal(5)
		end)

		it("stays quiet on the same level", function()
			expect(HudFeedback.compare({ level = 4, coins = 0 }, { level = 4, coins = 0 }).levelUp).to.equal(nil)
		end)

		it("counts only coins gained, never spent", function()
			expect(HudFeedback.compare({ level = 1, coins = 100 }, { level = 1, coins = 250 }).coinsGained).to.equal(
				150
			)
			expect(HudFeedback.compare({ level = 1, coins = 250 }, { level = 1, coins = 50 }).coinsGained).to.equal(0)
		end)

		it("does not celebrate the level reset of a rebirth", function()
			expect(HudFeedback.compare({ level = 30, coins = 2e6 }, { level = 1, coins = 0 }).levelUp).to.equal(nil)
		end)
	end)
end
