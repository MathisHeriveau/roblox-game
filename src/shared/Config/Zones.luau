--!strict
--[[
	Zones — the four concentric rings of the island, from the central hub outwards.

	The hub (tier 0) holds the player bases. Each ring is `Zones.WIDTH` tiles wide; the further out,
	the higher the terrain and the rarer the shards. A shard can only be picked up in zones the
	player has unlocked (comet cores excepted). Pure data + pure helpers: usable on client and server.
]]

export type Zone = {
	tier: number,
	key: string,
	name: string,
	icon: string,
	color: Color3,
	unlockCost: number,
	-- Rarity weights indexed by rarity id (see Rarities). Zero = never spawns here.
	weights: { number },
	-- Share of meteor impacts that land in this zone.
	impactShare: number,
	baseHeight: number,
	heightAmplitude: number,
	lavaChance: number,
	topMaterial: Enum.Material,
	topColor: Color3,
}

local TILE_SIZE = 16
local HUB_RADIUS = 5 -- tiles
local WIDTH = 4 -- tiles per ring

local LIST: { Zone } = {
	{
		tier = 1,
		key = "meadow",
		name = "Starting Meadow",
		icon = "🌿",
		color = Color3.fromRGB(76, 175, 80),
		unlockCost = 0,
		weights = { 70, 25, 5, 0, 0, 0 },
		impactShare = 45,
		baseHeight = 1,
		heightAmplitude = 6,
		lavaChance = 0,
		topMaterial = Enum.Material.Grass,
		topColor = Color3.fromRGB(86, 178, 78),
	},
	{
		tier = 2,
		key = "desert",
		name = "Crystal Desert",
		icon = "🏜️",
		color = Color3.fromRGB(246, 194, 107),
		unlockCost = 400,
		weights = { 35, 40, 20, 5, 0, 0 },
		impactShare = 28,
		baseHeight = 6,
		heightAmplitude = 8,
		lavaChance = 0,
		topMaterial = Enum.Material.Sand,
		topColor = Color3.fromRGB(246, 194, 107),
	},
	{
		tier = 3,
		key = "lava",
		name = "Lava Fields",
		icon = "🌋",
		color = Color3.fromRGB(255, 69, 0),
		unlockCost = 8000,
		weights = { 0, 35, 40, 20, 5, 0 },
		impactShare = 17,
		baseHeight = 10,
		heightAmplitude = 8,
		lavaChance = 0.2,
		topMaterial = Enum.Material.Basalt,
		topColor = Color3.fromRGB(74, 56, 66),
	},
	{
		tier = 4,
		key = "sky",
		name = "Floating Sky Islands",
		icon = "☁️",
		color = Color3.fromRGB(123, 104, 238),
		unlockCost = 150000,
		weights = { 0, 0, 35, 40, 20, 5 },
		impactShare = 10,
		baseHeight = 18,
		heightAmplitude = 14,
		lavaChance = 0,
		topMaterial = Enum.Material.LeafyGrass,
		topColor = Color3.fromRGB(150, 132, 240),
	},
}

for _, zone in LIST do
	table.freeze(zone.weights)
	table.freeze(zone)
end

local byKey: { [string]: Zone } = {}
for _, zone in LIST do
	byKey[zone.key] = zone
end

local Zones = {
	list = table.freeze(LIST),
	COUNT = #LIST,
	TILE_SIZE = TILE_SIZE,
	HUB_RADIUS = HUB_RADIUS,
	WIDTH = WIDTH,
	-- Island radius in tiles (hub + every ring).
	RADIUS = HUB_RADIUS + WIDTH * #LIST,
	-- Comet cores ignore zone locks and roll from this table.
	COMET_WEIGHTS = table.freeze({ 0, 0, 0, 55, 33, 12 }),
	HUB_NAME = "Comet Plaza",
}

function Zones.get(tier: number): Zone
	local zone = LIST[tier]
	assert(zone ~= nil, `Zones: unknown tier {tier}`)
	return zone
end

function Zones.byKey(key: string): Zone?
	return byKey[key]
end

-- Tier for a distance from the island centre, in tiles: 0 = hub, 1..COUNT = rings, nil = off-island.
function Zones.tierForDistance(distanceInTiles: number): number?
	if distanceInTiles ~= distanceInTiles or distanceInTiles < 0 then
		return nil
	end
	if distanceInTiles <= HUB_RADIUS then
		return 0
	end
	local tier = math.ceil((distanceInTiles - HUB_RADIUS) / WIDTH)
	if tier > #LIST then
		return nil
	end
	return tier
end

-- Tier at a world position (the island is centred on the origin).
function Zones.tierAt(x: number, z: number): number?
	return Zones.tierForDistance(math.sqrt(x * x + z * z) / TILE_SIZE)
end

return table.freeze(Zones)
