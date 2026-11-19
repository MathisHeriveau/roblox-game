--!strict
--[[
	RaidRules — pure decisions for base raids (stealing Starlings) and base locks.

	Services gather facts from the engine and data; these functions decide. Every rule that keeps
	raids fair (no stealing from locked bases, beginners, yourself, or while busy) lives here.
]]

export type StealFacts = {
	thiefUserId: number,
	ownerUserId: number,
	thiefAlive: boolean,
	thiefLoaded: boolean,
	thiefCarryingShards: number,
	thiefCarryingStarling: boolean,
	baseLocked: boolean,
	victimStarlings: number,
	minVictimStarlings: number,
	pedestalOccupied: boolean,
	pedestalInTransit: boolean,
	distance: number,
	maxDistance: number,
}

export type StealRefusal =
	"OwnBase"
	| "Dead"
	| "NotLoaded"
	| "Busy"
	| "Locked"
	| "Protected"
	| "Empty"
	| "InTransit"
	| "TooFar"

local RaidRules = {}

function RaidRules.canSteal(facts: StealFacts): (boolean, StealRefusal?)
	if facts.thiefUserId == facts.ownerUserId then
		return false, "OwnBase"
	end
	if not facts.thiefAlive then
		return false, "Dead"
	end
	if not facts.thiefLoaded then
		return false, "NotLoaded"
	end
	if facts.thiefCarryingShards > 0 or facts.thiefCarryingStarling then
		return false, "Busy"
	end
	if facts.baseLocked then
		return false, "Locked"
	end
	if facts.victimStarlings < facts.minVictimStarlings then
		return false, "Protected"
	end
	if not facts.pedestalOccupied then
		return false, "Empty"
	end
	if facts.pedestalInTransit then
		return false, "InTransit"
	end
	local distance = facts.distance
	if distance ~= distance or distance < 0 or distance > facts.maxDistance then
		return false, "TooFar"
	end
	return true, nil
end

-- A lock can be (re)activated by the owner only, once the previous one has expired.
function RaidRules.canLock(isOwner: boolean, lockedUntil: number, now: number): boolean
	return isOwner and now >= lockedUntil
end

function RaidRules.isLocked(lockedUntil: number, now: number): boolean
	return now < lockedUntil
end

-- Index of the first Starling matching the stolen one, or nil (sold, replaced or rebirthed away).
function RaidRules.findStarling(
	starlings: { { rarity: number, shiny: boolean } },
	rarity: number,
	shiny: boolean
): number?
	for index, starling in starlings do
		if starling.rarity == rarity and starling.shiny == shiny then
			return index
		end
	end
	return nil
end

return table.freeze(RaidRules)
