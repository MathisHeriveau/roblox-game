--!strict
--[[
	SkySchedule — pure decisions for meteor showers and comets: how many shards, where they land
	and what rarity they are. Driven by an injected Prng so every outcome is reproducible in tests.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapLayout = require(ServerScriptService.Server.Systems.Map.MapLayout)
local Prng = require(ReplicatedStorage.Shared.Utils.Prng)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local RarityRoll = require(ReplicatedStorage.Shared.Game.RarityRoll)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

export type Impact = {
	tile: MapLayout.Tile,
	rarity: number,
	shiny: boolean,
	isComet: boolean,
}

export type EventsConfig = {
	MeteorBase: number,
	MeteorPerPlayer: number,
	MeteorMax: number,
	CometScatter: number,
}

local SkySchedule = {}

function SkySchedule.meteorCount(playerCount: number, config: EventsConfig): number
	return math.min(config.MeteorMax, config.MeteorBase + config.MeteorPerPlayer * math.max(0, playerCount))
end

function SkySchedule.rollShiny(rng: Prng.Prng): boolean
	return rng:nextNumber() < Rarities.SHINY_CHANCE
end

local function zoneShares(): { number }
	local shares = {}
	for _, zone in Zones.list do
		table.insert(shares, zone.impactShare)
	end
	return shares
end

-- Picks a random free tile in `tier`, or nil when that zone has no free tile.
local function pickFreeTile(
	rng: Prng.Prng,
	candidates: { MapLayout.Tile },
	isFree: (MapLayout.Tile) -> boolean
): MapLayout.Tile?
	if #candidates == 0 then
		return nil
	end
	-- A few random probes first (cheap), then a deterministic scan from a random start.
	for _ = 1, 8 do
		local tile = candidates[rng:nextInteger(1, #candidates)]
		if isFree(tile) then
			return tile
		end
	end
	local start = rng:nextInteger(1, #candidates)
	for offset = 0, #candidates - 1 do
		local tile = candidates[(start + offset - 1) % #candidates + 1]
		if isFree(tile) then
			return tile
		end
	end
	return nil
end

-- Meteor shower: `count` impacts spread over zones by impactShare, each on a distinct free tile.
function SkySchedule.meteorImpacts(
	rng: Prng.Prng,
	layout: MapLayout.Layout,
	count: number,
	isFree: (MapLayout.Tile) -> boolean
): { Impact }
	local impacts: { Impact } = {}
	local taken: { [MapLayout.Tile]: boolean } = {}
	local shares = zoneShares()
	local function free(tile: MapLayout.Tile): boolean
		return not taken[tile] and isFree(tile)
	end
	for _ = 1, count do
		local tier = RarityRoll.pick(rng, shares)
		local tile = pickFreeTile(rng, layout.impactCandidates[tier], free)
		if tile then
			taken[tile] = true
			table.insert(impacts, {
				tile = tile,
				rarity = RarityRoll.pick(rng, Zones.get(tier).weights),
				shiny = SkySchedule.rollShiny(rng),
				isComet = false,
			})
		end
	end
	return impacts
end

-- Comet: a crater in zones 2..COUNT with one comet core plus `CometScatter` regular shards around.
function SkySchedule.cometImpacts(
	rng: Prng.Prng,
	layout: MapLayout.Layout,
	config: EventsConfig,
	isFree: (MapLayout.Tile) -> boolean
): { Impact }
	local candidates: { MapLayout.Tile } = {}
	for tier = 2, Zones.COUNT do
		for _, tile in layout.impactCandidates[tier] do
			table.insert(candidates, tile)
		end
	end
	local center = pickFreeTile(rng, candidates, isFree)
	if center == nil then
		return {}
	end

	local impacts: { Impact } = {
		{
			tile = center,
			rarity = RarityRoll.pick(rng, Zones.COMET_WEIGHTS),
			shiny = SkySchedule.rollShiny(rng),
			isComet = true,
		},
	}
	local taken: { [MapLayout.Tile]: boolean } = { [center] = true }

	-- Ring of shards on nearby free tiles of any walkable zone.
	local nearby: { MapLayout.Tile } = {}
	for tier = 1, Zones.COUNT do
		for _, tile in layout.impactCandidates[tier] do
			local dx, dz = tile.gridX - center.gridX, tile.gridZ - center.gridZ
			if dx * dx + dz * dz <= 9 and tile ~= center then
				table.insert(nearby, tile)
			end
		end
	end
	for _ = 1, config.CometScatter do
		local tile = pickFreeTile(rng, nearby, function(candidate)
			return not taken[candidate] and isFree(candidate)
		end)
		if tile == nil then
			break
		end
		taken[tile] = true
		table.insert(impacts, {
			tile = tile,
			rarity = RarityRoll.pick(rng, Zones.get(math.max(1, tile.tier)).weights),
			shiny = SkySchedule.rollShiny(rng),
			isComet = false,
		})
	end
	return impacts
end

return table.freeze(SkySchedule)
