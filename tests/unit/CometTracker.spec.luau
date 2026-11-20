--!strict
--[[
	CometTracker: what the comet banner says, from the warning to a few seconds after the crash.

	Regression: the client cleared the comet as soon as the server announced the impact, so the
	"grab the core!" call to action was never shown and the target marker vanished at the moment
	players needed it to find the core.
]]

local StarterPlayer = game:GetService("StarterPlayer")

local CometTracker = require(StarterPlayer.StarterPlayerScripts.Client.Hud.CometTracker)

return function()
	describe("CometTracker", function()
		it("counts down to the crash", function()
			local tracker = CometTracker.new()
			expect(tracker:status(0)).to.equal(nil)
			tracker:warn(100, "Lava Fields")
			local status = tracker:status(80)
			assert(status, "status expected")
			expect(status.title).to.equal("COMET INCOMING!")
			expect(string.find(status.subtitle, "Lava Fields", 1, true) ~= nil).to.equal(true)
			expect(string.find(status.subtitle, "0:20", 1, true) ~= nil).to.equal(true)
		end)

		it("keeps calling players to the core for a while after the impact event (regression)", function()
			local tracker = CometTracker.new()
			tracker:warn(100, "Crystal Desert")
			tracker:impact(100.05)
			local status = tracker:status(101)
			assert(status, "the banner must stay after the impact")
			expect(string.find(status.subtitle, "grab the core", 1, true) ~= nil).to.equal(true)
			expect(string.find(status.subtitle, "Crystal Desert", 1, true) ~= nil).to.equal(true)
			expect(tracker:status(100 + CometTracker.LINGER_SECONDS - 0.1)).to.be.ok()
			expect(tracker:status(100 + CometTracker.LINGER_SECONDS + 0.1)).to.equal(nil)
			-- Once over, it stays over.
			expect(tracker:status(101)).to.equal(nil)
		end)

		it("treats an early impact event as the crash time", function()
			local tracker = CometTracker.new()
			tracker:warn(100, "Lava Fields")
			tracker:impact(98)
			local status = tracker:status(99)
			assert(status, "status expected")
			expect(string.find(status.subtitle, "grab the core", 1, true) ~= nil).to.equal(true)
			expect(tracker:status(98 + CometTracker.LINGER_SECONDS + 0.1)).to.equal(nil)
		end)

		it("ends a comet that never got its impact event", function()
			local tracker = CometTracker.new()
			tracker:warn(100, "Lava Fields")
			expect(tracker:status(100 + CometTracker.LINGER_SECONDS + 0.1)).to.equal(nil)
		end)

		it("replaces the previous comet on a new warning, and ignores stray impacts", function()
			local tracker = CometTracker.new()
			tracker:impact(5)
			expect(tracker:status(5)).to.equal(nil)
			tracker:warn(100, "Lava Fields")
			tracker:warn(300, "Crystal Desert")
			local status = tracker:status(290)
			assert(status, "status expected")
			expect(string.find(status.subtitle, "Crystal Desert", 1, true) ~= nil).to.equal(true)
		end)
	end)
end
