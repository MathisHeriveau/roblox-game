--!strict
--[[
	JumpFlight — the client side of a jump pad flight. Pure: reads attributes, decides timing.

	A Humanoid steers its own horizontal velocity even in the air (towards MoveDirection *
	WalkSpeed, i.e. to a stop without input), so a one-off launch velocity loses its horizontal part
	within half a second. JumpPadController therefore *holds* the planned horizontal velocity for
	the whole flight and lets gravity do the vertical part, which lands exactly where MapLayout
	planned (MapLayout.launchVelocity).

	API:
	  JumpFlight.read(pad) -> { velocity, flightTime }?   validated pad attributes (nil if unusable)
	  JumpFlight.shouldRelease(elapsed, flightTime, onGround) -> boolean
]]

export type Plan = {
	velocity: Vector3,
	flightTime: number,
}

-- Ground contact right after the launch is the pad itself, not the landing.
local MIN_AIRTIME_SECONDS = 0.3
-- Safety net when the landing is missed (wall, island edge): stop pushing shortly after.
local GRACE_SECONDS = 0.6
local MAX_FLIGHT_SECONDS = 5

local JumpFlight = {
	GRACE_SECONDS = GRACE_SECONDS,
	MAX_FLIGHT_SECONDS = MAX_FLIGHT_SECONDS,
}

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

function JumpFlight.read(pad: Instance): Plan?
	local velocity = pad:GetAttribute("LaunchVelocity")
	local flightTime = pad:GetAttribute("FlightTime")
	if typeof(velocity) ~= "Vector3" or type(flightTime) ~= "number" then
		return nil
	end
	if not (finite(velocity.X) and finite(velocity.Y) and finite(velocity.Z)) then
		return nil
	end
	if not (flightTime > 0 and flightTime <= MAX_FLIGHT_SECONDS) then
		return nil
	end
	return { velocity = velocity, flightTime = flightTime }
end

function JumpFlight.shouldRelease(elapsed: number, flightTime: number, onGround: boolean): boolean
	if elapsed >= flightTime + GRACE_SECONDS then
		return true
	end
	return onGround and elapsed >= MIN_AIRTIME_SECONDS
end

return table.freeze(JumpFlight)
