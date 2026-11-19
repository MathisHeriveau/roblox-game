--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

return function()
	describe("Zones", function()
		it("maps distances to tiers: hub, rings, off-island", function()
			expect(Zones.tierForDistance(0)).to.equal(0)
			expect(Zones.tierForDistance(Zones.HUB_RADIUS)).to.equal(0)
			expect(Zones.tierForDistance(Zones.HUB_RADIUS + 0.1)).to.equal(1)
			expect(Zones.tierForDistance(Zones.HUB_RADIUS + Zones.WIDTH)).to.equal(1)
			expect(Zones.tierForDistance(Zones.HUB_RADIUS + Zones.WIDTH + 0.1)).to.equal(2)
			expect(Zones.tierForDistance(Zones.RADIUS)).to.equal(Zones.COUNT)
			expect(Zones.tierForDistance(Zones.RADIUS + 0.5)).to.equal(nil)
			expect(Zones.tierForDistance(0 / 0)).to.equal(nil)
		end)

		it("maps world positions through the tile size", function()
			expect(Zones.tierAt(0, 0)).to.equal(0)
			local inDesert = (Zones.HUB_RADIUS + Zones.WIDTH + 1) * Zones.TILE_SIZE
			expect(Zones.tierAt(inDesert, 0)).to.equal(2)
			expect(Zones.tierAt(0, -inDesert)).to.equal(2)
		end)

		it("has consistent, increasing zone data", function()
			local previousCost = -1
			for tier, zone in Zones.list do
				expect(zone.tier).to.equal(tier)
				expect(zone.unlockCost > previousCost).to.equal(true)
				previousCost = zone.unlockCost
				expect(#zone.weights).to.equal(Rarities.COUNT)
				expect(Zones.byKey(zone.key)).to.equal(zone)
			end
			expect(Zones.get(1).unlockCost).to.equal(0)
			expect(#Zones.COMET_WEIGHTS).to.equal(Rarities.COUNT)
		end)
	end)
end
