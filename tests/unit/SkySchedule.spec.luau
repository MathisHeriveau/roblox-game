--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MapLayout = require(ServerScriptService.Server.Systems.Map.MapLayout)
local Prng = require(ReplicatedStorage.Shared.Utils.Prng)
local SkySchedule = require(ServerScriptService.Server.Systems.Shards.SkySchedule)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local events = GameConfig.Events

local function always(_tile: MapLayout.Tile): boolean
	return true
end

return function()
	local layout = MapLayout.generate(GameConfig.Map)

	describe("SkySchedule.meteorCount", function()
		it("scales with players and is capped", function()
			expect(SkySchedule.meteorCount(0, events)).to.equal(events.MeteorBase)
			expect(SkySchedule.meteorCount(2, events)).to.equal(events.MeteorBase + 2 * events.MeteorPerPlayer)
			expect(SkySchedule.meteorCount(1000, events)).to.equal(events.MeteorMax)
		end)
	end)

	describe("SkySchedule.meteorImpacts", function()
		it("lands on distinct free tiles with rarities allowed in each zone", function()
			local impacts = SkySchedule.meteorImpacts(Prng.new(3), layout, 40, always)
			expect(#impacts).to.equal(40)
			local seen: { [MapLayout.Tile]: boolean } = {}
			for _, impact in impacts do
				expect(seen[impact.tile]).to.equal(nil)
				seen[impact.tile] = true
				expect(impact.isComet).to.equal(false)
				expect(impact.tile.tier >= 1).to.equal(true)
				expect(Zones.get(impact.tile.tier).weights[impact.rarity] > 0).to.equal(true)
			end
		end)

		it("spreads impacts over every zone", function()
			local perZone: { [number]: number } = {}
			for _, impact in SkySchedule.meteorImpacts(Prng.new(8), layout, 200, always) do
				perZone[impact.tile.tier] = (perZone[impact.tile.tier] or 0) + 1
			end
			for tier = 1, Zones.COUNT do
				expect((perZone[tier] or 0) > 0).to.equal(true)
			end
			expect(perZone[1] > perZone[Zones.COUNT]).to.equal(true)
		end)

		it("respects occupied tiles", function()
			local impacts = SkySchedule.meteorImpacts(Prng.new(4), layout, 10, function()
				return false
			end)
			expect(#impacts).to.equal(0)
		end)

		it("is deterministic for a seed", function()
			local a = SkySchedule.meteorImpacts(Prng.new(21), layout, 12, always)
			local b = SkySchedule.meteorImpacts(Prng.new(21), layout, 12, always)
			for index, impact in a do
				expect(impact.tile).to.equal(b[index].tile)
				expect(impact.rarity).to.equal(b[index].rarity)
			end
		end)
	end)

	describe("SkySchedule.cometImpacts", function()
		it("drops one comet core outside the meadow plus scattered shards around it", function()
			local impacts = SkySchedule.cometImpacts(Prng.new(5), layout, events, always)
			expect(#impacts).to.equal(1 + events.CometScatter)
			local core = impacts[1]
			expect(core.isComet).to.equal(true)
			expect(core.tile.tier >= 2).to.equal(true)
			expect(Zones.COMET_WEIGHTS[core.rarity] > 0).to.equal(true)
			for index = 2, #impacts do
				local impact = impacts[index]
				expect(impact.isComet).to.equal(false)
				local dx, dz = impact.tile.gridX - core.tile.gridX, impact.tile.gridZ - core.tile.gridZ
				expect(dx * dx + dz * dz <= 9).to.equal(true)
			end
		end)

		it("returns nothing when no tile is free", function()
			local impacts = SkySchedule.cometImpacts(Prng.new(5), layout, events, function()
				return false
			end)
			expect(#impacts).to.equal(0)
		end)
	end)
end
