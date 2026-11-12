--!strict
--[[
	MapBuilder — turns a MapLayout.Layout into Instances.

	Kept separate from MapLayout so generation logic stays pure. The builder only does
	Instance work and never yields, so it can run during a service's init() and finish before
	any character spawns.

	Output tree (parented to `parent` in one step, after it is fully built):
	  Map (Folder)
	    Tiles (Folder)          Anchored terrain columns
	    Bounds (Folder)         Invisible walls keeping players on the map
	    Collectibles (Folder)   Parts tagged with attribute CollectibleId
	    SpawnLocation
]]

local MapLayout = require(script.Parent.MapLayout)

export type BuildResult = {
	root: Folder,
	spawnLocation: SpawnLocation,
	collectibles: { BasePart },
}

-- Tiles extend this far below Y = 0 so terraces look solid.
local BASE_DEPTH = 8
local WALL_HEIGHT = 64
local WALL_THICKNESS = 2

local LOW_COLOR = Color3.fromRGB(86, 148, 72)
local HIGH_COLOR = Color3.fromRGB(150, 134, 108)
local COLLECTIBLE_COLOR = Color3.fromRGB(255, 200, 40)

local MapBuilder = {}

local function makeFolder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function buildTile(tile: MapLayout.Tile, layout: MapLayout.Layout, maxHeight: number, parent: Instance)
	local columnHeight = tile.height + BASE_DEPTH
	local part = Instance.new("Part")
	part.Name = `Tile_{tile.gridX}_{tile.gridZ}`
	part.Anchored = true
	part.CanTouch = false -- terrain never needs Touched events; saves physics work
	part.Size = Vector3.new(layout.tileSize, columnHeight, layout.tileSize)
	part.CFrame = CFrame.new(tile.x, tile.height - columnHeight / 2, tile.z)
	part.Material = if tile.height >= maxHeight * 0.6 then Enum.Material.Rock else Enum.Material.Grass
	local alpha = if maxHeight > 0 then tile.height / maxHeight else 0
	part.Color = LOW_COLOR:Lerp(HIGH_COLOR, alpha)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
end

local function buildWalls(layout: MapLayout.Layout, parent: Instance)
	local extent = layout.extent
	local span = extent * 2 + WALL_THICKNESS * 2
	local y = WALL_HEIGHT / 2 - BASE_DEPTH
	local walls = {
		{
			name = "North",
			size = Vector3.new(span, WALL_HEIGHT, WALL_THICKNESS),
			x = 0,
			z = -extent - WALL_THICKNESS / 2,
		},
		{
			name = "South",
			size = Vector3.new(span, WALL_HEIGHT, WALL_THICKNESS),
			x = 0,
			z = extent + WALL_THICKNESS / 2,
		},
		{
			name = "West",
			size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, span),
			x = -extent - WALL_THICKNESS / 2,
			z = 0,
		},
		{
			name = "East",
			size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, span),
			x = extent + WALL_THICKNESS / 2,
			z = 0,
		},
	}
	for _, wall in walls do
		local part = Instance.new("Part")
		part.Name = `Wall{wall.name}`
		part.Anchored = true
		part.CanTouch = false
		part.CanQuery = false
		part.Transparency = 1
		part.Size = wall.size
		part.CFrame = CFrame.new(wall.x, y, wall.z)
		part.Parent = parent
	end
end

local function buildCollectible(collectible: MapLayout.Collectible, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = collectible.id
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(2, 2, 2)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = COLLECTIBLE_COLOR
	part.CFrame = CFrame.new(collectible.x, collectible.y, collectible.z)
	part:SetAttribute("CollectibleId", collectible.id)
	part:SetAttribute("Active", true)
	part.Parent = parent
	return part
end

function MapBuilder.build(layout: MapLayout.Layout, maxHeight: number, parent: Instance): BuildResult
	local root = Instance.new("Folder")
	root.Name = "Map"
	root:SetAttribute("Seed", layout.seed)

	local tilesFolder = makeFolder("Tiles", root)
	for _, tile in layout.tiles do
		buildTile(tile, layout, maxHeight, tilesFolder)
	end

	buildWalls(layout, makeFolder("Bounds", root))

	local collectiblesFolder = makeFolder("Collectibles", root)
	local collectibles = table.create(#layout.collectibles)
	for _, collectible in layout.collectibles do
		table.insert(collectibles, buildCollectible(collectible, collectiblesFolder))
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "SpawnLocation"
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0 -- no spawn ForceField
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.CFrame = CFrame.new(layout.spawn.x, layout.spawn.y + 0.5, layout.spawn.z)
	spawnLocation.Material = Enum.Material.SmoothPlastic
	spawnLocation.Color = Color3.fromRGB(235, 235, 235)
	spawnLocation.Parent = root

	-- Parent last: replication and listeners see one complete map, not hundreds of partial updates.
	root.Parent = parent

	return {
		root = root,
		spawnLocation = spawnLocation,
		collectibles = collectibles,
	}
end

return table.freeze(MapBuilder)
