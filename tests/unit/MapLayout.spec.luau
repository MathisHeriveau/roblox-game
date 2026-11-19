--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MapLayout = require(ServerScriptService.Server.Systems.Map.MapLayout)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local SKY = Zones.COUNT

local function withOverrides(overrides: { [string]: any }): MapLayout.Config
	local config = table.clone(GameConfig.Map) :: any
	for key, value in overrides do
		config[key] = value
	end
	return config
end

local function fingerprint(layout: MapLayout.Layout): string
	local parts = {}
	for _, tile in layout.tiles do
		table.insert(parts, `{tile.gridX},{tile.gridZ},{tile.height},{tile.kind}`)
	end
	return table.concat(parts, ";")
end

local function neighbours(layout: MapLayout.Layout, tile: MapLayout.Tile): { MapLayout.Tile }
	local result = {}
	for _, offset in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local other =
			MapLayout.tileAt(layout, tile.x + offset[1] * layout.tileSize, tile.z + offset[2] * layout.tileSize)
		if other then
			table.insert(result, other)
		end
	end
	return result
end

return function()
	local layout = MapLayout.generate(GameConfig.Map)

	describe("MapLayout mainland", function()
		it("is deterministic for a seed and changes with it", function()
			expect(fingerprint(MapLayout.generate(GameConfig.Map))).to.equal(fingerprint(layout))
			local other = MapLayout.generate(withOverrides({ Seed = GameConfig.Map.Seed + 1 }))
			expect(fingerprint(other) ~= fingerprint(layout)).to.equal(true)
		end)

		it("assigns mainland tiles the organic zone of their position", function()
			local seen: { [number]: boolean } = {}
			for _, tile in layout.tiles do
				if tile.island == 0 then
					expect(tile.tier).to.equal(Zones.tierAt(tile.x, tile.z))
					expect(tile.tier < SKY).to.equal(true)
				end
				seen[tile.tier] = true
			end
			for tier = 0, Zones.COUNT do
				expect(seen[tier]).to.equal(true)
			end
		end)

		it("keeps the hub flat at Y = 0 and lava only in lava zones", function()
			for _, tile in layout.tiles do
				if tile.tier == 0 then
					expect(tile.height).to.equal(0)
					expect(tile.kind).to.equal("ground")
				end
				if tile.kind == "lava" then
					expect(Zones.get(tile.tier).lavaChance > 0).to.equal(true)
				end
			end
		end)

		it("generates lava pools in the Lava Fields", function()
			local lava, total = 0, 0
			for _, tile in layout.tiles do
				if tile.tier == 3 then
					total += 1
					if tile.kind == "lava" then
						lava += 1
					end
				end
			end
			expect(lava / total).to.be.near(Zones.get(3).lavaChance, 0.05)
		end)

		it("never lets walkable neighbours on the same landmass differ by more than MaxStep", function()
			for _, tile in layout.tiles do
				if tile.kind == "ground" then
					for _, other in neighbours(layout, tile) do
						if other.kind == "ground" and other.island == tile.island then
							expect(math.abs(tile.height - other.height) <= GameConfig.Map.MaxStep).to.equal(true)
						end
					end
				end
			end
		end)

		it("puts the rock underside below every surface", function()
			for _, tile in layout.tiles do
				expect(tile.bottom < tile.height - 4).to.equal(true)
			end
		end)
	end)

	describe("MapLayout sky islands", function()
		it("creates the configured number of separate islands, all in the sky zone", function()
			expect(#layout.islands).to.equal(GameConfig.Map.SkyIslands)
			local tilesPerIsland: { [number]: number } = {}
			for _, tile in layout.tiles do
				if tile.island > 0 then
					expect(tile.tier).to.equal(SKY)
					tilesPerIsland[tile.island] = (tilesPerIsland[tile.island] or 0) + 1
				end
			end
			for index = 1, GameConfig.Map.SkyIslands do
				expect((tilesPerIsland[index] or 0) >= 12).to.equal(true)
			end
		end)

		it("separates every island from the mainland and the others by the void", function()
			for _, tile in layout.tiles do
				if tile.island > 0 then
					for _, other in neighbours(layout, tile) do
						expect(other.island).to.equal(tile.island)
					end
				end
			end
		end)
	end)

	describe("MapLayout jump pads", function()
		it("serves every island with one pad up (from the Lava Fields) and one pad down", function()
			local ups, downs = {}, {}
			for _, pad in layout.jumpPads do
				local tile = MapLayout.tileAt(layout, pad.position.x, pad.position.z) :: MapLayout.Tile
				expect(tile).to.be.ok()
				expect(tile.hasProp).to.equal(true) -- no shard spawns on a pad
				if pad.kind == "up" then
					ups[pad.island] = true
					expect(tile.tier).to.equal(SKY - 1)
					local target = MapLayout.tileAt(layout, pad.target.x, pad.target.z) :: MapLayout.Tile
					expect(target.island).to.equal(pad.island)
				else
					downs[pad.island] = true
					expect(tile.island).to.equal(pad.island)
					local target = MapLayout.tileAt(layout, pad.target.x, pad.target.z) :: MapLayout.Tile
					expect(target.island).to.equal(0)
				end
			end
			for index = 1, #layout.islands do
				expect(ups[index]).to.equal(true)
				expect(downs[index]).to.equal(true)
			end
		end)

		it("computes launch velocities that land exactly on target", function()
			local g = GameConfig.Map.Gravity
			for _, pad in layout.jumpPads do
				local t = pad.flightTime
				local v = pad.velocity
				expect(pad.position.x + v.x * t).to.be.near(pad.target.x, 1e-6)
				expect(pad.position.z + v.z * t).to.be.near(pad.target.z, 1e-6)
				expect(pad.position.y + v.y * t - 0.5 * g * t * t).to.be.near(pad.target.y, 1e-6)
				expect(v.y > 0).to.equal(true)
			end
		end)
	end)

	describe("MapLayout content", function()
		it("offers impact candidates in every zone: walkable, prop-free, right tier", function()
			for tier = 1, Zones.COUNT do
				local candidates = layout.impactCandidates[tier]
				expect(#candidates > 10).to.equal(true)
				for _, tile in candidates do
					expect(tile.tier).to.equal(tier)
					expect(tile.kind).to.equal("ground")
					expect(tile.hasProp).to.equal(false)
				end
			end
		end)

		it("places landmarks, decorations and floating islands", function()
			local kinds: { [string]: number } = {}
			for _, prop in layout.props do
				kinds[prop.kind] = (kinds[prop.kind] or 0) + 1
			end
			expect(kinds.volcano).to.equal(GameConfig.Map.Volcanoes)
			expect(kinds.arch).to.equal(GameConfig.Map.Arches)
			expect(kinds.floatingIsland).to.equal(GameConfig.Map.FloatingIslands)
			expect((kinds.tree or 0) > 0).to.equal(true)
			expect((kinds.crystal or 0) > 0).to.equal(true)
		end)
	end)

	describe("MapLayout.tileAt", function()
		it("finds the tile under a position and nil over the void", function()
			local centre = MapLayout.tileAt(layout, 0, 0) :: MapLayout.Tile
			expect(centre.tier).to.equal(0)
			local sample = layout.tiles[#layout.tiles // 2]
			expect(MapLayout.tileAt(layout, sample.x + 3, sample.z - 3)).to.equal(sample)
			expect(MapLayout.tileAt(layout, 10000, 0)).to.equal(nil)
		end)
	end)

	describe("MapLayout.validateConfig", function()
		it("accepts the shipped config and rejects broken ones", function()
			expect((MapLayout.validateConfig(GameConfig.Map))).to.equal(true)
			expect((MapLayout.validateConfig(withOverrides({ MaxStep = 0 })))).to.equal(false)
			expect((MapLayout.validateConfig(withOverrides({ TreeChance = 2 })))).to.equal(false)
			expect((MapLayout.validateConfig(withOverrides({ Gravity = 0 })))).to.equal(false)
			expect(function()
				MapLayout.generate(withOverrides({ SkyIslands = -1 }))
			end).to.throw()
		end)
	end)
end
