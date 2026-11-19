--!strict
--[[
	MapBuilder — turns a MapLayout.Layout into the world: smooth Terrain for the ground, Parts for
	decorations, the central monument, the plaza spawn and invisible bounds.

	Terrain access goes through an injected TerrainWriter so the builder is testable headlessly
	(tests record the calls; production wraps Workspace.Terrain). Never yields: safe in init().
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapLayout = require(script.Parent.MapLayout)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

export type TerrainWriter = {
	fillBlock: (self: TerrainWriter, cframe: CFrame, size: Vector3, material: Enum.Material) -> (),
	setMaterialColor: (self: TerrainWriter, material: Enum.Material, color: Color3) -> (),
}

export type BuildResult = {
	root: Folder,
	spawnLocation: SpawnLocation,
}

local TOP_THICKNESS = 4
local WALL_HEIGHT = 400
local HUB_MATERIAL = Enum.Material.Pavement
local HUB_COLOR = Color3.fromRGB(156, 148, 196)
local ROCK_MATERIAL = Enum.Material.Rock
local ROCK_COLOR = Color3.fromRGB(92, 76, 146)
local LAVA_MATERIAL = Enum.Material.CrackedLava
local LAVA_COLOR = Color3.fromRGB(255, 92, 24)

local MapBuilder = {}

function MapBuilder.terrainWriter(terrain: Terrain): TerrainWriter
	local writer = {}
	function writer.fillBlock(_self: TerrainWriter, cframe: CFrame, size: Vector3, material: Enum.Material)
		terrain:FillBlock(cframe, size, material)
	end
	function writer.setMaterialColor(_self: TerrainWriter, material: Enum.Material, color: Color3)
		terrain:SetMaterialColor(material, color)
	end
	return writer :: any
end

local function part(props: { [string]: any }, parent: Instance): Part
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.CanTouch = false
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function folder(name: string, parent: Instance): Folder
	local instance = Instance.new("Folder")
	instance.Name = name
	instance.Parent = parent
	return instance
end

--------------------------------------------------------------------------------------------------
-- Terrain
--------------------------------------------------------------------------------------------------

local function topMaterial(tile: MapLayout.Tile): Enum.Material
	if tile.tier == 0 then
		return HUB_MATERIAL
	elseif tile.kind == "lava" then
		return LAVA_MATERIAL
	end
	return Zones.get(tile.tier).topMaterial
end

local function buildTerrain(layout: MapLayout.Layout, writer: TerrainWriter)
	writer:setMaterialColor(HUB_MATERIAL, HUB_COLOR)
	writer:setMaterialColor(ROCK_MATERIAL, ROCK_COLOR)
	writer:setMaterialColor(LAVA_MATERIAL, LAVA_COLOR)
	for _, zone in Zones.list do
		writer:setMaterialColor(zone.topMaterial, zone.topColor)
	end

	local size = layout.tileSize
	for _, tile in layout.tiles do
		local top = tile.height
		writer:fillBlock(
			CFrame.new(tile.x, top - TOP_THICKNESS / 2, tile.z),
			Vector3.new(size, TOP_THICKNESS, size),
			topMaterial(tile)
		)
		local rockTop = top - TOP_THICKNESS
		local rockHeight = rockTop - tile.bottom
		if rockHeight > 0 then
			writer:fillBlock(
				CFrame.new(tile.x, tile.bottom + rockHeight / 2, tile.z),
				Vector3.new(size, rockHeight, size),
				ROCK_MATERIAL
			)
		end
	end
end

--------------------------------------------------------------------------------------------------
-- Props
--------------------------------------------------------------------------------------------------

local function baseCFrame(prop: MapLayout.Prop): CFrame
	return CFrame.new(prop.x, prop.y, prop.z) * CFrame.Angles(0, prop.yaw, 0)
end

local function buildTree(prop: MapLayout.Prop, parent: Instance)
	local s = prop.scale
	local base = baseCFrame(prop)
	local model = Instance.new("Model")
	model.Name = "Tree"
	part({
		Name = "Trunk",
		Size = Vector3.new(2 * s, 8 * s, 2 * s),
		CFrame = base * CFrame.new(0, 4 * s, 0),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(116, 78, 50),
	}, model)
	part({
		Name = "Leaves",
		Size = Vector3.new(8 * s, 6 * s, 8 * s),
		CFrame = base * CFrame.new(0, 10 * s, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(70, 160, 72),
	}, model)
	part({
		Name = "LeavesTop",
		Size = Vector3.new(5 * s, 4 * s, 5 * s),
		CFrame = base * CFrame.new(0.6 * s, 14 * s, -0.4 * s),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(96, 190, 86),
	}, model)
	model.Parent = parent
end

local function buildCrystal(prop: MapLayout.Prop, parent: Instance)
	local s = prop.scale
	local base = baseCFrame(prop)
	local model = Instance.new("Model")
	model.Name = "Crystal"
	local colors = { Color3.fromRGB(179, 102, 255), Color3.fromRGB(140, 110, 255), Color3.fromRGB(210, 150, 255) }
	for index, offset in { { 0, 0, 0 }, { 1.8, -12, 1.2 }, { -1.6, 14, -0.8 } } do
		local height = (8 - index * 1.6) * s
		part({
			Name = "Shard",
			Size = Vector3.new(1.8 * s, height, 1.8 * s),
			CFrame = base
				* CFrame.new(offset[1] * s, height / 2 - 0.5, offset[3] * s)
				* CFrame.Angles(math.rad(offset[2]), math.rad(45), math.rad(offset[2] / 2)),
			Material = Enum.Material.Neon,
			Color = colors[index],
			Transparency = 0.15,
			CastShadow = false,
		}, model)
	end
	model.Parent = parent
end

local function buildRock(prop: MapLayout.Prop, parent: Instance)
	local s = prop.scale
	part({
		Name = "Rock",
		Size = Vector3.new(5 * s, 4 * s, 4 * s),
		CFrame = baseCFrame(prop) * CFrame.new(0, 1.5 * s, 0) * CFrame.Angles(math.rad(12), 0, math.rad(-8)),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(58, 44, 54),
	}, parent)
end

local function buildPillar(prop: MapLayout.Prop, parent: Instance)
	local s = prop.scale
	local base = baseCFrame(prop)
	local model = Instance.new("Model")
	model.Name = "SkyPillar"
	part({
		Name = "Base",
		Size = Vector3.new(4 * s, 2 * s, 4 * s),
		CFrame = base * CFrame.new(0, 1 * s, 0),
		Material = Enum.Material.Rock,
		Color = ROCK_COLOR,
	}, model)
	part({
		Name = "Crystal",
		Size = Vector3.new(2.4 * s, 10 * s, 2.4 * s),
		CFrame = base * CFrame.new(0, 7 * s, 0) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(190, 172, 255),
		Transparency = 0.2,
		CastShadow = false,
	}, model)
	model.Parent = parent
end

local function buildFloatingIsland(prop: MapLayout.Prop, parent: Instance)
	local s = prop.scale
	local base = baseCFrame(prop)
	local model = Instance.new("Model")
	model.Name = "FloatingIsland"
	part({
		Name = "Top",
		Size = Vector3.new(16 * s, 3 * s, 16 * s),
		CFrame = base,
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(86, 178, 78),
	}, model)
	part({
		Name = "Rock",
		Size = Vector3.new(12 * s, 9 * s, 12 * s),
		CFrame = base * CFrame.new(0, -6 * s, 0),
		Material = Enum.Material.Rock,
		Color = ROCK_COLOR,
	}, model)
	part({
		Name = "RockTip",
		Size = Vector3.new(6 * s, 6 * s, 6 * s),
		CFrame = base * CFrame.new(0, -13 * s, 0) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Rock,
		Color = ROCK_COLOR,
	}, model)
	model.Parent = parent
end

local PROP_BUILDERS: { [MapLayout.PropKind]: (MapLayout.Prop, Instance) -> () } = {
	tree = buildTree,
	crystal = buildCrystal,
	rock = buildRock,
	pillar = buildPillar,
	floatingIsland = buildFloatingIsland,
}

--------------------------------------------------------------------------------------------------
-- Landmarks
--------------------------------------------------------------------------------------------------

local function buildMonument(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "StarMonument"
	part({
		Name = "Plinth",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 18, 18),
		CFrame = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(92, 76, 146),
	}, model)
	part({
		Name = "Column",
		Size = Vector3.new(3, 12, 3),
		CFrame = CFrame.new(0, 9, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(230, 226, 245),
	}, model)
	local starCenter = CFrame.new(0, 19, 0)
	local core = part({
		Name = "StarCore",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		CFrame = starCenter,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 205, 64),
		CastShadow = false,
	}, model)
	for index = 0, 4 do
		part({
			Name = "StarRay",
			Size = Vector3.new(2.4, 4.4, 1.6),
			CFrame = starCenter * CFrame.Angles(0, 0, math.rad(index * 72)) * CFrame.new(0, 3.6, 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 196, 40),
			CastShadow = false,
		}, model)
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 120)
	light.Range = 40
	light.Brightness = 2
	light.Parent = core
	model.PrimaryPart = core
	model.Parent = parent
end

local function buildBounds(layout: MapLayout.Layout, parent: Instance)
	local extent = (layout.radius + 7) * layout.tileSize
	local span = extent * 2
	type Wall = { name: string, size: Vector3, position: Vector3 }
	local walls: { Wall } = {
		{ name = "North", size = Vector3.new(span, WALL_HEIGHT, 2), position = Vector3.new(0, 0, -extent) },
		{ name = "South", size = Vector3.new(span, WALL_HEIGHT, 2), position = Vector3.new(0, 0, extent) },
		{ name = "West", size = Vector3.new(2, WALL_HEIGHT, span), position = Vector3.new(-extent, 0, 0) },
		{ name = "East", size = Vector3.new(2, WALL_HEIGHT, span), position = Vector3.new(extent, 0, 0) },
	}
	for _, wall in walls do
		part({
			Name = `Wall{wall.name}`,
			Size = wall.size,
			CFrame = CFrame.new(wall.position),
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
		}, parent)
	end
end

--------------------------------------------------------------------------------------------------
-- Entry point
--------------------------------------------------------------------------------------------------

function MapBuilder.build(layout: MapLayout.Layout, parent: Instance, writer: TerrainWriter): BuildResult
	buildTerrain(layout, writer)

	local root = Instance.new("Folder")
	root.Name = "Map"
	root:SetAttribute("Seed", layout.seed)

	local props = folder("Props", root)
	for _, prop in layout.props do
		local builder = PROP_BUILDERS[prop.kind]
		if builder then
			builder(prop, props)
		end
	end

	local landmarks = folder("Landmarks", root)
	buildMonument(landmarks)
	buildBounds(layout, folder("Bounds", root))

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "PlazaSpawn"
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.CFrame = CFrame.new(0, 0.5, 22)
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Color = Color3.fromRGB(150, 132, 240)
	spawnLocation.Transparency = 0.35
	spawnLocation.TopSurface = Enum.SurfaceType.Smooth
	spawnLocation.Parent = landmarks

	-- Parent last: one replication burst for the whole map.
	root.Parent = parent

	return { root = root, spawnLocation = spawnLocation }
end

return table.freeze(MapBuilder)
