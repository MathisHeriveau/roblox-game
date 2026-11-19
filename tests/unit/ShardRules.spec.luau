--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local ShardRules = require(ServerScriptService.Server.Systems.Shards.ShardRules)

local function shard(overrides: { [string]: any }?): ShardRules.ShardFacts
	local base: { [string]: any } = {
		tier = 1,
		isComet = false,
		readyAt = 0,
		held = false,
		blockedUserId = nil,
		blockedUntil = 0,
	}
	for key, value in overrides or {} :: { [string]: any } do
		base[key] = value
	end
	return base :: any
end

local function picker(overrides: { [string]: any }?): ShardRules.PickerFacts
	local base: { [string]: any } = {
		userId = 1,
		alive = true,
		loaded = true,
		carrying = 0,
		capacity = 2,
		zoneTier = 1,
		distance = 3,
		radius = 6,
	}
	for key, value in overrides or {} :: { [string]: any } do
		base[key] = value
	end
	return base :: any
end

local function reason(s: ShardRules.ShardFacts, p: ShardRules.PickerFacts, now: number?): string?
	local _, why = ShardRules.canPickup(s, p, now or 10)
	return why
end

return function()
	describe("ShardRules.canPickup", function()
		it("allows a legitimate pickup", function()
			expect((ShardRules.canPickup(shard(), picker(), 10))).to.equal(true)
		end)

		it("refuses held, falling (not ready) and out-of-range shards", function()
			expect(reason(shard({ held = true }), picker())).to.equal("Held")
			expect(reason(shard({ readyAt = 11 }), picker())).to.equal("NotReady")
			expect(reason(shard(), picker({ distance = 6.01 }))).to.equal("TooFar")
			expect(reason(shard(), picker({ distance = 0 / 0 }))).to.equal("TooFar")
		end)

		it("refuses dead, unloaded and full players", function()
			expect(reason(shard(), picker({ alive = false }))).to.equal("Dead")
			expect(reason(shard(), picker({ loaded = false }))).to.equal("NotLoaded")
			expect(reason(shard(), picker({ carrying = 2 }))).to.equal("Full")
		end)

		it("enforces zone locks, except for comet cores", function()
			expect(reason(shard({ tier = 3 }), picker({ zoneTier = 2 }))).to.equal("Locked")
			expect((ShardRules.canPickup(shard({ tier = 3, isComet = true }), picker({ zoneTier = 1 }), 10))).to.equal(
				true
			)
		end)

		it("blocks the victim from instantly re-grabbing a dropped shard", function()
			local dropped = shard({ blockedUserId = 1, blockedUntil = 12 })
			expect(reason(dropped, picker(), 11)).to.equal("Blocked")
			expect((ShardRules.canPickup(dropped, picker({ userId = 2 }), 11))).to.equal(true)
			expect((ShardRules.canPickup(dropped, picker(), 12.5))).to.equal(true)
		end)
	end)

	describe("ShardRules.deliveryPlausible", function()
		it("accepts realistic trips and rejects teleports", function()
			-- 100 studs at 20 studs/s takes 5 s.
			expect(ShardRules.deliveryPlausible(100, 5, 20)).to.equal(true)
			expect(ShardRules.deliveryPlausible(100, 3, 20)).to.equal(true) -- within tolerance
			expect(ShardRules.deliveryPlausible(400, 0.5, 20)).to.equal(false)
			expect(ShardRules.deliveryPlausible(0 / 0, 5, 20)).to.equal(false)
			expect(ShardRules.deliveryPlausible(10, 5, 0)).to.equal(false)
		end)
	end)

	describe("ShardRules bumps", function()
		local function candidate(userId: number, x: number, overrides: { [string]: any }?): ShardRules.BumpCandidate
			local base: { [string]: any } = {
				userId = userId,
				position = Vector3.new(x, 0, 0),
				alive = true,
				carrying = 1,
				immuneUntil = 0,
				inSafeZone = false,
			}
			for key, value in overrides or {} :: { [string]: any } do
				base[key] = value
			end
			return base :: any
		end

		it("respects the attacker cooldown", function()
			expect(ShardRules.canBump(nil, 5, 2.5, true)).to.equal(true)
			expect(ShardRules.canBump(4, 5, 2.5, true)).to.equal(false)
			expect(ShardRules.canBump(2, 5, 2.5, true)).to.equal(true)
			expect(ShardRules.canBump(nil, 5, 2.5, false)).to.equal(false)
		end)

		it("targets the nearest valid carrier in range", function()
			local target = ShardRules.bumpTarget(1, Vector3.zero, {
				candidate(1, 0),
				candidate(2, 6),
				candidate(3, 4),
				candidate(4, 20),
			}, 10, 9)
			expect(target).to.equal(3)
		end)

		it("ignores empty-handed, immune, dead and safe players", function()
			local target = ShardRules.bumpTarget(1, Vector3.zero, {
				candidate(2, 2, { carrying = 0 }),
				candidate(3, 2, { immuneUntil = 11 }),
				candidate(4, 2, { alive = false }),
				candidate(5, 2, { inSafeZone = true }),
			}, 10, 9)
			expect(target).to.equal(nil)
		end)
	end)
end
