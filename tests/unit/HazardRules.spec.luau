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

		-- Regression (measured in Studio): a standing R15 root is ~3.3 studs above the ground, and
		-- the terrain rises up to ~2.2 studs at the rim of a lava pit where it blends into the
		-- neighbouring tiles. Standing anywhere on the pit must burn.
		it("burns a character standing anywhere in a lava pit, rim included", function()
			local STANDING_ROOT = 3.3
			local RIM_RISE = 2.2
			expect(HazardRules.classify(10 + STANDING_ROOT, tile("lava", 10), VOID)).to.equal("lava")
			expect(HazardRules.classify(10 + RIM_RISE + STANDING_ROOT, tile("lava", 10), VOID)).to.equal("lava")
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

	-- Playtest 2026-11-28: burning and falling gave no feedback at all (no toast, no reason).
	describe("HazardRules.deathNotice", function()
		it("explains a fall and the shards it cost", function()
			expect(HazardRules.deathNotice("void", 0)).to.equal("💫 You fell off the island! Back to your base…")
			expect(HazardRules.deathNotice("void", 1)).to.equal(
				"💫 You fell off the island and lost 1 shard! Back to your base…"
			)
			expect(HazardRules.deathNotice("void", 3)).to.equal(
				"💫 You fell off the island and lost 3 shards! Back to your base…"
			)
		end)

		it("explains a lava death (dropped shards stay in the lava pit)", function()
			expect(HazardRules.deathNotice("lava", 0)).to.equal("🔥 You burned in the lava! Back to your base…")
			expect(HazardRules.deathNotice("lava", 2)).to.equal(
				"🔥 You burned in the lava and dropped 2 shards! Back to your base…"
			)
		end)

		it("says nothing when it was not a hazard", function()
			expect(HazardRules.deathNotice("safe", 2)).to.equal(nil)
		end)
	end)

	describe("HazardRules.shouldWarnBurn", function()
		it("warns on the first burn, then at most once per interval", function()
			expect(HazardRules.shouldWarnBurn(nil, 100, 4)).to.equal(true)
			expect(HazardRules.shouldWarnBurn(100, 101, 4)).to.equal(false)
			expect(HazardRules.shouldWarnBurn(100, 103.99, 4)).to.equal(false)
			expect(HazardRules.shouldWarnBurn(100, 104, 4)).to.equal(true)
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
