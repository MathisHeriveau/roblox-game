--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local settings = GameConfig.Economy

local function newData(): Economy.EconomyData
	return {
		coins = 0,
		vault = 0,
		xp = 0,
		rebirths = 0,
		zoneTier = 1,
		upgrades = { speed = 0, carry = 0, magnet = 0, slots = 0 },
		starlings = {},
		lastSeen = 0,
		discovered = {},
		dailyLastClaim = 0,
		dailyStreak = 0,
		stats = { collectiblesCollected = 0, sessions = 0, shardsDelivered = 0, bumpsLanded = 0, cometsCaught = 0 },
	}
end

local function starling(rarity: number, shiny: boolean?): Economy.Starling
	return { rarity = rarity, shiny = shiny == true }
end

return function()
	describe("Economy upgrade effects and costs", function()
		it("derives stats from upgrade levels", function()
			expect(Economy.walkSpeed(0)).to.equal(settings.BaseWalkSpeed)
			expect(Economy.walkSpeed(3)).to.equal(settings.BaseWalkSpeed + 3 * settings.SpeedPerLevel)
			expect(Economy.capacity(0)).to.equal(settings.BaseCapacity)
			expect(Economy.slots(2)).to.equal(settings.BaseSlots + 2)
			expect(Economy.magnetRadius(2)).to.be.near(settings.BaseMagnetRadius + 2 * settings.MagnetPerLevel, 1e-9)
		end)

		it("grows costs geometrically and stops at max level", function()
			local first = Economy.upgradeCost("speed", 0) :: number
			local second = Economy.upgradeCost("speed", 1) :: number
			expect(first).to.equal(50)
			expect(second > first).to.equal(true)
			expect(Economy.upgradeCost("speed", 10)).to.equal(nil)
		end)

		it("slows carriers down but never below the floor", function()
			expect(Economy.carrySpeedFactor(0)).to.equal(1)
			expect(Economy.carrySpeedFactor(2)).to.be.near(1 - 2 * settings.CarryPenaltyPerShard, 1e-9)
			expect(Economy.carrySpeedFactor(100)).to.equal(settings.MinCarrySpeedFactor)
		end)

		it("rejects unknown upgrades loudly", function()
			expect(function()
				Economy.upgradeCost("teleport", 0)
			end).to.throw()
		end)
	end)

	describe("Economy income", function()
		it("sums Starling income, triples shinies, applies rebirth multiplier, floors the result", function()
			local starlings = { starling(1), starling(2), starling(1, true) }
			-- 1 + 5 + 1 * 3 = 9
			expect(Economy.incomePerSecond(starlings, 0)).to.equal(9)
			-- x1.5 = 13.5 -> 13
			expect(Economy.incomePerSecond(starlings, 1)).to.equal(13)
		end)

		it("computes capped, reduced offline earnings", function()
			expect(Economy.offlineEarnings(10, 100)).to.equal(math.floor(100 * 10 * settings.OfflineRate))
			local capped = Economy.offlineEarnings(10, settings.OfflineCapSeconds * 10)
			expect(capped).to.equal(math.floor(settings.OfflineCapSeconds * 10 * settings.OfflineRate))
			expect(Economy.offlineEarnings(10, -5)).to.equal(0)
			expect(Economy.offlineEarnings(0, 1000)).to.equal(0)
			expect(Economy.offlineEarnings(10, 0 / 0)).to.equal(0)
		end)
	end)

	describe("Economy.placeStarling", function()
		it("uses a free pedestal first", function()
			local placement = Economy.placeStarling({ starling(1) }, 4, starling(2), 0)
			expect(placement.outcome).to.equal("placed")
			expect(#placement.starlings).to.equal(2)
			expect(placement.soldValue).to.equal(0)
		end)

		it("replaces the weakest Starling when full and the newcomer is better", function()
			local placement = Economy.placeStarling({ starling(2), starling(1), starling(3) }, 3, starling(4), 0)
			expect(placement.outcome).to.equal("replaced")
			expect(placement.starlings[2].rarity).to.equal(4)
			expect(placement.soldValue).to.equal(Economy.sellValue(starling(1), 0))
		end)

		it("sells the newcomer when it is not better", function()
			local placement = Economy.placeStarling({ starling(3), starling(3) }, 2, starling(1), 0)
			expect(placement.outcome).to.equal("sold")
			expect(placement.starlings[1].rarity).to.equal(3)
			expect(placement.soldValue).to.equal(settings.SellSeconds)
		end)

		it("never mutates the input list", function()
			local original = { starling(1) }
			Economy.placeStarling(original, 4, starling(2), 0)
			expect(#original).to.equal(1)
		end)
	end)

	describe("Economy levels", function()
		it("starts at level 1 and levels up exactly at thresholds", function()
			local level, progress, goal = Economy.levelFromXp(0)
			expect(level).to.equal(1)
			expect(progress).to.equal(0)
			expect(goal).to.equal(Economy.xpToNextLevel(1))
			local nextLevel, nextProgress = Economy.levelFromXp(Economy.xpToNextLevel(1))
			expect(nextLevel).to.equal(2)
			expect(nextProgress).to.equal(0)
		end)

		it("gives double XP for shiny deliveries", function()
			expect(Economy.xpForDelivery(3, true)).to.equal(Rarities.get(3).xp * 2)
		end)
	end)

	describe("Economy purchases", function()
		it("buys an upgrade when affordable", function()
			local data = newData()
			data.coins = 1000
			local ok, reason, cost = Economy.canPurchase(data, "upgrade", "carry")
			expect(ok).to.equal(true)
			expect(reason).to.equal(nil)
			Economy.applyPurchase(data, "upgrade", "carry")
			expect(data.upgrades.carry).to.equal(1)
			expect(data.coins).to.equal(1000 - cost)
		end)

		it("refuses unaffordable, maxed and unknown purchases", function()
			local data = newData()
			expect((Economy.canPurchase(data, "upgrade", "speed"))).to.equal(false)
			data.coins = 10 ^ 12
			data.upgrades.speed = 10
			expect(select(2, Economy.canPurchase(data, "upgrade", "speed"))).to.equal("Already maxed")
			expect((Economy.canPurchase(data, "upgrade", "teleport"))).to.equal(false)
			expect((Economy.canPurchase(data, "vip", nil))).to.equal(false)
			expect(function()
				Economy.applyPurchase(newData(), "upgrade", "speed")
			end).to.throw()
		end)

		it("unlocks zones strictly in order", function()
			local data = newData()
			data.coins = 10 ^ 9
			expect((Economy.canPurchase(data, "zone", "lava"))).to.equal(false)
			Economy.applyPurchase(data, "zone", "desert")
			expect(data.zoneTier).to.equal(2)
			expect((Economy.canPurchase(data, "zone", "desert"))).to.equal(false)
			expect((Economy.canPurchase(data, "zone", "lava"))).to.equal(true)
		end)

		it("rebirths only with every zone unlocked, resetting progress but keeping XP", function()
			local data = newData()
			data.coins = Economy.rebirthCost(0)
			expect((Economy.canRebirth(data))).to.equal(false)
			data.zoneTier = Zones.COUNT
			data.xp = 500
			data.upgrades.speed = 4
			data.starlings = { starling(5) }
			Economy.applyPurchase(data, "rebirth", nil)
			expect(data.rebirths).to.equal(1)
			expect(data.coins).to.equal(0)
			expect(data.zoneTier).to.equal(1)
			expect(data.upgrades.speed).to.equal(0)
			expect(#data.starlings).to.equal(0)
			expect(data.xp).to.equal(500)
			expect(Economy.rebirthCost(1) > Economy.rebirthCost(0)).to.equal(true)
		end)
	end)

	describe("Economy.deliver", function()
		it("hatches Starlings, grants XP, counts stats and comet catches", function()
			local data = newData()
			local placements = Economy.deliver(data, {
				{ rarity = 2, shiny = false, isComet = false },
				{ rarity = 4, shiny = true, isComet = true },
			})
			expect(#placements).to.equal(2)
			expect(#data.starlings).to.equal(2)
			expect(data.xp).to.equal(Rarities.get(2).xp + Rarities.get(4).xp * 2)
			expect(data.stats.shardsDelivered).to.equal(2)
			expect(data.stats.cometsCaught).to.equal(1)
		end)

		it("converts overflow into coins when the base is full", function()
			local data = newData()
			data.starlings = { starling(3), starling(3), starling(3), starling(3) }
			data.discovered = { r1 = true }
			Economy.deliver(data, { { rarity = 1, shiny = false, isComet = false } })
			expect(#data.starlings).to.equal(4)
			expect(data.coins).to.equal(Economy.sellValue(starling(1), 0))
		end)

		it("rejects invalid rarities", function()
			expect(function()
				Economy.deliver(newData(), { { rarity = 99, shiny = false, isComet = false } })
			end).to.throw()
		end)

		it("records first discoveries in the Index and pays a one-time reward", function()
			local data = newData()
			local first = Economy.deliver(data, { { rarity = 3, shiny = true, isComet = false } })[1]
			expect(first.discovered).to.equal(true)
			expect(first.discoveryReward).to.equal(Economy.discoveryReward(3, true))
			expect(data.discovered.r3s).to.equal(true)
			expect(data.coins).to.equal(Economy.discoveryReward(3, true))
			local again = Economy.deliver(data, { { rarity = 3, shiny = true, isComet = false } })[1]
			expect(again.discovered).to.equal(nil)
			expect(data.coins).to.equal(Economy.discoveryReward(3, true))
			-- The plain variant is a separate entry.
			Economy.deliver(data, { { rarity = 3, shiny = false, isComet = false } })
			expect(Economy.indexCount(data.discovered)).to.equal(2)
		end)
	end)

	describe("Economy Starling Index", function()
		it("names one entry per rarity and shiny variant", function()
			expect(Economy.indexKey(1, false)).to.equal("r1")
			expect(Economy.indexKey(6, true)).to.equal("r6s")
			expect(Economy.INDEX_SIZE).to.equal(Rarities.COUNT * 2)
		end)

		it("counts only discovered entries", function()
			expect(Economy.indexCount({})).to.equal(0)
			expect(Economy.indexCount({ r1 = true, r2s = true, r3 = false })).to.equal(2)
		end)

		it("pays at least the minimum discovery reward, more for rarer finds", function()
			local common = Rarities.get(1).income * settings.DiscoveryRewardSeconds
			expect(Economy.discoveryReward(1, false)).to.equal(math.max(settings.MinDiscoveryReward, common))
			expect(Economy.discoveryReward(1, false) >= settings.MinDiscoveryReward).to.equal(true)
			expect(Economy.discoveryReward(6, false) > Economy.discoveryReward(5, false)).to.equal(true)
			expect(Economy.discoveryReward(4, true) > Economy.discoveryReward(4, false)).to.equal(true)
		end)

		it("adds a permanent income bonus per entry", function()
			expect(Economy.multiplier(0, 0)).to.equal(1)
			expect(Economy.multiplier(0)).to.equal(1)
			expect(Economy.multiplier(0, 5)).to.be.near(1 + 5 * settings.IndexBonusPerEntry, 1e-9)
			local data = newData()
			data.starlings = { starling(5) }
			local plain = Economy.baseIncome(data)
			expect(plain).to.equal(Rarities.get(5).income)
			data.discovered = { r1 = true, r2 = true }
			expect(Economy.baseIncome(data)).to.equal(math.floor(plain * (1 + 2 * settings.IndexBonusPerEntry)))
			expect(Economy.baseIncome(data) > plain).to.equal(true)
		end)
	end)

	describe("Economy daily reward", function()
		local DAY = 24 * 60 * 60
		local NOW = 1800000000

		it("is claimable immediately for a new player, then after the cooldown", function()
			expect((Economy.dailyStatus(0, NOW))).to.equal(true)
			local ready, wait = Economy.dailyStatus(NOW, NOW + 60)
			expect(ready).to.equal(false)
			expect(wait).to.equal(settings.DailyCooldownSeconds - 60)
			ready, wait = Economy.dailyStatus(NOW, NOW + settings.DailyCooldownSeconds)
			expect(ready).to.equal(true)
			expect(wait).to.equal(0)
		end)

		it("advances the streak, wraps after the last day and resets after a missed day", function()
			expect(Economy.nextDailyDay(0, 0, NOW)).to.equal(1)
			expect(Economy.nextDailyDay(NOW, 3, NOW + DAY)).to.equal(4)
			expect(Economy.nextDailyDay(NOW, settings.DailyStreakLength, NOW + DAY)).to.equal(1)
			expect(Economy.nextDailyDay(NOW, 5, NOW + settings.DailyResetSeconds)).to.equal(1)
		end)

		it("grows with the day and the base income, with a big final day", function()
			local day1 = Economy.dailyReward(1, 0)
			expect(day1).to.equal(settings.DailyBaseReward)
			expect(Economy.dailyReward(2, 0)).to.equal(day1 * 2)
			expect(Economy.dailyReward(1, 10) > day1).to.equal(true)
			local last = settings.DailyStreakLength
			expect(Economy.dailyReward(last, 0)).to.equal(day1 * last * 3)
		end)

		it("claims once per cooldown and records the streak", function()
			local data = newData()
			local day, coins = Economy.claimDaily(data, NOW)
			expect(day).to.equal(1)
			expect(data.coins).to.equal(coins)
			expect(data.dailyStreak).to.equal(1)
			expect(data.dailyLastClaim).to.equal(NOW)
			expect(function()
				Economy.claimDaily(data, NOW + 10)
			end).to.throw()
			expect(data.coins).to.equal(coins)
			day = Economy.claimDaily(data, NOW + DAY)
			expect(day).to.equal(2)
		end)
	end)
end
