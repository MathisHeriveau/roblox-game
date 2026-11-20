--!strict
--[[
	Integration: MapLayout -> MapBuilder. Terrain goes through a recording fake writer (Lune has no
	voxel engine); Parts are real Instances.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MapSystems = ServerScriptService.Server.Systems.Map
local MapBuilder = require(MapSystems.MapBuilder)
local MapLayout = require(MapSystems.MapLayout)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

type Fill = { cframe: CFrame, size: Vector3, material: Enum.Material }

local function fakeWriter(): (MapBuilder.TerrainWriter, { Fill }, { [Enum.Material]: Color3 })
	local fills: { Fill } = {}
	local colors: { [Enum.Material]: Color3 } = {}
	local writer = {}
	function writer.fillBlock(_self: any, cframe: CFrame, size: Vector3, material: Enum.Material)
		table.insert(fills, { cframe = cframe, size = size, material = material })
	end
	function writer.setMaterialColor(_self: any, material: Enum.Material, color: Color3)
		colors[material] = color
	end
	return writer :: any, fills, colors
end

return function()
	describe("MapBuilder.build", function()
		local layout: MapLayout.Layout
		local container: Folder
		local result: MapBuilder.BuildResult
		local fills: { Fill }
		local colors: { [Enum.Material]: Color3 }

		beforeAll(function()
			layout = MapLayout.generate(GameConfig.Map)
		end)

		beforeEach(function()
			container = Instance.new("Folder")
			local writer
			writer, fills, colors = fakeWriter()
			result = MapBuilder.build(layout, container, writer)
		end)

		afterEach(function()
			container:Destroy()
		end)

		it("paints every zone's terrain colour", function()
			for _, zone in Zones.list do
				expect(colors[zone.topMaterial]).to.equal(zone.topColor)
			end
			expect(colors[Enum.Material.CrackedLava]).to.be.ok()
		end)

		it("fills a surface block (and rock underneath) for every tile", function()
			local surfaces = 0
			for _, fill in fills do
				if fill.material ~= Enum.Material.Rock then
					surfaces += 1
				end
				expect(fill.size.X).to.equal(layout.tileSize)
				expect(fill.size.Y > 0).to.equal(true)
			end
			expect(surfaces).to.equal(#layout.tiles)
			expect(#fills > #layout.tiles).to.equal(true)
		end)

		-- Regression: Roblox renders a filled block's top half a voxel (2 studs) higher, so every
		-- surface stood 2 studs above the layout (plot floors buried, lava out of reach). The
		-- engine side is checked by TerrainSurface.spec (Studio only).
		it("fills each surface block so the rendered surface lands on the tile height", function()
			local tile = layout.tiles[1]
			local checked = 0
			for _, fill in fills do
				local position = fill.cframe.Position
				if position.X == tile.x and position.Z == tile.z and fill.material ~= Enum.Material.Rock then
					expect(position.Y + fill.size.Y / 2 + MapBuilder.TERRAIN_SURFACE_OFFSET).to.be.near(
						tile.height,
						1e-6
					)
					checked += 1
				end
			end
			expect(checked).to.equal(1)
			expect(MapBuilder.TERRAIN_SURFACE_OFFSET).to.equal(2)
		end)

		it("parents one Map folder with props, landmarks, bounds and the plaza spawn", function()
			local map = container:FindFirstChild("Map")
			expect(map).to.equal(result.root)
			for _, name in { "Props", "Landmarks", "Bounds" } do
				expect(result.root:FindFirstChild(name)).to.be.ok()
			end
			expect(#(result.root:FindFirstChild("Props") :: Folder):GetChildren()).to.equal(#layout.props)
			expect(#(result.root:FindFirstChild("Bounds") :: Folder):GetChildren()).to.equal(4)
			local pads = result.root:FindFirstChild("JumpPads") :: Folder
			expect(#pads:GetChildren()).to.equal(#layout.jumpPads)
			for _, pad in pads:GetChildren() do
				expect(pad:HasTag("JumpPad")).to.equal(true)
				expect(typeof(pad:GetAttribute("LaunchVelocity"))).to.equal("Vector3")
				-- The client holds the horizontal launch for this long (JumpFlight).
				expect(type(pad:GetAttribute("FlightTime"))).to.equal("number")
			end
			for index, jump in layout.jumpPads do
				local name = if jump.kind == "up" then `JumpPad{jump.island}` else `ReturnPad{jump.island}`
				local built = pads:FindFirstChild(name) :: BasePart
				expect(built:GetAttribute("FlightTime")).to.be.near(layout.jumpPads[index].flightTime, 1e-6)
			end
			expect(result.spawnLocation.Neutral).to.equal(true)
			expect(result.root:GetAttribute("Seed")).to.equal(layout.seed)
		end)
	end)
end
