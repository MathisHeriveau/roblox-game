--!strict
--[[
	CollectPadRules: the vault is banked once per visit to the collect pad.

	Regression: BaseService banked the vault on every collect tick while the owner stood on the pad,
	so a player waiting there got a "+💰1" toast every second (stacked 4 high, over the shop).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local CollectPadRules = require(ServerScriptService.Server.Systems.Base.CollectPadRules)

-- Plays a sequence of on/off-pad ticks; the vault earns `income` per tick. Returns bank count.
local function simulate(onPadTicks: { boolean }, income: number): (number, number)
	local wasOnPad = false
	local vault = 0
	local banks = 0
	for _, isOnPad in onPadTicks do
		vault += income
		if CollectPadRules.shouldBank(wasOnPad, isOnPad, vault) then
			banks += 1
			vault = 0
		end
		wasOnPad = isOnPad
	end
	return banks, vault
end

return function()
	describe("CollectPadRules.shouldBank", function()
		it("banks once when stepping on the pad, not on every tick spent standing there (regression)", function()
			local banks, vault = simulate({ false, true, true, true, true, true, true, true, true, true }, 1)
			expect(banks).to.equal(1)
			-- Income earned while standing waits for the next visit.
			expect(vault).to.equal(8)
		end)

		it("banks again on the next visit", function()
			local banks = simulate({ true, true, false, false, true, true, false, true }, 5)
			expect(banks).to.equal(3)
		end)

		it("needs something to bank", function()
			expect(CollectPadRules.shouldBank(false, true, 0)).to.equal(false)
			expect(CollectPadRules.shouldBank(false, true, 12)).to.equal(true)
			expect(CollectPadRules.shouldBank(true, true, 12)).to.equal(false)
			expect(CollectPadRules.shouldBank(false, false, 12)).to.equal(false)
		end)

		it("rejects corrupt vault values", function()
			expect(CollectPadRules.shouldBank(false, true, 0 / 0)).to.equal(false)
			expect(CollectPadRules.shouldBank(false, true, -5)).to.equal(false)
			expect(CollectPadRules.shouldBank(false, true, math.huge)).to.equal(false)
		end)
	end)
end
