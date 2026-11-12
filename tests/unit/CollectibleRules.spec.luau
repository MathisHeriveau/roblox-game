--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local CollectibleRules = require(ServerScriptService.Server.Systems.Collectibles.CollectibleRules)

local function context(overrides: { [string]: any }?): CollectibleRules.Context
	local base: { [string]: any } = {
		itemActive = true,
		playerAlive = true,
		dataLoaded = true,
		distance = 3,
		maxDistance = 14,
		now = 100,
		lastPickupAt = nil,
		cooldownSeconds = 0.15,
	}
	local source: { [string]: any } = overrides or {}
	for key, value in source do
		base[key] = value
	end
	return base :: any
end

return function()
	describe("CollectibleRules.canCollect", function()
		it("allows a legitimate pickup", function()
			expect((CollectibleRules.canCollect(context()))).to.equal(true)
		end)

		it("rejects inactive items, dead players and unloaded data", function()
			expect(select(2, CollectibleRules.canCollect(context({ itemActive = false })))).to.equal("Inactive")
			expect(select(2, CollectibleRules.canCollect(context({ playerAlive = false })))).to.equal("Dead")
			expect(select(2, CollectibleRules.canCollect(context({ dataLoaded = false })))).to.equal("NotLoaded")
		end)

		it("rejects pickups from too far away (teleport / reach exploits)", function()
			expect(select(2, CollectibleRules.canCollect(context({ distance = 14.01 })))).to.equal("TooFar")
			expect((CollectibleRules.canCollect(context({ distance = 14 })))).to.equal(true)
		end)

		it("rejects NaN and negative distances", function()
			expect(select(2, CollectibleRules.canCollect(context({ distance = 0 / 0 })))).to.equal("InvalidDistance")
			expect(select(2, CollectibleRules.canCollect(context({ distance = -1 })))).to.equal("InvalidDistance")
		end)

		it("enforces the per-player cooldown", function()
			expect(select(2, CollectibleRules.canCollect(context({ lastPickupAt = 99.9 })))).to.equal("Cooldown")
			expect((CollectibleRules.canCollect(context({ lastPickupAt = 99.8 })))).to.equal(true)
		end)
	end)
end
