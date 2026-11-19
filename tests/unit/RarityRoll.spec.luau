--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prng = require(ReplicatedStorage.Shared.Utils.Prng)
local RarityRoll = require(ReplicatedStorage.Shared.Game.RarityRoll)

return function()
	describe("RarityRoll.pick", function()
		it("never picks zero-weight entries", function()
			local rng = Prng.new(5)
			for _ = 1, 2000 do
				local pick = RarityRoll.pick(rng, { 0, 3, 0, 1 })
				expect(pick == 2 or pick == 4).to.equal(true)
			end
		end)

		it("follows the weights", function()
			local rng = Prng.new(11)
			local counts = { 0, 0 }
			for _ = 1, 10000 do
				local pick = RarityRoll.pick(rng, { 3, 1 })
				counts[pick] += 1
			end
			expect(counts[1]).to.be.near(7500, 300)
		end)

		it("is deterministic for a seed", function()
			local a, b = Prng.new(99), Prng.new(99)
			for _ = 1, 100 do
				expect(RarityRoll.pick(a, { 1, 2, 3 })).to.equal(RarityRoll.pick(b, { 1, 2, 3 }))
			end
		end)

		it("rejects empty or invalid weights", function()
			expect(function()
				RarityRoll.pick(Prng.new(1), { 0, 0 })
			end).to.throw()
			expect(function()
				RarityRoll.pick(Prng.new(1), { 1, -1 })
			end).to.throw()
		end)
	end)
end
