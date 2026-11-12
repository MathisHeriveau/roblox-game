--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

return function()
	describe("RateLimiter", function()
		local now = 0
		local function clock(): number
			return now
		end

		beforeEach(function()
			now = 0
		end)

		it("allows a burst up to capacity, then blocks", function()
			local limiter = RateLimiter.new({ capacity = 3, refillPerSecond = 1, clock = clock })
			expect(limiter:tryConsume("a")).to.equal(true)
			expect(limiter:tryConsume("a")).to.equal(true)
			expect(limiter:tryConsume("a")).to.equal(true)
			expect(limiter:tryConsume("a")).to.equal(false)
		end)

		it("refills over time without exceeding capacity", function()
			local limiter = RateLimiter.new({ capacity = 2, refillPerSecond = 1, clock = clock })
			limiter:tryConsume("a")
			limiter:tryConsume("a")
			expect(limiter:tryConsume("a")).to.equal(false)
			now = 1
			expect(limiter:tryConsume("a")).to.equal(true)
			expect(limiter:tryConsume("a")).to.equal(false)
			now = 100
			expect(limiter:tryConsume("a")).to.equal(true)
			expect(limiter:tryConsume("a")).to.equal(true)
			expect(limiter:tryConsume("a")).to.equal(false)
		end)

		it("isolates keys from each other", function()
			local limiter = RateLimiter.new({ capacity = 1, refillPerSecond = 0, clock = clock })
			expect(limiter:tryConsume("a")).to.equal(true)
			expect(limiter:tryConsume("a")).to.equal(false)
			expect(limiter:tryConsume("b")).to.equal(true)
		end)

		it("supports weighted costs", function()
			local limiter = RateLimiter.new({ capacity = 5, refillPerSecond = 0, clock = clock })
			expect(limiter:tryConsume("a", 4)).to.equal(true)
			expect(limiter:tryConsume("a", 2)).to.equal(false)
			expect(limiter:tryConsume("a", 1)).to.equal(true)
		end)

		it("releases memory with remove()", function()
			local limiter = RateLimiter.new({ capacity = 1, refillPerSecond = 0, clock = clock })
			limiter:tryConsume("a")
			limiter:tryConsume("b")
			expect(limiter:size()).to.equal(2)
			limiter:remove("a")
			expect(limiter:size()).to.equal(1)
			-- A removed key starts again with a full bucket.
			expect(limiter:tryConsume("a")).to.equal(true)
		end)

		it("ignores a clock that goes backwards", function()
			local limiter = RateLimiter.new({ capacity = 1, refillPerSecond = 1, clock = clock })
			now = 10
			limiter:tryConsume("a")
			now = 5
			expect(limiter:tryConsume("a")).to.equal(false)
		end)
	end)
end
