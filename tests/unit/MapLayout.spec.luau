--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MapLayout = require(ServerScriptService.Server.Systems.Map.MapLayout)

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
		table.insert(parts, `{tile.gridX},{tile.gridZ},{tile.height}`)
	end
	for _, item in layout.collectibles do
		table.insert(parts, item.id)
	end
	return table.concat(parts, ";")
end

return function()
	describe("MapLayout.generate", function()
		local config = GameConfig.Map

		it("is deterministic for a given seed", function()
			local a = MapLayout.generate(config)
			local b = MapLayout.generate(config)
			expect(fingerprint(a)).to.equal(fingerprint(b))
		end)

		it("produces a different map for a different seed", function()
			local a = MapLayout.generate(config)
			local b = MapLayout.generate(withOverrides({ Seed = config.Seed + 1 }))
			expect(fingerprint(a) ~= fingerprint(b)).to.equal(true)
		end)

		it("creates exactly GridSize x GridSize tiles, centred on the origin", function()
			local layout = MapLayout.generate(config)
			expect(#layout.tiles).to.equal(config.GridSize * config.GridSize)
			local minX, maxX = math.huge, -math.huge
			for _, tile in layout.tiles do
				minX = math.min(minX, tile.x)
				maxX = math.max(maxX, tile.x)
			end
			expect(minX).to.equal(-maxX)
			expect(layout.extent).to.equal(config.GridSize * config.TileSize / 2)
		end)

		it("keeps heights within [0, MaxHeight] in whole studs", function()
			local layout = MapLayout.generate(config)
			for _, tile in layout.tiles do
				expect(tile.height >= 0 and tile.height <= config.MaxHeight).to.equal(true)
				expect(math.floor(tile.height)).to.equal(tile.height)
			end
		end)

		it("keeps the spawn plateau flat at Y = 0", function()
			local layout = MapLayout.generate(config)
			for _, tile in layout.tiles do
				if MapLayout.distanceFromCenter(tile.gridX, tile.gridZ, config.GridSize) <= config.SpawnClearRadius then
					expect(tile.height).to.equal(0)
				end
			end
			expect(layout.spawn.y).to.equal(0)
		end)

		it("places the configured number of unique collectibles outside the spawn zone", function()
			local layout = MapLayout.generate(config)
			expect(#layout.collectibles).to.equal(config.CollectibleCount)
			local seen: { [string]: boolean } = {}
			for _, item in layout.collectibles do
				expect(seen[item.id]).to.equal(nil)
				seen[item.id] = true
				local distance = MapLayout.distanceFromCenter(item.gridX, item.gridZ, config.GridSize)
				expect(distance > config.SpawnClearRadius).to.equal(true)
				expect(math.abs(item.x) <= layout.extent and math.abs(item.z) <= layout.extent).to.equal(true)
			end
		end)

		it("supports filling every available tile with collectibles", function()
			local available = 5 * 5 - 3 * 3
			local layout =
				MapLayout.generate(withOverrides({ GridSize = 5, SpawnClearRadius = 1, CollectibleCount = available }))
			expect(#layout.collectibles).to.equal(available)
		end)
	end)

	describe("MapLayout.validateConfig", function()
		it("accepts the shipped configuration", function()
			expect((MapLayout.validateConfig(GameConfig.Map))).to.equal(true)
		end)

		it("rejects even grids, oversized spawn zones and impossible collectible counts", function()
			expect((MapLayout.validateConfig(withOverrides({ GridSize = 12 })))).to.equal(false)
			expect((MapLayout.validateConfig(withOverrides({ GridSize = 5, SpawnClearRadius = 2 })))).to.equal(false)
			expect((MapLayout.validateConfig(withOverrides({ GridSize = 5, CollectibleCount = 17 })))).to.equal(false)
		end)

		it("makes generate() fail loudly on invalid config", function()
			expect(function()
				MapLayout.generate(withOverrides({ GridSize = 4 }))
			end).to.throw()
		end)
	end)
end
