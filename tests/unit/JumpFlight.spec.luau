--!strict
--[[
	JumpFlight: reading a jump pad and deciding how long its launch is held.

	Regression: the client set the launch velocity once; the Humanoid's air control then cancelled
	the horizontal part within half a second, so players flew straight up and fell back onto the
	pad. The sky islands (needed for rebirth) were unreachable. The horizontal velocity must be
	held for the whole planned flight.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local JumpFlight = require(StarterPlayer.StarterPlayerScripts.Client.Movement.JumpFlight)
local MapLayout = require(ServerScriptService.Server.Systems.Map.MapLayout)

local function pad(attributes: { [string]: any }): BasePart
	local part = Instance.new("Part")
	for key, value in attributes do
		part:SetAttribute(key, value)
	end
	return part
end

return function()
	describe("JumpFlight.read", function()
		it("reads the launch velocity and flight time of a built pad", function()
			local plan = JumpFlight.read(pad({ LaunchVelocity = Vector3.new(60, 220, 7), FlightTime = 2.2 }))
			assert(plan, "plan expected")
			expect(plan.velocity).to.equal(Vector3.new(60, 220, 7))
			expect(plan.flightTime).to.equal(2.2)
		end)

		it("ignores pads with missing or corrupt attributes", function()
			expect(JumpFlight.read(pad({ LaunchVelocity = Vector3.new(60, 220, 7) }))).to.equal(nil)
			expect(JumpFlight.read(pad({ FlightTime = 2 }))).to.equal(nil)
			expect(JumpFlight.read(pad({ LaunchVelocity = Vector3.new(0 / 0, 1, 1), FlightTime = 2 }))).to.equal(nil)
			expect(JumpFlight.read(pad({ LaunchVelocity = Vector3.new(1, math.huge, 1), FlightTime = 2 }))).to.equal(
				nil
			)
			expect(JumpFlight.read(pad({ LaunchVelocity = Vector3.new(1, 1, 1), FlightTime = 0 }))).to.equal(nil)
			expect(JumpFlight.read(pad({ LaunchVelocity = Vector3.new(1, 1, 1), FlightTime = 0 / 0 }))).to.equal(nil)
			expect(JumpFlight.read(pad({ LaunchVelocity = Vector3.new(1, 1, 1), FlightTime = 60 }))).to.equal(nil)
			expect(JumpFlight.read(pad({ LaunchVelocity = "fast", FlightTime = 2 }))).to.equal(nil)
		end)
	end)

	describe("JumpFlight.shouldRelease", function()
		it("holds the horizontal velocity for the whole planned flight (regression)", function()
			local flightTime = 2.2
			for elapsed = 0, flightTime - 0.05, 0.1 do
				-- In the air the whole time: never released before the planned landing.
				expect(JumpFlight.shouldRelease(elapsed, flightTime, false)).to.equal(false)
			end
		end)

		it("releases on landing, but not while still leaving the pad", function()
			expect(JumpFlight.shouldRelease(0.05, 2.2, true)).to.equal(false)
			expect(JumpFlight.shouldRelease(1.9, 2.2, true)).to.equal(true)
		end)

		it("always releases a little after the planned flight time (blocked by a wall, missed landing)", function()
			expect(JumpFlight.shouldRelease(2.2 + JumpFlight.GRACE_SECONDS + 0.01, 2.2, false)).to.equal(true)
		end)
	end)

	describe("held flight", function()
		it("lands on every pad's target when the horizontal velocity is held", function()
			local layout = MapLayout.generate(GameConfig.Map)
			expect(#layout.jumpPads > 0).to.equal(true)
			for _, jump in layout.jumpPads do
				local t = jump.flightTime
				local g = GameConfig.Map.Gravity
				local x = jump.position.x + jump.velocity.x * t
				local y = jump.position.y + jump.velocity.y * t - 0.5 * g * t * t
				local z = jump.position.z + jump.velocity.z * t
				expect(x).to.be.near(jump.target.x, 1e-6)
				expect(y).to.be.near(jump.target.y, 1e-6)
				expect(z).to.be.near(jump.target.z, 1e-6)
				expect(t <= JumpFlight.MAX_FLIGHT_SECONDS).to.equal(true)
			end
		end)
	end)
end
