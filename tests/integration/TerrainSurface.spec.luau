--!strict
--[[
	Integration (Studio only): the rendered Terrain surface matches the layout heights.

	Regression: Workspace.Terrain draws a FillBlock's top half a voxel (2 studs) above the block,
	whatever the height, so the whole island stood 2 studs above MapLayout: plot floors were
	buried under the plaza and standing in lava stayed out of HazardRules' reach.
	Skipped headlessly — Lune has no voxel engine.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local MapBuilder = require(ServerScriptService.Server.Systems.Map.MapBuilder)

-- Far from the island: nothing else is built there.
local ORIGIN = Vector3.new(4000, 0, 4000)
local TILE_SIZE = 16

return function()
	describe("Terrain surface (Studio)", function()
		if __LUNE_RUNTIME__ then
			SKIP()
		end

		it("renders each tile's surface at its layout height", function()
			local terrain = Workspace.Terrain
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { terrain }
			local clear = function()
				terrain:FillBlock(CFrame.new(ORIGIN), Vector3.new(96, 96, 96), Enum.Material.Air)
			end
			for _, height in { 0, 1, 2.5, 7, 13 } do
				-- A 3x3 block of equal tiles so the centre is not smoothed by empty neighbours.
				for dx = -1, 1 do
					for dz = -1, 1 do
						local tile = { x = ORIGIN.X + dx * TILE_SIZE, z = ORIGIN.Z + dz * TILE_SIZE, height = height }
						local cframe, size = MapBuilder.surfaceBlock(tile, TILE_SIZE)
						terrain:FillBlock(cframe, size, Enum.Material.Grass)
					end
				end
				task.wait()
				local hit = Workspace:Raycast(ORIGIN + Vector3.new(0, 80, 0), Vector3.new(0, -160, 0), params)
				clear()
				expect(hit).to.be.ok()
				expect((hit :: RaycastResult).Position.Y).to.be.near(height, 0.1)
			end
		end)
	end)
end
