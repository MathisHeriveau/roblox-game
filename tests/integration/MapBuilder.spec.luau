--!strict
--[[
	Integration: MapLayout -> MapBuilder -> Instance tree. Runs headlessly (Lune creates real
	Instances, without physics) and in Studio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MapSystems = ServerScriptService.Server.Systems.Map
local MapBuilder = require(MapSystems.MapBuilder)
local MapLayout = require(MapSystems.MapLayout)

return function()
	describe("MapBuilder.build", function()
		local container: Folder
		local layout: MapLayout.Layout
		local result: MapBuilder.BuildResult

		beforeEach(function()
			container = Instance.new("Folder")
			layout = MapLayout.generate(GameConfig.Map)
			result = MapBuilder.build(layout, GameConfig.Map.MaxHeight, container)
		end)

		afterEach(function()
			container:Destroy()
		end)

		it("parents one Map folder with the expected sections", function()
			local map = container:FindFirstChild("Map")
			expect(map).to.be.ok()
			expect(result.root).to.equal(map)
			for _, name in { "Tiles", "Bounds", "Collectibles", "SpawnLocation" } do
				expect((map :: Instance):FindFirstChild(name)).to.be.ok()
			end
			expect(result.root:GetAttribute("Seed")).to.equal(GameConfig.Map.Seed)
		end)

		it("builds one anchored part per tile", function()
			local tiles = result.root:FindFirstChild("Tiles") :: Folder
			local children = tiles:GetChildren()
			expect(#children).to.equal(#layout.tiles)
			for _, child in children do
				expect((child :: Part).Anchored).to.equal(true)
				expect((child :: Part).CanTouch).to.equal(false)
			end
		end)

		it("places tile top surfaces at the layout height", function()
			local tiles = result.root:FindFirstChild("Tiles") :: Folder
			local sample = layout.tiles[#layout.tiles]
			local part = tiles:FindFirstChild(`Tile_{sample.gridX}_{sample.gridZ}`) :: Part
			-- CFrame.Position (not Part.Position): portable across the engine and headless runtimes.
			local top = part.CFrame.Position.Y + part.Size.Y / 2
			expect(top).to.be.near(sample.height, 1e-3)
		end)

		it("creates active, touchable, non-colliding collectibles", function()
			expect(#result.collectibles).to.equal(#layout.collectibles)
			for _, part in result.collectibles do
				expect(part:GetAttribute("Active")).to.equal(true)
				expect(type(part:GetAttribute("CollectibleId"))).to.equal("string")
				expect(part.CanCollide).to.equal(false)
				expect(part.Anchored).to.equal(true)
			end
		end)

		it("creates a neutral spawn at the plateau", function()
			local spawnLocation = result.spawnLocation
			expect(spawnLocation.Neutral).to.equal(true)
			expect(spawnLocation.CFrame.Position.X).to.equal(0)
			expect(spawnLocation.CFrame.Position.Z).to.equal(0)
		end)

		it("encloses the playable area with four invisible walls", function()
			local bounds = result.root:FindFirstChild("Bounds") :: Folder
			local walls = bounds:GetChildren()
			expect(#walls).to.equal(4)
			for _, wall in walls do
				expect((wall :: Part).Transparency).to.equal(1)
			end
		end)
	end)
end
