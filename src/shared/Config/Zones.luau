--!strict
--[[
	Zones — the four zones of the island, from the central hub outwards.

	The hub (tier 0) holds the player bases. Each zone is a ring `width` tiles wide; the further
	out, the higher the terrain and the rarer the shards. Ring borders are bent by a deterministic
	angular warp so zones look organic instead of a bullseye (same function on client and server).
	The outermost ring holds separate floating islands reached with jump pads.
	A shard can only be picked up in zones the player has unlocked (comet cores excepted).
	Pure data + pure helpers: usable on client and server.
]]

export type Zone = {
	tier: number,
	-- Ring width in tiles.
	width: number,
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
-- Angular warp of ring borders: { frequency, amplitude in tiles, phase }.
local WARP = {
	{ 3, 0.85, 0.4 },
	{ 5, 0.55, 1.9 },
	{ 9, 0.3, 4.2 },
}

local LIST: { Zone } = {
	{
		tier = 1,
		key = "meadow",
		width = 4,
		name = "Starting Meadow",
		icon = "🌿",
		color = Color3.fromRGB(76, 175, 80),
		unlockCost = 0,
		weights = { 70, 25, 5, 0, 0, 0 },
		impactShare = 43,
		baseHeight = 1,
		heightAmplitude = 6,
		lavaChance = 0,
		topMaterial = Enum.Material.Grass,
		topColor = Color3.fromRGB(86, 178, 78),
	},
	{
		tier = 2,
		key = "desert",
		width = 4,
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
		width = 4,
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
		topColor = Color3.fromRGB(104, 70, 74),
	},
	{
		tier = 4,
		key = "sky",
		width = 10,
		name = "Floating Sky Islands",
		icon = "☁️",
		color = Color3.fromRGB(123, 104, 238),
		unlockCost = 150000,
		weights = { 0, 0, 35, 40, 20, 5 },
		impactShare = 12,
		baseHeight = 26,
		heightAmplitude = 10,
		lavaChance = 0,
		topMaterial = Enum.Material.LeafyGrass,
		topColor = Color3.fromRGB(132, 206, 120),
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

-- Outer border (tiles from the centre) of each tier, before warping.
local OUTER: { [number]: number } = { [0] = HUB_RADIUS }
do
	local edge = HUB_RADIUS
	for _, zone in LIST do
		edge += zone.width
		OUTER[zone.tier] = edge
	end
end

local Zones = {
	list = table.freeze(LIST),
	COUNT = #LIST,
	TILE_SIZE = TILE_SIZE,
	HUB_RADIUS = HUB_RADIUS,
	-- World radius in tiles (hub + every ring, floating islands included).
	RADIUS = OUTER[#LIST],
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

-- Outer border of a tier in tiles (unwarped). 0 = hub.
function Zones.outerRadius(tier: number): number
	local radius = OUTER[tier]
	assert(radius ~= nil, `Zones: unknown tier {tier}`)
	return radius
end

-- Tier for an (already warped) distance from the centre, in tiles: 0 = hub, nil = beyond the world.
function Zones.tierForDistance(distanceInTiles: number): number?
	if distanceInTiles ~= distanceInTiles or distanceInTiles < 0 then
		return nil
	end
	if distanceInTiles <= HUB_RADIUS then
		return 0
	end
	for _, zone in LIST do
		if distanceInTiles <= OUTER[zone.tier] then
			return zone.tier
		end
	end
	return nil
end

-- Border offset (tiles) at the angle of (x, z): bends rings into organic shapes.
function Zones.warp(x: number, z: number): number
	local angle = math.atan2(z, x)
	local offset = 0
	for _, wave in WARP do
		offset += wave[2] * math.sin(wave[1] * angle + wave[3])
	end
	return offset
end

-- Tier at a world position (the island is centred on the origin). The hub stays perfectly round
-- (bases live there); every other border is warped.
function Zones.tierAt(x: number, z: number): number?
	local distance = math.sqrt(x * x + z * z) / TILE_SIZE
	if distance ~= distance then
		return nil
	end
	if distance <= HUB_RADIUS then
		return 0
	end
	local warped = math.max(HUB_RADIUS + 0.001, distance + Zones.warp(x, z))
	return Zones.tierForDistance(warped)
end

return table.freeze(Zones)
