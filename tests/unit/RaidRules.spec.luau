--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local RaidRules = require(ServerScriptService.Server.Systems.Raid.RaidRules)

local function facts(overrides: { [string]: any }?): RaidRules.StealFacts
	local base: { [string]: any } = {
		thiefUserId = 1,
		ownerUserId = 2,
		thiefAlive = true,
		thiefLoaded = true,
		thiefCarryingShards = 0,
		thiefCarryingStarling = false,
		baseLocked = false,
		victimStarlings = 3,
		minVictimStarlings = 2,
		pedestalOccupied = true,
		pedestalInTransit = false,
		distance = 4,
		maxDistance = 12,
	}
	for key, value in overrides or {} :: { [string]: any } do
		base[key] = value
	end
	return base :: any
end

local function reason(overrides: { [string]: any }): string?
	local _, why = RaidRules.canSteal(facts(overrides))
	return why
end

return function()
	describe("RaidRules.canSteal", function()
		it("allows a fair raid", function()
			expect((RaidRules.canSteal(facts()))).to.equal(true)
		end)

		it("forbids stealing from yourself, locked bases and protected beginners", function()
			expect(reason({ ownerUserId = 1 })).to.equal("OwnBase")
			expect(reason({ baseLocked = true })).to.equal("Locked")
			expect(reason({ victimStarlings = 1 })).to.equal("Protected")
		end)

		it("requires a free, alive, loaded thief", function()
			expect(reason({ thiefAlive = false })).to.equal("Dead")
			expect(reason({ thiefLoaded = false })).to.equal("NotLoaded")
			expect(reason({ thiefCarryingShards = 1 })).to.equal("Busy")
			expect(reason({ thiefCarryingStarling = true })).to.equal("Busy")
		end)

		it("requires an occupied pedestal not already being stolen, within reach", function()
			expect(reason({ pedestalOccupied = false })).to.equal("Empty")
			expect(reason({ pedestalInTransit = true })).to.equal("InTransit")
			expect(reason({ distance = 12.5 })).to.equal("TooFar")
			expect(reason({ distance = 0 / 0 })).to.equal("TooFar")
		end)
	end)

	describe("RaidRules locks", function()
		it("lets only the owner lock, and only once the previous lock expired", function()
			expect(RaidRules.canLock(true, 0, 10)).to.equal(true)
			expect(RaidRules.canLock(false, 0, 10)).to.equal(false)
			expect(RaidRules.canLock(true, 20, 10)).to.equal(false)
			expect(RaidRules.isLocked(20, 10)).to.equal(true)
			expect(RaidRules.isLocked(20, 20)).to.equal(false)
		end)
	end)

	describe("RaidRules.findStarling", function()
		it("finds the first identical Starling, or nil when it is gone", function()
			local list = { { rarity = 2, shiny = false }, { rarity = 4, shiny = true }, { rarity = 4, shiny = false } }
			expect(RaidRules.findStarling(list, 4, false)).to.equal(3)
			expect(RaidRules.findStarling(list, 4, true)).to.equal(2)
			expect(RaidRules.findStarling(list, 6, false)).to.equal(nil)
		end)
	end)
end
