--!strict
-- Template: copy to tests/unit/<Module>.spec.luau and adapt. Demonstrates fake clocks,
-- abuse inputs and multi-return assertions.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

return function()
	describe("RateLimiter (template example)", function()
		local now = 0
		local function clock(): number
			return now
		end

		beforeEach(function()
			now = 0
		end)

		it("normal: allows up to capacity", function()
			local limiter = RateLimiter.new({ capacity = 2, refillPerSecond = 1, clock = clock })
			expect(limiter:tryConsume("player")).to.equal(true)
			expect(limiter:tryConsume("player")).to.equal(true)
		end)

		it("boundary: blocks exactly at capacity, refills with time", function()
			local limiter = RateLimiter.new({ capacity = 1, refillPerSecond = 1, clock = clock })
			limiter:tryConsume("player")
			expect(limiter:tryConsume("player")).to.equal(false)
			now += 1
			expect(limiter:tryConsume("player")).to.equal(true)
		end)

		it("invalid: rejects impossible configuration", function()
			expect(function()
				RateLimiter.new({ capacity = 0, refillPerSecond = 1 })
			end).to.throw()
		end)
	end)
end
