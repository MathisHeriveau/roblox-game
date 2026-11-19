--!strict
--[[
	MapLayout — pure, deterministic generation of the Comet Raiders world.

	  - hub (tier 0): flat round plaza holding the player bases
	  - Meadow, Crystal Desert, Lava Fields (tiers 1-3): one continuous island whose zone borders
	    are bent organically (Zones.tierAt), rising outwards, with lava pools, volcanoes and arches
	  - Floating Sky Islands (tier 4): separate islands floating beyond the void, each reached by a
	    jump pad on the Lava Fields and left through a return pad
	  - decorative props and far-away floating islands

	Guarantees (unit-tested): same seed => identical layout; walkable neighbours on the mainland
	(and inside each sky island) never differ by more than MaxStep; every jump pad's launch
	velocity lands exactly on its target under `Gravity`; impact candidates are walkable,
	prop-free tiles of the right zone.

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
	Arches: number,
	Volcanoes: number,
	SkyIslands: number,
	Gravity: number,
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
	-- 0 = hub, 1..Zones.COUNT = zones.
	tier: number,
	kind: TileKind,
	height: number,
	bottom: number,
	hasProp: boolean,
	-- Sky island index (tier COUNT only), else 0.
	island: number,
}

export type PropKind = "tree" | "crystal" | "rock" | "pillar" | "arch" | "volcano" | "floatingIsland"

export type Prop = {
	kind: PropKind,
	x: number,
	y: number,
	z: number,
	yaw: number,
	scale: number,
	tier: number,
}

export type Point = { x: number, y: number, z: number }

export type JumpPad = {
	kind: "up" | "down",
	island: number,
	position: Point,
	target: Point,
	velocity: Point,
	flightTime: number,
}

export type Island = {
	index: number,
	x: number,
	z: number,
	radius: number,
	height: number,
}

export type Layout = {
	seed: number,
	tileSize: number,
	radius: number,
	gridSize: number,
	tiles: { Tile },
	-- Grid lookup: index[gridX * gridSize + gridZ + 1] -> Tile (see MapLayout.tileAt).
	index: { [number]: Tile },
	islands: { Island },
	jumpPads: { JumpPad },
	-- Walkable, prop-free tiles where shards may land, per zone tier (1..Zones.COUNT).
	impactCandidates: { { Tile } },
	props: { Prop },
}

local LAVA_PIT_DEPTH = 2
local NEIGHBOURS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

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

-- Lowers tiles until no walkable neighbour pair differs by more than maxStep (hub stays at 0).
local function enforceMaxStep(tiles: { Tile }, byKey: { [number]: Tile }, gridSize: number, maxStep: number)
	local changed = true
	local guard = 0
	while changed and guard < 300 do
		changed = false
		guard += 1
		for _, tile in tiles do
			if tile.kind == "ground" then
				for _, offset in NEIGHBOURS do
					local neighbour = byKey[key(tile.gridX + offset[1], tile.gridZ + offset[2], gridSize)]
					if
						neighbour
						and neighbour.kind == "ground"
						and neighbour.island == tile.island
						and tile.height - neighbour.height > maxStep
					then
						tile.height = neighbour.height + maxStep
						changed = true
					end
				end
			end
		end
	end
end

--[[
	Initial velocity that carries a projectile from `from` to `to` under `gravity`, with a flight
	time scaled to the horizontal distance. Exact for drag-free motion (Roblox characters in the air).
]]
function MapLayout.launchVelocity(from: Point, to: Point, gravity: number): (Point, number)
	local dx, dy, dz = to.x - from.x, to.y - from.y, to.z - from.z
	local horizontal = math.sqrt(dx * dx + dz * dz)
	local flightTime = math.clamp(horizontal / 60, 1.3, 2.8)
	return {
		x = dx / flightTime,
		y = (dy + 0.5 * gravity * flightTime * flightTime) / flightTime,
		z = dz / flightTime,
	},
		flightTime
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
	for _, field in { "Arches", "Volcanoes", "SkyIslands", "FloatingIslands" } do
		if ((config :: any)[field] :: number) < 0 then
			return false, `{field} must be >= 0`
		end
	end
	if config.Gravity <= 0 then
		return false, "Gravity must be > 0"
	end
	return true, nil
end

function MapLayout.generate(config: Config): Layout
	local valid, err = MapLayout.validateConfig(config)
	assert(valid, `MapLayout: invalid config: {err}`)

	local rng = Prng.new(config.Seed)
	local tileSize = Zones.TILE_SIZE
	local radius = Zones.RADIUS
	local gridSize = (radius + 1) * 2 + 1
	local center = radius + 1
	local heightNoise = noiseGrid(rng, gridSize, 2)
	local lavaNoise = noiseGrid(rng, gridSize, 1)
	local skyTier = Zones.COUNT

	local tiles: { Tile } = {}
	local byKey: { [number]: Tile } = {}

	local function addTile(tile: Tile)
		table.insert(tiles, tile)
		byKey[key(tile.gridX, tile.gridZ, gridSize)] = tile
	end

	-- 1. Mainland: hub + every zone except the sky.
	for gridX = 0, gridSize - 1 do
		for gridZ = 0, gridSize - 1 do
			local dx, dz = gridX - center, gridZ - center
			local x, z = dx * tileSize, dz * tileSize
			local tier = Zones.tierAt(x, z)
			if tier ~= nil and tier < skyTier then
				local distance = math.sqrt(dx * dx + dz * dz)
				local height = 0
				if tier > 0 then
					local zone = Zones.get(tier)
					local inner = Zones.outerRadius(tier - 1)
					local progress = math.clamp((distance - inner) / zone.width, 0, 1)
					local n = heightNoise[gridX + 1][gridZ + 1]
					height = math.floor(zone.baseHeight + n * zone.heightAmplitude + progress * 3 + 0.5)
				end
				addTile({
					gridX = gridX,
					gridZ = gridZ,
					x = x,
					z = z,
					distance = distance,
					tier = tier,
					kind = "ground",
					height = height,
					bottom = -(
							config.UndersideBase
							+ (Zones.outerRadius(skyTier - 1) + 2 - distance) * config.UndersideSlope
						),
					hasProp = false,
					island = 0,
				})
			end
		end
	end

	-- 2. Lava pools: lowest smoothed-noise tiles of lava zones (clustered, exact proportion).
	for tier = 1, skyTier - 1 do
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

	-- 3. Floating sky islands beyond the void, evenly spread around the world.
	local islands: { Island } = {}
	local skyZone = Zones.get(skyTier)
	local lavaEdge = Zones.outerRadius(skyTier - 1) + 1.75 -- worst-case warped border
	for index = 1, config.SkyIslands do
		local angle = (index - 1) / config.SkyIslands * math.pi * 2 + rng:nextRange(-0.2, 0.2)
		local islandRadius = rng:nextRange(2.4, 3.3)
		local distance = math.min(lavaEdge + 1.4 + islandRadius, radius - islandRadius)
		local island: Island = {
			index = index,
			x = math.cos(angle) * distance,
			z = math.sin(angle) * distance,
			radius = islandRadius,
			height = math.floor(skyZone.baseHeight + rng:nextNumber() * skyZone.heightAmplitude + 0.5),
		}
		table.insert(islands, island)
		for gridX = math.floor(center + island.x - islandRadius - 1), math.ceil(center + island.x + islandRadius + 1) do
			for gridZ = math.floor(center + island.z - islandRadius - 1), math.ceil(center + island.z + islandRadius + 1) do
				local dx, dz = gridX - center, gridZ - center
				local fromIsland = math.sqrt((dx - island.x) ^ 2 + (dz - island.z) ^ 2)
				if
					fromIsland <= islandRadius
					and gridX >= 0
					and gridZ >= 0
					and gridX < gridSize
					and gridZ < gridSize
					and byKey[key(gridX, gridZ, gridSize)] == nil
				then
					-- A small raised crown in the middle of each island.
					local crown = if fromIsland < islandRadius * 0.4 then 2 else 0
					local height = island.height + crown
					addTile({
						gridX = gridX,
						gridZ = gridZ,
						x = dx * tileSize,
						z = dz * tileSize,
						distance = math.sqrt(dx * dx + dz * dz),
						tier = skyTier,
						kind = "ground",
						height = height,
						bottom = height - 4 - (6 + (islandRadius - fromIsland) * 6),
						hasProp = false,
						island = index,
					})
				end
			end
		end
	end

	enforceMaxStep(tiles, byKey, gridSize, config.MaxStep)

	-- Lava pits sit slightly below their surroundings.
	for _, tile in tiles do
		if tile.kind == "lava" then
			local lowest = math.huge
			for _, offset in NEIGHBOURS do
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

	-- Nearest walkable, free tile of `tier` to a point (in tiles from the centre).
	local function nearestTile(tier: number, px: number, pz: number): Tile?
		local best: Tile? = nil
		local bestDistance = math.huge
		for _, tile in tiles do
			if tile.tier == tier and tile.kind == "ground" and not tile.hasProp then
				local d = (tile.gridX - center - px) ^ 2 + (tile.gridZ - center - pz) ^ 2
				if d < bestDistance then
					bestDistance = d
					best = tile
				end
			end
		end
		return best
	end

	local function top(tile: Tile, lift: number): Point
		return { x = tile.x, y = tile.height + lift, z = tile.z }
	end

	-- 4. Jump pads: Lava Fields -> island (up), island -> Crystal Desert (down).
	local jumpPads: { JumpPad } = {}
	for _, island in islands do
		local length = math.sqrt(island.x ^ 2 + island.z ^ 2)
		local ux, uz = island.x / length, island.z / length
		local centreTile = nearestTile(skyTier, island.x, island.z)
		local lavaRadius = Zones.outerRadius(skyTier - 2) + 1.5
		local launch = nearestTile(skyTier - 1, ux * lavaRadius, uz * lavaRadius)
		local innerEdge =
			nearestTile(skyTier, island.x - ux * (island.radius - 0.8), island.z - uz * (island.radius - 0.8))
		local desertRadius = Zones.outerRadius(skyTier - 3) + 2
		local landing = nearestTile(skyTier - 2, ux * desertRadius, uz * desertRadius)
		if centreTile and launch and innerEdge and landing and innerEdge ~= centreTile then
			launch.hasProp = true
			innerEdge.hasProp = true
			for _, pad in
				{
					{ kind = "up", from = launch, to = centreTile },
					{ kind = "down", from = innerEdge, to = landing },
				}
			do
				local position = top(pad.from, 0)
				local target = top(pad.to, 3)
				local velocity, flightTime = MapLayout.launchVelocity(position, target, config.Gravity)
				table.insert(jumpPads, {
					kind = pad.kind :: any,
					island = island.index,
					position = position,
					target = target,
					velocity = velocity,
					flightTime = flightTime,
				})
			end
		end
	end

	-- 5. Props. Tiles with a prop never receive shards.
	local props: { Prop } = {}
	local function addProp(tile: Tile, kind: PropKind, scaleMin: number, scaleMax: number, jitter: number?)
		tile.hasProp = true
		local spread = tileSize * (jitter or 0.25)
		table.insert(props, {
			kind = kind,
			x = tile.x + rng:nextRange(-spread, spread),
			y = tile.height,
			z = tile.z + rng:nextRange(-spread, spread),
			yaw = rng:nextRange(0, math.pi * 2),
			scale = rng:nextRange(scaleMin, scaleMax),
			tier = tile.tier,
		})
	end

	-- Landmarks first (they need room): volcanoes in the Lava Fields, arches in the desert.
	local function placeLandmarks(tier: number, count: number, kind: PropKind, clearRadius: number)
		local candidates: { Tile } = {}
		for _, tile in tiles do
			if tile.tier == tier and tile.kind == "ground" and not tile.hasProp then
				table.insert(candidates, tile)
			end
		end
		local placed: { Tile } = {}
		local attempts = 0
		while #placed < count and attempts < 400 and #candidates > 0 do
			attempts += 1
			local tile = candidates[rng:nextInteger(1, #candidates)]
			local farEnough = not tile.hasProp
			for _, other in placed do
				if (tile.gridX - other.gridX) ^ 2 + (tile.gridZ - other.gridZ) ^ 2 < 64 then
					farEnough = false
				end
			end
			if farEnough then
				table.insert(placed, tile)
				addProp(tile, kind, 0.9, 1.15, 0)
				for _, other in tiles do
					if (other.gridX - tile.gridX) ^ 2 + (other.gridZ - tile.gridZ) ^ 2 <= clearRadius * clearRadius then
						other.hasProp = true
					end
				end
			end
		end
	end
	placeLandmarks(skyTier - 1, config.Volcanoes, "volcano", 1.5)
	placeLandmarks(skyTier - 2, config.Arches, "arch", 1)

	for _, tile in tiles do
		local roll = rng:nextNumber()
		if tile.kind == "ground" and not tile.hasProp and tile.distance > Zones.HUB_RADIUS + 0.75 then
			if tile.tier == 1 and roll < config.TreeChance then
				addProp(tile, "tree", 0.8, 1.3)
			elseif tile.tier == 2 and roll < config.CrystalChance then
				addProp(tile, "crystal", 0.8, 1.6)
			elseif tile.tier == 3 and roll < config.RockChance then
				addProp(tile, "rock", 0.8, 1.5)
			elseif tile.tier == skyTier and roll < config.PillarChance then
				addProp(tile, if roll < config.PillarChance / 2 then "pillar" else "tree", 0.8, 1.2)
			end
		end
	end

	for _ = 1, config.FloatingIslands do
		local angle = rng:nextRange(0, math.pi * 2)
		local distance = (radius + rng:nextRange(2, 6)) * tileSize
		table.insert(props, {
			kind = "floatingIsland",
			x = math.cos(angle) * distance,
			y = rng:nextRange(30, 80),
			z = math.sin(angle) * distance,
			yaw = rng:nextRange(0, math.pi * 2),
			scale = rng:nextRange(0.8, 1.6),
			tier = skyTier,
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
		islands = islands,
		jumpPads = jumpPads,
		impactCandidates = impactCandidates,
		props = props,
	}
end

-- Tile under a world position, or nil when over the void.
function MapLayout.tileAt(layout: Layout, x: number, z: number): Tile?
	local center = layout.radius + 1
	local gridX = math.floor(x / layout.tileSize + 0.5) + center
	local gridZ = math.floor(z / layout.tileSize + 0.5) + center
	if gridX < 0 or gridZ < 0 or gridX >= layout.gridSize or gridZ >= layout.gridSize then
		return nil
	end
	return layout.index[key(gridX, gridZ, layout.gridSize)]
end

return table.freeze(MapLayout)
