--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guard = require(ReplicatedStorage.Shared.Utils.Guard)

local function call(check: Guard.TupleCheck, ...: any): boolean
	return (check({ ... }, select("#", ...)))
end

return function()
	describe("Guard.number", function()
		local check = Guard.number({ min = 0, max = 10 })

		it("accepts finite numbers in range", function()
			expect((check(0))).to.equal(true)
			expect((check(10))).to.equal(true)
			expect((check(5.5))).to.equal(true)
		end)

		it("rejects NaN and infinities (classic exploit payloads)", function()
			expect((check(0 / 0))).to.equal(false)
			expect((check(math.huge))).to.equal(false)
			expect((check(-math.huge))).to.equal(false)
		end)

		it("rejects out-of-range and non-numbers", function()
			expect((check(-1))).to.equal(false)
			expect((check(11))).to.equal(false)
			expect((check("5"))).to.equal(false)
			expect((check(nil))).to.equal(false)
		end)

		it("enforces integers when asked", function()
			local integer = Guard.integer({ min = 1, max = 3 })
			expect((integer(2))).to.equal(true)
			expect((integer(2.5))).to.equal(false)
		end)
	end)

	describe("Guard.string", function()
		local check = Guard.string({ minLength = 1, maxLength = 5 })

		it("accepts strings within length bounds", function()
			expect((check("abc"))).to.equal(true)
			expect((check("héllo"))).to.equal(true) -- 5 code points, 6 bytes
		end)

		it("rejects empty, too long, invalid UTF-8 and non-strings", function()
			expect((check(""))).to.equal(false)
			expect((check("abcdef"))).to.equal(false)
			expect((check("\255\254"))).to.equal(false)
			expect((check(5))).to.equal(false)
		end)

		it("applies an optional pattern", function()
			local alnum = Guard.string({ maxLength = 10, pattern = "^%w+$" })
			expect((alnum("abc123"))).to.equal(true)
			expect((alnum("abc 123"))).to.equal(false)
		end)
	end)

	describe("Guard.oneOf / optional / boolean", function()
		it("accepts only allow-listed values", function()
			local check = Guard.oneOf({ "red", "blue" })
			expect((check("red"))).to.equal(true)
			expect((check("green"))).to.equal(false)
			expect((check(nil))).to.equal(false)
		end)

		it("optional allows nil but still validates values", function()
			local check = Guard.optional(Guard.boolean())
			expect((check(nil))).to.equal(true)
			expect((check(true))).to.equal(true)
			expect((check("true"))).to.equal(false)
		end)
	end)

	describe("Guard.tuple", function()
		local check = Guard.tuple(Guard.string({ maxLength = 8 }), Guard.integer({ min = 1, max = 99 }))

		it("accepts exactly the declared arguments", function()
			expect(call(check, "sword", 3)).to.equal(true)
		end)

		it("rejects extra arguments, including trailing nils", function()
			expect(call(check, "sword", 3, "extra")).to.equal(false)
			expect(call(check, "sword", 3, nil)).to.equal(false)
		end)

		it("rejects missing or invalid arguments with a positional message", function()
			expect(call(check, "sword")).to.equal(false)
			local ok, err = check({ "sword", 0 / 0 }, 2)
			expect(ok).to.equal(false)
			expect(string.find(err or "", "argument #2", 1, true) ~= nil).to.equal(true)
		end)

		it("an empty tuple accepts no arguments at all", function()
			local none = Guard.tuple()
			expect(call(none)).to.equal(true)
			expect(call(none, 1)).to.equal(false)
		end)
	end)
end
