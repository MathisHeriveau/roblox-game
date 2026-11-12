--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lifecycle = require(ReplicatedStorage.Shared.Utils.Lifecycle)

-- Runs start() immediately so ordering is observable without a scheduler.
local function immediate(fn: () -> ())
	fn()
end

return function()
	describe("Lifecycle.boot", function()
		it("runs every init() in order before any start()", function()
			local log = {}
			local function module(name: string): Lifecycle.Module
				return {
					name = name,
					init = function()
						table.insert(log, `init:{name}`)
					end,
					start = function()
						table.insert(log, `start:{name}`)
					end,
				}
			end
			Lifecycle.boot({ module("A"), module("B") }, immediate)
			expect(table.concat(log, ",")).to.equal("init:A,init:B,start:A,start:B")
		end)

		it("fails fast when an init() errors, before starting anything", function()
			local started = false
			expect(function()
				Lifecycle.boot({
					{
						name = "Broken",
						init = function()
							error("cannot init")
						end,
						start = function() end,
					},
					{
						name = "Other",
						init = function() end,
						start = function()
							started = true
						end,
					},
				}, immediate)
			end).to.throw()
			expect(started).to.equal(false)
		end)

		it("rejects an init() that yields", function()
			expect(function()
				Lifecycle.boot({
					{
						name = "Yielder",
						init = function()
							coroutine.yield()
						end,
						start = function() end,
					},
				}, immediate)
			end).to.throw()
		end)

		it("isolates a failing start() from the others", function()
			local reached = false
			Lifecycle.boot({
				{
					name = "Crashes",
					init = function() end,
					start = function()
						error("start failed")
					end,
				},
				{
					name = "Healthy",
					init = function() end,
					start = function()
						reached = true
					end,
				},
			}, immediate)
			expect(reached).to.equal(true)
		end)

		it("rejects duplicate names and missing phases", function()
			local noop = function() end
			expect(function()
				Lifecycle.boot({
					{ name = "Same", init = noop, start = noop },
					{ name = "Same", init = noop, start = noop },
				}, immediate)
			end).to.throw()
			expect(function()
				Lifecycle.boot({ { name = "NoStart", init = noop } :: any }, immediate)
			end).to.throw()
		end)
	end)
end
