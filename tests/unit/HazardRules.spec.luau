--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Systems = ServerScriptService.Server.Systems
local HazardRules = require(Systems.Hazards.HazardRules)
local MapLayout = require(Systems.Map.MapLayout)

local VOID = -110

local function tile(kind: MapLayout.TileKind, height: number): MapLayout.Tile
	return {
		gridX = 0,
		gridZ = 0,
		x = 0,
		z = 0,
		distance = 0,
		tier = 3,
		kind = kind,
		height = height,
		bottom = height - 20,
		hasProp = false,
		island = 0,
	}
end

return function()
	describe("HazardRules.classify", function()
		it("is safe on ground, and above lava out of reach", function()
			expect(HazardRules.classify(12, tile("ground", 10), VOID)).to.equal("safe")
			expect(HazardRules.classify(10 + HazardRules.LAVA_REACH, tile("lava", 10), VOID)).to.equal("safe")
		end)

		it("burns inside the lava reach", function()
			expect(HazardRules.classify(10, tile("lava", 10), VOID)).to.equal("lava")
			expect(HazardRules.classify(10 + HazardRules.LAVA_REACH - 0.01, tile("lava", 10), VOID)).to.equal("lava")
		end)

		it("kills below the void height, with or without a tile underneath", function()
			expect(HazardRules.classify(VOID - 0.01, nil, VOID)).to.equal("void")
			expect(HazardRules.classify(VOID - 50, tile("ground", 10), VOID)).to.equal("void")
			expect(HazardRules.classify(VOID - 50, tile("lava", 10), VOID)).to.equal("void")
			expect(HazardRules.classify(VOID, nil, VOID)).to.equal("safe")
		end)

		it("is safe while falling over the void above the kill height", function()
			expect(HazardRules.classify(0, nil, VOID)).to.equal("safe")
		end)

		it("treats non-finite heights as void", function()
			expect(HazardRules.classify(0 / 0, tile("ground", 10), VOID)).to.equal("void")
			expect(HazardRules.classify(math.huge, nil, VOID)).to.equal("void")
			expect(HazardRules.classify(-math.huge, nil, VOID)).to.equal("void")
		end)
	end)

	describe("GameConfig.Hazards.VoidKillHeight", function()
		it("lies below every walkable surface of the generated world", function()
			local layout = MapLayout.generate(GameConfig.Map)
			local lowest = math.huge
			for _, t in layout.tiles do
				lowest = math.min(lowest, t.height)
			end
			for _, island in layout.islands do
				lowest = math.min(lowest, island.height)
			end
			expect(GameConfig.Hazards.VoidKillHeight < lowest - 20).to.equal(true)
		end)
	end)
end
