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

		-- Surface fill = the layer whose rendered top lands on the tile height. Regression: Roblox
		-- renders a filled block's top half a voxel (2 studs) higher, so every surface stood 2 studs
		-- above the layout (plot floors buried, lava out of reach). Engine side: TerrainSurface.spec.
		local function surfaceArea(): { [MapLayout.Tile]: number }
			local covered: { [MapLayout.Tile]: number } = {}
			for _, fill in fills do
				local position = fill.cframe.Position
				local tile = MapLayout.tileAt(layout, position.X, position.Z)
				local top = position.Y + fill.size.Y / 2 + MapBuilder.TERRAIN_SURFACE_OFFSET
				if tile and math.abs(top - tile.height) < 1e-3 then
					covered[tile] = (covered[tile] or 0) + fill.size.X * fill.size.Z
				end
			end
			return covered
		end

		it("covers every tile's surface exactly, at the tile height", function()
			local covered = surfaceArea()
			for _, tile in layout.tiles do
				expect(covered[tile]).to.be.near(layout.tileSize * layout.tileSize, 1e-6)
			end
			expect(MapBuilder.TERRAIN_SURFACE_OFFSET).to.equal(2)
		end)

		it("fills earth or rock under every surface, down to the tile bottom", function()
			local lowest: { [MapLayout.Tile]: number } = {}
			for _, fill in fills do
				local position = fill.cframe.Position
				local tile = MapLayout.tileAt(layout, position.X, position.Z)
				if tile then
					local bottom = position.Y - fill.size.Y / 2
					lowest[tile] = math.min(lowest[tile] or math.huge, bottom)
				end
			end
			for _, tile in layout.tiles do
				expect(lowest[tile]).to.be.near(tile.bottom, 1e-3)
			end
		end)

		it("paints every material it uses", function()
			for _, fill in fills do
				expect(colors[fill.material]).to.be.ok()
			end
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
	describe("MapBuilder.terrainPlan", function()
		local layout = MapLayout.generate(GameConfig.Map)
		local plans = MapBuilder.terrainPlan(layout)
		local cells = MapBuilder.SURFACE_DIVISIONS * MapBuilder.SURFACE_DIVISIONS

		it("puts lava only on the tiles that burn, and fully on them", function()
			for _, plan in plans do
				expect(#plan.surface).to.equal(cells)
				for _, material in plan.surface do
					expect(material == Enum.Material.CrackedLava).to.equal(plan.tile.kind == "lava")
				end
			end
		end)

		it("mixes materials inside zones instead of one flat colour", function()
			local perTier: { [number]: { [Enum.Material]: boolean } } = {}
			for _, plan in plans do
				if plan.tile.kind ~= "lava" then
					perTier[plan.tile.tier] = perTier[plan.tile.tier] or {}
					for _, material in plan.surface do
						perTier[plan.tile.tier][material] = true
					end
				end
			end
			for tier = 1, #Zones.list do
				local materials: { [Enum.Material]: boolean } = perTier[tier] or {}
				local count = 0
				for _ in materials do
					count += 1
				end
				expect(count >= 2).to.equal(true)
				-- The zone's own material stays the main one.
				expect(materials[Zones.get(tier).topMaterial]).to.equal(true)
			end
		end)

		it("puts earth under grass and is deterministic", function()
			local again = MapBuilder.terrainPlan(layout)
			for index, plan in plans do
				if plan.tile.tier == 1 and plan.tile.kind ~= "lava" then
					expect(plan.band).to.equal(Enum.Material.Ground)
				end
				for cell, material in plan.surface do
					expect(again[index].surface[cell]).to.equal(material)
				end
			end
		end)
	end)
	describe("MapBuilder.decorPlan", function()
		local layout = MapLayout.generate(GameConfig.Map)
		local decor = MapBuilder.decorPlan(layout)

		it("scatters a bounded amount of decor, deterministically", function()
			expect(#decor > 300).to.equal(true)
			expect(#decor <= MapBuilder.MAX_DECOR).to.equal(true)
			local again = MapBuilder.decorPlan(layout)
			expect(#again).to.equal(#decor)
			for index, item in decor do
				expect(again[index].x).to.equal(item.x)
				expect(again[index].kind).to.equal(item.kind)
			end
		end)

		it("stays on ground tiles, off the plaza, lava and jump pads", function()
			for _, item in decor do
				local tile = MapLayout.tileAt(layout, item.x, item.z)
				assert(tile, "decor outside the island")
				expect(tile.tier > 0).to.equal(true)
				expect(tile.kind).to.equal("ground")
				expect(item.y).to.equal(tile.height)
				for _, pad in layout.jumpPads do
					local dx, dz = item.x - pad.position.x, item.z - pad.position.z
					expect(math.sqrt(dx * dx + dz * dz) >= MapBuilder.DECOR_PAD_CLEARANCE).to.equal(true)
				end
			end
		end)

		it("builds decor that nothing can collide with or hit", function()
			local container = Instance.new("Folder")
			local writer = {
				fillBlock = function() end,
				setMaterialColor = function() end,
			}
			local result = MapBuilder.build(layout, container, writer :: any)
			local folder = result.root:FindFirstChild("Decor") :: Folder
			assert(folder, "Decor folder expected")
			local parts = folder:GetChildren()
			expect(#parts >= #decor).to.equal(true)
			for _, child in parts do
				local part = child :: BasePart
				expect(part.CanCollide).to.equal(false)
				expect(part.CanQuery).to.equal(false)
				expect(part.Anchored).to.equal(true)
			end
			container:Destroy()
		end)
	end)
end
