--!strict
--[[
	Escape boost (owner's idea): a bumped player gets a short speed burst to get away. It must be
	a noticeable but bounded burst, and must not outlast the bump immunity (a boosted player who
	could not be bumped back for longer would dominate chases).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

return function()
	describe("Escape boost tuning", function()
		local bump = GameConfig.Bump

		it("is a noticeable but bounded speed burst", function()
			expect(bump.EscapeBoostFactor > 1.15).to.equal(true)
			expect(bump.EscapeBoostFactor <= 1.6).to.equal(true)
		end)

		it("never outlasts the bump immunity", function()
			expect(bump.EscapeBoostSeconds > 0).to.equal(true)
			expect(bump.EscapeBoostSeconds <= bump.ImmunitySeconds).to.equal(true)
		end)
	end)
end
