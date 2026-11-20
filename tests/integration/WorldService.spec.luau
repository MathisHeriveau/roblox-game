--!strict
--[[
	Integration: WorldService.init() against the real (headless) DataModel.

	Regression: Workspace.FallenPartsDestroyHeight is writable only with the PluginOrOpenCloud
	capability. Writing it from a game Script throws in Studio, which aborted the whole server boot
	(WorldService is booted first). Lune does not enforce capabilities, so the spec asserts the
	property is left untouched instead of expecting an error. Falls are handled by HazardService.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local WorldService = require(ServerScriptService.Server.Services.WorldService)

return function()
	describe("WorldService.init", function()
		it("never writes capability-restricted Workspace properties", function()
			local before = Workspace.FallenPartsDestroyHeight
			WorldService.init(WorldService)
			expect(Workspace.FallenPartsDestroyHeight).to.equal(before)
		end)

		it("applies the configured sky, lighting and gravity", function()
			WorldService.init(WorldService)
			-- Engine properties are float32: compare with a tolerance.
			expect(Lighting.ClockTime).to.be.near(GameConfig.World.ClockTime, 1e-4)
			expect(Lighting:FindFirstChildOfClass("Atmosphere")).to.be.ok()
			expect(Lighting:FindFirstChildOfClass("Sky")).to.be.ok()
			expect(Workspace.Gravity).to.be.near(GameConfig.Map.Gravity, 1e-3)
		end)

		it("is idempotent: effects are reused, not duplicated", function()
			WorldService.init(WorldService)
			WorldService.init(WorldService)
			local blooms = 0
			for _, child in Lighting:GetChildren() do
				if child:IsA("BloomEffect") then
					blooms += 1
				end
			end
			expect(blooms).to.equal(1)
		end)
	end)
end
