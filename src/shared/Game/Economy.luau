--!strict
--[[
	Economy — every number of the Comet Raiders progression, as pure functions.

	Shared by the server (authority: purchases, income, deliveries) and the client (shop display),
	so both always agree. Functions that mutate (`applyPurchase`, `applyRebirth`, `deliver`) are
	designed to run inside PlayerDataService.update mutators: they validate first and error on an
	invalid request, which makes the update abort without changing anything.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local GameConfig = require(Config.GameConfig)
local Rarities = require(Config.Rarities)
local Upgrades = require(Config.Upgrades)
local Zones = require(Config.Zones)

local settings = GameConfig.Economy

export type Starling = {
	rarity: number,
	shiny: boolean,
}

export type UpgradeLevels = {
	speed: number,
	carry: number,
	magnet: number,
	slots: number,
}

-- Mirrors the persisted PlayerData shape (server PlayerDataSchema): Luau checks nested table
-- types exactly, so both must stay field-for-field identical.
export type EconomyData = {
	coins: number,
	vault: number,
	xp: number,
	rebirths: number,
	zoneTier: number,
	upgrades: UpgradeLevels,
	starlings: { Starling },
	lastSeen: number,
	-- Starling Index: discovered entries keyed by Economy.indexKey.
	discovered: { [string]: boolean },
	dailyLastClaim: number,
	dailyStreak: number,
	stats: {
		collectiblesCollected: number,
		sessions: number,
		shardsDelivered: number,
		bumpsLanded: number,
		cometsCaught: number,
	},
}

export type PurchaseKind = "upgrade" | "zone" | "rebirth"

export type PlacementOutcome = "placed" | "replaced" | "sold"

export type Placement = {
	outcome: PlacementOutcome,
	starlings: { Starling },
	-- Coins earned from selling the Starling that did not fit (new one or replaced one).
	soldValue: number,
	sold: Starling?,
	-- Set by Economy.deliver: first time this rarity/shiny combination is delivered.
	discovered: boolean?,
	discoveryReward: number?,
}

local Economy = {}

Economy.MAX_SLOTS = settings.BaseSlots + (Upgrades.get("slots") :: Upgrades.Upgrade).maxLevel

--------------------------------------------------------------------------------------------------
-- Upgrade effects
--------------------------------------------------------------------------------------------------

function Economy.walkSpeed(speedLevel: number): number
	return settings.BaseWalkSpeed + settings.SpeedPerLevel * speedLevel
end

function Economy.capacity(carryLevel: number): number
	return settings.BaseCapacity + carryLevel
end

function Economy.magnetRadius(magnetLevel: number): number
	return settings.BaseMagnetRadius + settings.MagnetPerLevel * magnetLevel
end

function Economy.slots(slotsLevel: number): number
	return settings.BaseSlots + slotsLevel
end

-- Speed factor while carrying `count` shards (1 = no penalty).
function Economy.carrySpeedFactor(count: number): number
	return math.max(settings.MinCarrySpeedFactor, 1 - settings.CarryPenaltyPerShard * math.max(0, count))
end

-- Value of `id` at `level`, as shown in the shop ("22 → 24").
function Economy.upgradeEffect(id: string, level: number): number
	if id == "speed" then
		return Economy.walkSpeed(level)
	elseif id == "carry" then
		return Economy.capacity(level)
	elseif id == "magnet" then
		return Economy.magnetRadius(level)
	elseif id == "slots" then
		return Economy.slots(level)
	end
	error(`Economy: unknown upgrade "{id}"`)
end

-- Cost of buying the level after `currentLevel`, or nil when already maxed.
function Economy.upgradeCost(id: string, currentLevel: number): number?
	local upgrade = Upgrades.get(id)
	assert(upgrade ~= nil, `Economy: unknown upgrade "{id}"`)
	if currentLevel >= upgrade.maxLevel then
		return nil
	end
	return math.floor(upgrade.baseCost * upgrade.growth ^ currentLevel)
end

--------------------------------------------------------------------------------------------------
-- Income
--------------------------------------------------------------------------------------------------

-- Permanent income multiplier: rebirths and Starling Index entries.
function Economy.multiplier(rebirths: number, indexCount: number?): number
	return 1 + settings.RebirthBonus * rebirths + settings.IndexBonusPerEntry * (indexCount or 0)
end

function Economy.starlingIncome(starling: Starling): number
	local base = Rarities.get(starling.rarity).income
	return if starling.shiny then base * Rarities.SHINY_MULTIPLIER else base
end

-- Whole coins per second produced by a base (fractions are dropped: data stores integers).
function Economy.incomePerSecond(starlings: { Starling }, rebirths: number, indexCount: number?): number
	local total = 0
	for _, starling in starlings do
		total += Economy.starlingIncome(starling)
	end
	return math.floor(total * Economy.multiplier(rebirths, indexCount))
end

--------------------------------------------------------------------------------------------------
-- Starling Index (collection)
--------------------------------------------------------------------------------------------------

Economy.INDEX_SIZE = Rarities.COUNT * 2

function Economy.indexKey(rarityId: number, shiny: boolean): string
	return `r{rarityId}{if shiny then "s" else ""}`
end

function Economy.indexCount(discovered: { [string]: boolean }): number
	local count = 0
	for _, found in discovered do
		if found then
			count += 1
		end
	end
	return count
end

function Economy.discoveryReward(rarityId: number, shiny: boolean): number
	local income = Economy.starlingIncome({ rarity = rarityId, shiny = shiny })
	return math.max(settings.MinDiscoveryReward, income * settings.DiscoveryRewardSeconds)
end

-- Income of a player's base, Index bonus included (use this everywhere income is shown or paid).
function Economy.baseIncome(data: EconomyData): number
	return Economy.incomePerSecond(data.starlings, data.rebirths, Economy.indexCount(data.discovered))
end

--------------------------------------------------------------------------------------------------
-- Daily reward
--------------------------------------------------------------------------------------------------

-- Returns (canClaim, secondsUntilClaimable).
function Economy.dailyStatus(lastClaim: number, now: number): (boolean, number)
	if lastClaim <= 0 then
		return true, 0
	end
	local wait = lastClaim + settings.DailyCooldownSeconds - now
	return wait <= 0, math.max(0, wait)
end

-- The streak day (1..DailyStreakLength) the next claim would be.
function Economy.nextDailyDay(lastClaim: number, streak: number, now: number): number
	if lastClaim <= 0 or now - lastClaim >= settings.DailyResetSeconds or streak >= settings.DailyStreakLength then
		return 1
	end
	return streak + 1
end

function Economy.dailyReward(day: number, incomePerSecond: number): number
	local bonus = if day == settings.DailyStreakLength then 3 else 1
	return math.floor((settings.DailyBaseReward + incomePerSecond * settings.DailyIncomeSeconds) * day * bonus)
end

-- Applies a daily claim (inside an update mutator). Errors when not claimable. Returns (day, coins).
function Economy.claimDaily(data: EconomyData, now: number): (number, number)
	local ok = Economy.dailyStatus(data.dailyLastClaim, now)
	if not ok then
		error("Economy: daily reward not ready")
	end
	local day = Economy.nextDailyDay(data.dailyLastClaim, data.dailyStreak, now)
	local coins = Economy.dailyReward(day, Economy.baseIncome(data))
	data.coins += coins
	data.dailyStreak = day
	data.dailyLastClaim = now
	return day, coins
end

function Economy.sellValue(starling: Starling, rebirths: number): number
	return math.floor(Economy.starlingIncome(starling) * settings.SellSeconds * Economy.multiplier(rebirths))
end

function Economy.offlineEarnings(incomePerSecond: number, elapsedSeconds: number): number
	if elapsedSeconds ~= elapsedSeconds or elapsedSeconds <= 0 or incomePerSecond <= 0 then
		return 0
	end
	local seconds = math.min(elapsedSeconds, settings.OfflineCapSeconds)
	return math.floor(seconds * incomePerSecond * settings.OfflineRate)
end

--[[
	Puts `incoming` in the base:
	  - free pedestal          -> "placed"
	  - full, incoming better  -> "replaced": the weakest Starling is sold
	  - full, incoming weaker  -> "sold": the incoming Starling is sold
	Never mutates `starlings`; returns a new list.
]]
function Economy.placeStarling(
	starlings: { Starling },
	slotCount: number,
	incoming: Starling,
	rebirths: number
): Placement
	local result = table.clone(starlings)
	if #result < slotCount then
		table.insert(result, { rarity = incoming.rarity, shiny = incoming.shiny })
		return { outcome = "placed", starlings = result, soldValue = 0, sold = nil }
	end

	local weakestIndex: number? = nil
	local weakestIncome = math.huge
	for index, starling in result do
		local income = Economy.starlingIncome(starling)
		if income < weakestIncome then
			weakestIncome = income
			weakestIndex = index
		end
	end

	if weakestIndex ~= nil and Economy.starlingIncome(incoming) > weakestIncome then
		local weakest = result[weakestIndex]
		result[weakestIndex] = { rarity = incoming.rarity, shiny = incoming.shiny }
		return {
			outcome = "replaced",
			starlings = result,
			soldValue = Economy.sellValue(weakest, rebirths),
			sold = weakest,
		}
	end

	return {
		outcome = "sold",
		starlings = result,
		soldValue = Economy.sellValue(incoming, rebirths),
		sold = incoming,
	}
end

--------------------------------------------------------------------------------------------------
-- Experience
--------------------------------------------------------------------------------------------------

function Economy.xpForDelivery(rarityId: number, shiny: boolean): number
	local xp = Rarities.get(rarityId).xp
	return if shiny then xp * 2 else xp
end

-- XP needed to go from `level` to `level + 1`.
function Economy.xpToNextLevel(level: number): number
	return math.floor(settings.XpBase * level ^ settings.XpExponent)
end

-- Returns (level, xpIntoLevel, xpNeededForNextLevel) for a total amount of XP.
function Economy.levelFromXp(totalXp: number): (number, number, number)
	local level = 1
	local remaining = math.max(0, math.floor(totalXp))
	local needed = Economy.xpToNextLevel(level)
	-- Bounded loop: level 10k needs more XP than a double can count exactly.
	while remaining >= needed and level < 10000 do
		remaining -= needed
		level += 1
		needed = Economy.xpToNextLevel(level)
	end
	return level, remaining, needed
end

--------------------------------------------------------------------------------------------------
-- Rebirth
--------------------------------------------------------------------------------------------------

function Economy.rebirthCost(rebirths: number): number
	return settings.RebirthBaseCost * (rebirths + 1)
end

function Economy.canRebirth(data: EconomyData): (boolean, string?)
	if data.zoneTier < Zones.COUNT then
		return false, `Unlock {Zones.get(Zones.COUNT).name} first`
	end
	local cost = Economy.rebirthCost(data.rebirths)
	if data.coins < cost then
		return false, "Not enough coins"
	end
	return true, nil
end

--------------------------------------------------------------------------------------------------
-- Purchases
--------------------------------------------------------------------------------------------------

-- Validates a purchase. Returns (ok, reasonIfNot, cost).
function Economy.canPurchase(data: EconomyData, kind: string, id: string?): (boolean, string?, number)
	if kind == "upgrade" then
		local upgrade = if id then Upgrades.get(id) else nil
		if upgrade == nil then
			return false, "Unknown upgrade", 0
		end
		local level = (data.upgrades :: any)[upgrade.id] :: number
		local cost = Economy.upgradeCost(upgrade.id, level)
		if cost == nil then
			return false, "Already maxed", 0
		end
		if data.coins < cost then
			return false, "Not enough coins", cost
		end
		return true, nil, cost
	elseif kind == "zone" then
		local zone = if id then Zones.byKey(id) else nil
		if zone == nil then
			return false, "Unknown zone", 0
		end
		if zone.tier <= data.zoneTier then
			return false, "Already unlocked", 0
		end
		if zone.tier ~= data.zoneTier + 1 then
			return false, `Unlock {Zones.get(data.zoneTier + 1).name} first`, zone.unlockCost
		end
		if data.coins < zone.unlockCost then
			return false, "Not enough coins", zone.unlockCost
		end
		return true, nil, zone.unlockCost
	elseif kind == "rebirth" then
		local cost = Economy.rebirthCost(data.rebirths)
		local ok, reason = Economy.canRebirth(data)
		return ok, reason, cost
	end
	return false, "Unknown purchase", 0
end

-- Resets progression and grants a permanent income multiplier. XP and stats are kept.
function Economy.applyRebirth(data: EconomyData)
	local ok, reason = Economy.canRebirth(data)
	if not ok then
		error(`Economy: cannot rebirth: {reason}`)
	end
	data.rebirths += 1
	data.coins = 0
	data.vault = 0
	data.zoneTier = 1
	data.upgrades = { speed = 0, carry = 0, magnet = 0, slots = 0 }
	data.starlings = {}
end

-- Mutates `data` (inside an update mutator). Errors if the purchase is not allowed.
function Economy.applyPurchase(data: EconomyData, kind: string, id: string?): number
	local ok, reason, cost = Economy.canPurchase(data, kind, id)
	if not ok then
		error(`Economy: purchase refused: {reason}`)
	end
	if kind == "upgrade" then
		data.coins -= cost
		local levels = data.upgrades :: any
		levels[id :: string] += 1
	elseif kind == "zone" then
		data.coins -= cost
		data.zoneTier = (Zones.byKey(id :: string) :: Zones.Zone).tier
	elseif kind == "rebirth" then
		Economy.applyRebirth(data)
	end
	return cost
end

--------------------------------------------------------------------------------------------------
-- Delivery
--------------------------------------------------------------------------------------------------

export type DeliveredShard = {
	rarity: number,
	shiny: boolean,
	isComet: boolean,
}

-- Applies a delivery of shards to `data` (inside an update mutator). Returns one Placement per shard.
function Economy.deliver(data: EconomyData, shards: { DeliveredShard }): { Placement }
	local placements = {}
	local slotCount = Economy.slots(data.upgrades.slots)
	for _, shard in shards do
		assert(Rarities.isValid(shard.rarity), "Economy: invalid shard rarity")
		local placement = Economy.placeStarling(
			data.starlings,
			slotCount,
			{ rarity = shard.rarity, shiny = shard.shiny },
			data.rebirths
		)
		data.starlings = placement.starlings
		data.coins += placement.soldValue
		local key = Economy.indexKey(shard.rarity, shard.shiny)
		if not data.discovered[key] then
			data.discovered[key] = true
			local reward = Economy.discoveryReward(shard.rarity, shard.shiny)
			data.coins += reward
			placement.discovered = true
			placement.discoveryReward = reward
		end
		data.xp += Economy.xpForDelivery(shard.rarity, shard.shiny)
		data.stats.shardsDelivered += 1
		if shard.isComet then
			data.stats.cometsCaught += 1
		end
		table.insert(placements, placement)
	end
	return placements
end

return table.freeze(Economy)
