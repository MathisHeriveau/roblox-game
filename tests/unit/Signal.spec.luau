--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Utils.Signal)

return function()
	describe("Signal", function()
		it("calls handlers in connection order with arguments", function()
			local signal = Signal.new() :: Signal.Signal<string, number>
			local calls = {}
			signal:connect(function(name, value)
				table.insert(calls, `first:{name}:{value}`)
			end)
			signal:connect(function(name, value)
				table.insert(calls, `second:{name}:{value}`)
			end)
			signal:fire("x", 1)
			expect(#calls).to.equal(2)
			expect(calls[1]).to.equal("first:x:1")
			expect(calls[2]).to.equal("second:x:1")
		end)

		it("stops calling a disconnected handler", function()
			local signal = Signal.new() :: Signal.Signal<>
			local count = 0
			local connection = signal:connect(function()
				count += 1
			end)
			signal:fire()
			connection:disconnect()
			signal:fire()
			expect(count).to.equal(1)
			expect(connection.connected).to.equal(false)
		end)

		it("once() fires a single time", function()
			local signal = Signal.new() :: Signal.Signal<>
			local count = 0
			signal:once(function()
				count += 1
			end)
			signal:fire()
			signal:fire()
			expect(count).to.equal(1)
		end)

		it("keeps notifying other handlers when one errors", function()
			local signal = Signal.new() :: Signal.Signal<>
			local reached = false
			signal:connect(function()
				error("boom")
			end)
			signal:connect(function()
				reached = true
			end)
			signal:fire()
			expect(reached).to.equal(true)
		end)

		it("disconnectAll() removes every handler", function()
			local signal = Signal.new() :: Signal.Signal<>
			local count = 0
			signal:connect(function()
				count += 1
			end)
			signal:disconnectAll()
			signal:fire()
			expect(count).to.equal(0)
		end)
	end)
end
