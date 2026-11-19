--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

return function()
	describe("Zones.tierForDistance", function()
		it("maps unwarped distances to tiers: hub, zones, beyond the world", function()
			expect(Zones.tierForDistance(0)).to.equal(0)
			expect(Zones.tierForDistance(Zones.HUB_RADIUS)).to.equal(0)
			expect(Zones.tierForDistance(Zones.HUB_RADIUS + 0.1)).to.equal(1)
			expect(Zones.tierForDistance(Zones.outerRadius(1))).to.equal(1)
			expect(Zones.tierForDistance(Zones.outerRadius(1) + 0.1)).to.equal(2)
			expect(Zones.tierForDistance(Zones.RADIUS)).to.equal(Zones.COUNT)
			expect(Zones.tierForDistance(Zones.RADIUS + 0.5)).to.equal(nil)
			expect(Zones.tierForDistance(0 / 0)).to.equal(nil)
		end)

		it("derives the world radius from every zone width", function()
			local total = Zones.HUB_RADIUS
			for _, zone in Zones.list do
				expect(zone.width > 0).to.equal(true)
				total += zone.width
			end
			expect(Zones.RADIUS).to.equal(total)
		end)
	end)

	describe("Zones.tierAt (organic borders)", function()
		it("keeps the hub perfectly round", function()
			for step = 0, 63 do
				local angle = step / 64 * math.pi * 2
				local distance = (Zones.HUB_RADIUS - 0.01) * Zones.TILE_SIZE
				expect(Zones.tierAt(math.cos(angle) * distance, math.sin(angle) * distance)).to.equal(0)
			end
		end)

		it("bends other borders by a bounded warp", function()
			local bentSomewhere = false
			for step = 0, 359 do
				local angle = math.rad(step)
				local warp = Zones.warp(math.cos(angle), math.sin(angle))
				expect(math.abs(warp) <= 1.75).to.equal(true)
				if math.abs(warp) > 0.5 then
					bentSomewhere = true
				end
			end
			expect(bentSomewhere).to.equal(true)
		end)

		it("is consistent with the warped distance", function()
			for step = 0, 99 do
				local angle = step * 0.37
				local distance = (6 + step % 18) * Zones.TILE_SIZE
				local x, z = math.cos(angle) * distance, math.sin(angle) * distance
				local warped = math.max(Zones.HUB_RADIUS + 0.001, distance / Zones.TILE_SIZE + Zones.warp(x, z))
				expect(Zones.tierAt(x, z)).to.equal(Zones.tierForDistance(warped))
			end
		end)
	end)

	describe("Zones data", function()
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
