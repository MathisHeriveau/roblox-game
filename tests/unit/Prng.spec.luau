--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prng = require(ReplicatedStorage.Shared.Utils.Prng)

return function()
	describe("Prng", function()
		it("produces the same sequence for the same seed", function()
			local a = Prng.new(12345)
			local b = Prng.new(12345)
			for _ = 1, 100 do
				expect(a:nextUInt32()).to.equal(b:nextUInt32())
			end
		end)

		it("produces different sequences for different seeds", function()
			local a = Prng.new(1)
			local b = Prng.new(2)
			local identical = 0
			for _ = 1, 50 do
				if a:nextUInt32() == b:nextUInt32() then
					identical += 1
				end
			end
			expect(identical < 5).to.equal(true)
		end)

		it("treats seed 0 as a valid seed", function()
			local rng = Prng.new(0)
			expect(rng:nextUInt32() ~= 0).to.equal(true)
		end)

		it("keeps nextNumber within [0, 1)", function()
			local rng = Prng.new(99)
			for _ = 1, 1000 do
				local n = rng:nextNumber()
				expect(n >= 0 and n < 1).to.equal(true)
			end
		end)

		it("keeps nextInteger within inclusive bounds and reaches both ends", function()
			local rng = Prng.new(7)
			local seenMin, seenMax = false, false
			for _ = 1, 2000 do
				local n = rng:nextInteger(-2, 2)
				expect(n >= -2 and n <= 2).to.equal(true)
				expect(math.floor(n)).to.equal(n)
				seenMin = seenMin or n == -2
				seenMax = seenMax or n == 2
			end
			expect(seenMin).to.equal(true)
			expect(seenMax).to.equal(true)
		end)

		it("is roughly uniform", function()
			local rng = Prng.new(2026)
			local buckets = { 0, 0, 0, 0 }
			local samples = 8000
			for _ = 1, samples do
				local bucket = rng:nextInteger(1, 4)
				buckets[bucket] += 1
			end
			for _, count in buckets do
				expect(count).to.be.near(samples / 4, samples * 0.04)
			end
		end)

		it("rejects invalid arguments", function()
			expect(function()
				Prng.new(0 / 0)
			end).to.throw()
			expect(function()
				Prng.new(1):nextInteger(5, 1)
			end).to.throw()
		end)
	end)
end
