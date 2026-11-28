--!strict
--[[
	Motion is cosmetic: without TweenService (headless) it must leave the UI in its resting state
	and never throw.
]]

local StarterPlayer = game:GetService("StarterPlayer")

local Motion = require(StarterPlayer.StarterPlayerScripts.Client.UI.Motion)

return function()
	describe("Motion", function()
		it("leaves a popped modal at its resting scale", function()
			local scale = Instance.new("UIScale")
			scale.Scale = 0.8
			Motion.popIn(scale)
			if __LUNE_RUNTIME__ then
				expect(scale.Scale).to.be.near(0.8, 1e-4)
			end
		end)

		it("starts and stops a pulse without leaving the target scaled", function()
			local badge = Instance.new("TextLabel")
			Motion.pulse(badge, true)
			Motion.pulse(badge, false)
			local pulse = badge:FindFirstChild("PulseScale") :: UIScale
			assert(pulse, "pulse scale expected")
			expect(pulse.Scale).to.be.near(1, 1e-4)
			badge:Destroy()
		end)

		it("binds press feedback without throwing, and skips buttons that own a UIScale", function()
			local plain = Instance.new("TextButton")
			Motion.bindPress(plain)
			local owned = Instance.new("TextButton")
			local own = Instance.new("UIScale")
			own.Parent = owned
			Motion.bindPress(owned)
			expect(owned:FindFirstChild("PressScale")).to.equal(nil)
			plain:Destroy()
			owned:Destroy()
		end)
	end)
end
