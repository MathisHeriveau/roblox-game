--!strict
--[[
	StarlingBob — where a pedestal Starling rests and how it bobs (AmbientController animates it).

	The "Starling" tag can replicate before the model's parts. Until its core (PrimaryPart) is
	there, the model's pivot is the default one, the world origin, and animating around it buried
	every Starling under the plaza. `restPose` returns nil until the core exists: callers retry
	on a later frame.

	API: restPose(model) -> CFrame?, offset(time, phase) -> CFrame, AMPLITUDE (studs).
]]

local StarlingBob = {
	-- Vertical bob amplitude (studs).
	AMPLITUDE = 0.35,
}

local BOB_SPEED = 2.2
local SWAY_SPEED = 0.9
local SWAY_ANGLE = 0.45

-- The pose the server gave the Starling, or nil while its core part has not replicated yet.
function StarlingBob.restPose(model: Model): CFrame?
	local core = model.PrimaryPart
	if core == nil then
		return nil
	end
	-- StarlingBuilder centres the model on its core (no PivotOffset).
	return core.CFrame
end

-- Local offset from the resting pose at `time` (seconds); `phase` desynchronises Starlings.
function StarlingBob.offset(time: number, phase: number): CFrame
	return CFrame.new(0, math.sin(time * BOB_SPEED + phase) * StarlingBob.AMPLITUDE, 0)
		* CFrame.Angles(0, math.sin(time * SWAY_SPEED + phase) * SWAY_ANGLE, 0)
end

return table.freeze(StarlingBob)
