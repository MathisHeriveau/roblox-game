--!strict
--[[
	MapLayout — pure, deterministic procedural map generation.

	Produces plain data (no Instances) from a config + seed. Same input => identical output on
	every runtime, which makes it unit-testable headlessly and reproducible across servers.
	MapBuilder turns a Layout into Instances.

	Coordinates: the grid is centred on the world origin. `x`/`z` are tile centres in studs,
	`height` is the tile's top surface Y in studs (spawn plateau is at Y = 0).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prng = require(ReplicatedStorage.Shared.Utils.Prng)

export type Config = {
	Seed: number,
	GridSize: number,
	TileSize: number,
	MaxHeight: number,
	SpawnClearRadius: number,
	CollectibleCount: number,
	SmoothingPasses: number,
}

export type Tile = {
	gridX: number,
	gridZ: number,
	x: number,
	z: number,
	height: number,
}

export type Collectible = {
	id: string,
	gridX: number,
	gridZ: number,
	x: number,
	y: number,
	z: number,
}

export type Layout = {
	seed: number,
	gridSize: number,
	tileSize: number,
	-- Half the map's side length in studs (map spans [-extent, extent] on X and Z).
	extent: number,
	tiles: { Tile },
	spawn: { x: number, y: number, z: number },
	collectibles: { Collectible },
}

-- Height above the tile surface at which collectibles float.
local COLLECTIBLE_HOVER = 3

local MapLayout = {}

function MapLayout.validateConfig(config: Config): (boolean, string?)
	if config.GridSize < 3 or config.GridSize % 2 ~= 1 then
		return false, "GridSize must be an odd integer >= 3"
	end
	if config.TileSize <= 0 then
		return false, "TileSize must be > 0"
	end
	if config.MaxHeight < 0 then
		return false, "MaxHeight must be >= 0"
	end
	if config.SpawnClearRadius < 0 or config.SpawnClearRadius * 2 + 1 >= config.GridSize then
		return false, "SpawnClearRadius leaves no playable tiles"
	end
	local spawnTiles = (config.SpawnClearRadius * 2 + 1) ^ 2
	local available = config.GridSize * config.GridSize - spawnTiles
	if config.CollectibleCount < 0 or config.CollectibleCount > available then
		return false, `CollectibleCount must be between 0 and {available}`
	end
	return true, nil
end

-- Chebyshev distance (in tiles) from the centre tile.
function MapLayout.distanceFromCenter(gridX: number, gridZ: number, gridSize: number): number
	local center = (gridSize - 1) / 2
	return math.max(math.abs(gridX - center), math.abs(gridZ - center))
end

local function generateHeights(config: Config, rng: Prng.Prng): { { number } }
	local size = config.GridSize
	local heights: { { number } } = table.create(size)
	for x = 1, size do
		local column = table.create(size)
		for z = 1, size do
			column[z] = rng:nextNumber()
		end
		heights[x] = column
	end

	-- Box-blur smoothing turns white noise into rolling hills.
	for _ = 1, config.SmoothingPasses do
		local smoothed: { { number } } = table.create(size)
		for x = 1, size do
			local column = table.create(size)
			for z = 1, size do
				local sum, count = 0, 0
				for dx = -1, 1 do
					for dz = -1, 1 do
						local neighbour = heights[x + dx] and heights[x + dx][z + dz]
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
		heights = smoothed
	end
	return heights
end

function MapLayout.generate(config: Config): Layout
	local valid, err = MapLayout.validateConfig(config)
	assert(valid, `MapLayout: invalid config: {err}`)

	local rng = Prng.new(config.Seed)
	local size = config.GridSize
	local tileSize = config.TileSize
	local center = (size - 1) / 2
	local heights = generateHeights(config, rng)

	local tiles: { Tile } = table.create(size * size)
	local candidates: { Tile } = {}

	for gridX = 0, size - 1 do
		for gridZ = 0, size - 1 do
			local distance = MapLayout.distanceFromCenter(gridX, gridZ, size)
			local height = 0
			if distance > config.SpawnClearRadius then
				-- Whole-stud steps read clearly as terraces and avoid float noise in builds/tests.
				height = math.floor(heights[gridX + 1][gridZ + 1] * config.MaxHeight + 0.5)
			end
			local tile: Tile = {
				gridX = gridX,
				gridZ = gridZ,
				x = (gridX - center) * tileSize,
				z = (gridZ - center) * tileSize,
				height = height,
			}
			table.insert(tiles, tile)
			if distance > config.SpawnClearRadius then
				table.insert(candidates, tile)
			end
		end
	end

	-- Partial Fisher–Yates shuffle: pick CollectibleCount distinct tiles outside the spawn zone.
	local collectibles: { Collectible } = table.create(config.CollectibleCount)
	for index = 1, config.CollectibleCount do
		local pick = rng:nextInteger(index, #candidates)
		candidates[index], candidates[pick] = candidates[pick], candidates[index]
		local tile = candidates[index]
		table.insert(collectibles, {
			id = `collectible_{tile.gridX}_{tile.gridZ}`,
			gridX = tile.gridX,
			gridZ = tile.gridZ,
			x = tile.x,
			y = tile.height + COLLECTIBLE_HOVER,
			z = tile.z,
		})
	end

	return {
		seed = config.Seed,
		gridSize = size,
		tileSize = tileSize,
		extent = size * tileSize / 2,
		tiles = tiles,
		spawn = { x = 0, y = 0, z = 0 },
		collectibles = collectibles,
	}
end

return table.freeze(MapLayout)
