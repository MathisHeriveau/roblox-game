--!strict
--[[
	StarlingBob: the resting pose and bobbing of pedestal Starlings (client-side animation).

	Regression (playtest 2026-11-28): the "Starling" tag replicated before the model's parts, so
	AmbientController read GetPivot() while the model was still empty (the default pivot, the world
	origin) and kept pivoting every delivered Starling to (0, 0, 0), buried under the plaza. Players
	never saw the Starlings they hatched.
]]

local StarterPlayer = game:GetService("StarterPlayer")

local StarlingBob = require(StarterPlayer.StarterPlayerScripts.Client.Effects.StarlingBob)

local function starling(at: CFrame?): Model
	local model = Instance.new("Model")
	if at then
		local core = Instance.new("Part")
		core.Name = "Core"
		core.CFrame = at
		core.Parent = model
		model.PrimaryPart = core
	end
	return model
end

return function()
	describe("StarlingBob.restPose", function()
		it("waits for the core part instead of returning the world origin", function()
			expect(StarlingBob.restPose(starling(nil))).to.equal(nil)
		end)

		it("rests where the server placed the core", function()
			local at = CFrame.new(49.9, 4.8, 10) * CFrame.Angles(0, math.rad(90), 0)
			local pose = StarlingBob.restPose(starling(at))
			expect(pose).to.be.ok()
			local position = (pose :: CFrame).Position
			expect(position.X).to.be.near(49.9, 1e-3)
			expect(position.Y).to.be.near(4.8, 1e-3)
			expect(position.Z).to.be.near(10, 1e-3)
		end)
	end)

	describe("StarlingBob.offset", function()
		it("bobs a little around the resting pose, never far from it", function()
			for step = 0, 200 do
				local offset = StarlingBob.offset(step * 0.05, 1.3)
				expect(math.abs(offset.Position.Y) <= StarlingBob.AMPLITUDE + 1e-6).to.equal(true)
				expect(offset.Position.X).to.be.near(0, 1e-6)
				expect(offset.Position.Z).to.be.near(0, 1e-6)
			end
		end)
	end)
end
