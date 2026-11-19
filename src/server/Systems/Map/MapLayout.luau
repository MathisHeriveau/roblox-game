--!strict
--[[
	MapLayout — pure, deterministic generation of the Comet Raiders island.

	A circular floating island centred on the origin, made of square tiles:
	  - hub (tier 0): flat plaza holding the player bases
	  - four concentric rings (Zones), each higher and richer than the previous one
	  - lava pits in the Lava Fields, decorations (props) per zone, floating islands around

	Guarantees (unit-tested):
	  - same seed => identical layout
	  - neighbouring walkable tiles never differ by more than MaxStep studs, so every zone is
	    reachable on foot from the hub
	  - shard impact candidates are walkable, prop-free tiles of the right zone

	Coordinates: `x`/`z` are tile centres in studs; `height` is the top surface Y; `bottom` is the
	underside Y of the rock column.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prng = require(ReplicatedStorage.Shared.Utils.Prng)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

export type Config = {
	Seed: number,
	MaxStep: number,
	UndersideBase: number,
	UndersideSlope: number,
	TreeChance: number,
	CrystalChance: number,
	RockChance: number,
	PillarChance: number,
	FloatingIslands: number,
}

export type TileKind = "ground" | "lava"

export type Tile = {
	gridX: number,
	gridZ: number,
	x: number,
	z: number,
	-- Distance from the centre, in tiles.
	distance: number,
	-- 0 = hub, 1..Zones.COUNT = rings.
	tier: number,
	kind: TileKind,
	height: number,
	bottom: number,
	hasProp: boolean,
}

export type PropKind = "tree" | "crystal" | "rock" | "pillar" | "floatingIsland"

export type Prop = {
	kind: PropKind,
	x: number,
	y: number,
	z: number,
	yaw: number,
	scale: number,
	tier: number,
}

export type Layout = {
	seed: number,
	tileSize: number,
	radius: number,
	gridSize: number,
	tiles: { Tile },
	-- Grid lookup: index[gridX * gridSize + gridZ + 1] -> Tile (see MapLayout.tileAt).
	index: { [number]: Tile },
	-- Walkable, prop-free tiles where shards may land, per zone tier (1..Zones.COUNT).
	impactCandidates: { { Tile } },
	props: { Prop },
}

local LAVA_PIT_DEPTH = 2

local MapLayout = {}

local function key(gridX: number, gridZ: number, gridSize: number): number
	return gridX * gridSize + gridZ + 1
end

-- Smoothed value noise in [0, 1] for every grid cell.
local function noiseGrid(rng: Prng.Prng, size: number, passes: number): { { number } }
	local grid: { { number } } = table.create(size)
	for x = 1, size do
		local column = table.create(size)
		for z = 1, size do
			column[z] = rng:nextNumber()
		end
		grid[x] = column
	end
	for _ = 1, passes do
		local smoothed: { { number } } = table.create(size)
		for x = 1, size do
			local column = table.create(size)
			for z = 1, size do
				local sum, count = 0, 0
				for dx = -1, 1 do
					for dz = -1, 1 do
						local neighbour = grid[x + dx] and grid[x + dx][z + dz]
						if neighbour ~= nil then
							sum += neighbour
							count += 1
						end
					end
				end
				column[z] = sum / count
			end
			smoothed[x] = column
		end
		grid = smoothed
	end
	return grid
end

-- Lowers tiles until no walkable neighbour pair differs by more than maxStep (hub stays fixed at 0).
local function enforceMaxStep(tiles: { Tile }, byKey: { [number]: Tile }, gridSize: number, maxStep: number)
	local changed = true
	local guard = 0
	while changed and guard < 200 do
		changed = false
		guard += 1
		for _, tile in tiles do
			if tile.kind == "ground" then
				for _, offset in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local neighbour = byKey[key(tile.gridX + offset[1], tile.gridZ + offset[2], gridSize)]
					if neighbour and neighbour.kind == "ground" and tile.height - neighbour.height > maxStep then
						tile.height = neighbour.height + maxStep
						changed = true
					end
				end
			end
		end
	end
end

function MapLayout.validateConfig(config: Config): (boolean, string?)
	if config.MaxStep <= 0 then
		return false, "MaxStep must be > 0"
	end
	for _, field in { "TreeChance", "CrystalChance", "RockChance", "PillarChance" } do
		local value = (config :: any)[field] :: number
		if value < 0 or value > 1 then
			return false, `{field} must be within [0, 1]`
		end
	end
	if config.FloatingIslands < 0 then
		return false, "FloatingIslands must be >= 0"
	end
	return true, nil
end

function MapLayout.generate(config: Config): Layout
	local valid, err = MapLayout.validateConfig(config)
	assert(valid, `MapLayout: invalid config: {err}`)

	local rng = Prng.new(config.Seed)
	local tileSize = Zones.TILE_SIZE
	local radius = Zones.RADIUS
	local gridSize = radius * 2 + 1
	local center = radius
	local heightNoise = noiseGrid(rng, gridSize, 2)
	local lavaNoise = noiseGrid(rng, gridSize, 1)

	local tiles: { Tile } = {}
	local byKey: { [number]: Tile } = {}

	for gridX = 0, gridSize - 1 do
		for gridZ = 0, gridSize - 1 do
			local dx, dz = gridX - center, gridZ - center
			local distance = math.sqrt(dx * dx + dz * dz)
			local tier = Zones.tierForDistance(distance)
			if tier ~= nil then
				local height = 0
				if tier > 0 then
					local zone = Zones.get(tier)
					local n = heightNoise[gridX + 1][gridZ + 1]
					-- Gentle outward ramp inside each ring so zones flow into each other.
					local ringProgress = (distance - Zones.HUB_RADIUS - (tier - 1) * Zones.WIDTH) / Zones.WIDTH
					height = math.floor(zone.baseHeight + n * zone.heightAmplitude + ringProgress * 3 + 0.5)
				end
				local tile: Tile = {
					gridX = gridX,
					gridZ = gridZ,
					x = dx * tileSize,
					z = dz * tileSize,
					distance = distance,
					tier = tier,
					kind = "ground",
					height = height,
					bottom = -(config.UndersideBase + (radius - distance) * config.UndersideSlope),
					hasProp = false,
				}
				table.insert(tiles, tile)
				byKey[key(gridX, gridZ, gridSize)] = tile
			end
		end
	end

	-- Lava pools: in zones with lavaChance > 0, the tiles with the lowest (smoothed) lava noise
	-- become lava. Using the noise quantile gives clustered pools and an exact proportion.
	for tier = 1, Zones.COUNT do
		local chance = Zones.get(tier).lavaChance
		if chance > 0 then
			local zoneTiles: { Tile } = {}
			for _, tile in tiles do
				if tile.tier == tier then
					table.insert(zoneTiles, tile)
				end
			end
			table.sort(zoneTiles, function(a, b)
				return lavaNoise[a.gridX + 1][a.gridZ + 1] < lavaNoise[b.gridX + 1][b.gridZ + 1]
			end)
			for index = 1, math.floor(#zoneTiles * chance) do
				zoneTiles[index].kind = "lava"
			end
		end
	end

	enforceMaxStep(tiles, byKey, gridSize, config.MaxStep)

	-- Lava pits sit slightly below their surroundings.
	for _, tile in tiles do
		if tile.kind == "lava" then
			local lowest = math.huge
			for _, offset in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local neighbour = byKey[key(tile.gridX + offset[1], tile.gridZ + offset[2], gridSize)]
				if neighbour and neighbour.kind == "ground" then
					lowest = math.min(lowest, neighbour.height)
				end
			end
			if lowest == math.huge then
				lowest = tile.height
			end
			tile.height = lowest - LAVA_PIT_DEPTH
		end
	end

	-- Props (decorations). Tiles with a prop never receive shards.
	local props: { Prop } = {}
	local function addProp(tile: Tile, kind: PropKind, scaleMin: number, scaleMax: number)
		tile.hasProp = true
		local jitter = tileSize * 0.25
		table.insert(props, {
			kind = kind,
			x = tile.x + rng:nextRange(-jitter, jitter),
			y = tile.height,
			z = tile.z + rng:nextRange(-jitter, jitter),
			yaw = rng:nextRange(0, math.pi * 2),
			scale = rng:nextRange(scaleMin, scaleMax),
			tier = tile.tier,
		})
	end

	for _, tile in tiles do
		local roll = rng:nextNumber()
		-- Keep the outer edge of the hub clear so plots and paths stay open.
		if tile.kind == "ground" and tile.distance > Zones.HUB_RADIUS + 0.75 then
			if tile.tier == 1 and roll < config.TreeChance then
				addProp(tile, "tree", 0.8, 1.3)
			elseif tile.tier == 2 and roll < config.CrystalChance then
				addProp(tile, "crystal", 0.7, 1.4)
			elseif tile.tier == 3 and roll < config.RockChance then
				addProp(tile, "rock", 0.8, 1.5)
			elseif tile.tier == 4 and roll < config.PillarChance then
				addProp(tile, "pillar", 0.8, 1.3)
			end
		end
	end

	-- Decorative floating islands around the main island (not walkable targets).
	for _ = 1, config.FloatingIslands do
		local angle = rng:nextRange(0, math.pi * 2)
		local distance = (radius + rng:nextRange(2, 6)) * tileSize
		table.insert(props, {
			kind = "floatingIsland",
			x = math.cos(angle) * distance,
			y = rng:nextRange(20, 60),
			z = math.sin(angle) * distance,
			yaw = rng:nextRange(0, math.pi * 2),
			scale = rng:nextRange(0.8, 1.6),
			tier = Zones.COUNT,
		})
	end

	local impactCandidates: { { Tile } } = {}
	for tier = 1, Zones.COUNT do
		impactCandidates[tier] = {}
	end
	for _, tile in tiles do
		if tile.tier > 0 and tile.kind == "ground" and not tile.hasProp then
			table.insert(impactCandidates[tile.tier], tile)
		end
	end

	return {
		seed = config.Seed,
		tileSize = tileSize,
		radius = radius,
		gridSize = gridSize,
		tiles = tiles,
		index = byKey,
		impactCandidates = impactCandidates,
		props = props,
	}
end

-- Tile under a world position, or nil when off-island.
function MapLayout.tileAt(layout: Layout, x: number, z: number): Tile?
	local center = layout.radius
	local gridX = math.floor(x / layout.tileSize + 0.5) + center
	local gridZ = math.floor(z / layout.tileSize + 0.5) + center
	if gridX < 0 or gridZ < 0 or gridX >= layout.gridSize or gridZ >= layout.gridSize then
		return nil
	end
	return layout.index[key(gridX, gridZ, layout.gridSize)]
end

return table.freeze(MapLayout)
