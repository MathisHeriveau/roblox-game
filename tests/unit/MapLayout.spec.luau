--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MapLayout = require(ServerScriptService.Server.Systems.Map.MapLayout)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

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

return function()
	local layout = MapLayout.generate(GameConfig.Map)

	describe("MapLayout.generate", function()
		it("is deterministic for a seed and changes with it", function()
			expect(fingerprint(MapLayout.generate(GameConfig.Map))).to.equal(fingerprint(layout))
			local other = MapLayout.generate(withOverrides({ Seed = GameConfig.Map.Seed + 1 }))
			expect(fingerprint(other) ~= fingerprint(layout)).to.equal(true)
		end)

		it("builds a circular island covering every zone", function()
			local seen: { [number]: boolean } = {}
			for _, tile in layout.tiles do
				expect(tile.distance <= Zones.RADIUS + 0.5).to.equal(true)
				expect(tile.tier).to.equal(Zones.tierForDistance(tile.distance))
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
			expect(lava > 0).to.equal(true)
			expect(lava / total).to.be.near(Zones.get(3).lavaChance, 0.05)
		end)

		it("never lets walkable neighbours differ by more than MaxStep (reachability)", function()
			local maxStep = GameConfig.Map.MaxStep
			for _, tile in layout.tiles do
				if tile.kind == "ground" then
					for _, offset in { { 1, 0 }, { 0, 1 } } do
						local neighbour = MapLayout.tileAt(
							layout,
							tile.x + offset[1] * layout.tileSize,
							tile.z + offset[2] * layout.tileSize
						)
						if neighbour and neighbour.kind == "ground" then
							expect(math.abs(tile.height - neighbour.height) <= maxStep).to.equal(true)
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

		it("places decorations and floating islands", function()
			local kinds: { [string]: number } = {}
			for _, prop in layout.props do
				kinds[prop.kind] = (kinds[prop.kind] or 0) + 1
			end
			expect(kinds.floatingIsland).to.equal(GameConfig.Map.FloatingIslands)
			expect((kinds.tree or 0) > 0).to.equal(true)
			expect((kinds.crystal or 0) > 0).to.equal(true)
		end)
	end)

	describe("MapLayout.tileAt", function()
		it("finds the tile under a position and nil off-island", function()
			local centre = MapLayout.tileAt(layout, 0, 0)
			expect(centre).to.be.ok()
			expect((centre :: MapLayout.Tile).tier).to.equal(0)
			local sample = layout.tiles[#layout.tiles // 2]
			expect(MapLayout.tileAt(layout, sample.x + 3, sample.z - 3)).to.equal(sample)
			expect(MapLayout.tileAt(layout, 10000, 0)).to.equal(nil)
			local corner = (Zones.RADIUS + 0.5) * layout.tileSize * 0.95
			expect(MapLayout.tileAt(layout, corner, corner)).to.equal(nil)
		end)
	end)

	describe("MapLayout.validateConfig", function()
		it("accepts the shipped config and rejects broken ones", function()
			expect((MapLayout.validateConfig(GameConfig.Map))).to.equal(true)
			expect((MapLayout.validateConfig(withOverrides({ MaxStep = 0 })))).to.equal(false)
			expect((MapLayout.validateConfig(withOverrides({ TreeChance = 2 })))).to.equal(false)
			expect(function()
				MapLayout.generate(withOverrides({ FloatingIslands = -1 }))
			end).to.throw()
		end)
	end)
end
