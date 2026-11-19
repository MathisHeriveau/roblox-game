--!strict
--[[
	ShardRules — pure, server-authoritative decisions about shards and bumps.

	The services gather facts from the engine (positions, timers, data) and ask these functions.
	Every anti-exploit rule lives here so it is unit-tested: distance checks are done on the server,
	zone locks are enforced at pickup, deliveries must be physically plausible, and bumps can only
	target a valid nearby carrier chosen by the server (clients never name a target).
]]

export type ShardFacts = {
	tier: number,
	isComet: boolean,
	readyAt: number,
	held: boolean,
	blockedUserId: number?,
	blockedUntil: number,
}

export type PickerFacts = {
	userId: number,
	alive: boolean,
	loaded: boolean,
	carrying: number,
	capacity: number,
	zoneTier: number,
	distance: number,
	radius: number,
}

export type PickupRefusal = "Held" | "NotReady" | "Dead" | "NotLoaded" | "TooFar" | "Full" | "Blocked" | "Locked"

export type BumpCandidate = {
	userId: number,
	position: Vector3,
	alive: boolean,
	carrying: number,
	immuneUntil: number,
	inSafeZone: boolean,
}

-- Deliveries faster than distance / (maxSpeed * SPEED_TOLERANCE) - SLACK are treated as teleports.
local SPEED_TOLERANCE = 1.6
local SLACK_SECONDS = 1

local ShardRules = {}

function ShardRules.canPickup(shard: ShardFacts, picker: PickerFacts, now: number): (boolean, PickupRefusal?)
	if shard.held then
		return false, "Held"
	end
	if now < shard.readyAt then
		return false, "NotReady"
	end
	if not picker.alive then
		return false, "Dead"
	end
	if not picker.loaded then
		return false, "NotLoaded"
	end
	local distance = picker.distance
	if distance ~= distance or distance < 0 or distance > picker.radius then
		return false, "TooFar"
	end
	if picker.carrying >= picker.capacity then
		return false, "Full"
	end
	if shard.blockedUserId == picker.userId and now < shard.blockedUntil then
		return false, "Blocked"
	end
	if not shard.isComet and shard.tier > picker.zoneTier then
		return false, "Locked"
	end
	return true, nil
end

-- True when travelling `distance` studs in `elapsed` seconds is possible at `maxSpeed` studs/s.
function ShardRules.deliveryPlausible(distance: number, elapsed: number, maxSpeed: number): boolean
	if distance ~= distance or elapsed ~= elapsed or maxSpeed <= 0 then
		return false
	end
	return elapsed + SLACK_SECONDS >= distance / (maxSpeed * SPEED_TOLERANCE)
end

function ShardRules.canBump(lastBumpAt: number?, now: number, cooldown: number, attackerAlive: boolean): boolean
	if not attackerAlive then
		return false
	end
	return lastBumpAt == nil or now - lastBumpAt >= cooldown
end

-- Picks the nearest valid target within range, or nil.
function ShardRules.bumpTarget(
	attackerUserId: number,
	attackerPosition: Vector3,
	candidates: { BumpCandidate },
	now: number,
	range: number
): number?
	local bestUserId: number? = nil
	local bestDistance = math.huge
	for _, candidate in candidates do
		if
			candidate.userId ~= attackerUserId
			and candidate.alive
			and candidate.carrying > 0
			and now >= candidate.immuneUntil
			and not candidate.inSafeZone
		then
			local distance = (candidate.position - attackerPosition).Magnitude
			if distance <= range and distance < bestDistance then
				bestDistance = distance
				bestUserId = candidate.userId
			end
		end
	end
	return bestUserId
end

return table.freeze(ShardRules)
