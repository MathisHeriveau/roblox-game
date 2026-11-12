--!strict
--[[
	CollectibleRules — pure decision logic for "may this player collect this item now?".

	The service gathers facts from the engine (character state, positions, clocks) and asks this
	module for a decision. Keeping the decision pure makes every anti-exploit rule unit-testable.
]]

export type Context = {
	itemActive: boolean,
	playerAlive: boolean,
	dataLoaded: boolean,
	-- Studs between the character root and the item, measured on the server.
	distance: number,
	maxDistance: number,
	now: number,
	lastPickupAt: number?,
	cooldownSeconds: number,
}

export type Reason = "Inactive" | "Dead" | "NotLoaded" | "TooFar" | "Cooldown" | "InvalidDistance"

local CollectibleRules = {}

function CollectibleRules.canCollect(context: Context): (boolean, Reason?)
	if not context.itemActive then
		return false, "Inactive"
	end
	if not context.playerAlive then
		return false, "Dead"
	end
	if not context.dataLoaded then
		-- Never grant rewards before the player's data is loaded: the grant could be lost or
		-- overwrite persisted progress.
		return false, "NotLoaded"
	end
	local distance = context.distance
	if distance ~= distance or distance < 0 then
		return false, "InvalidDistance"
	end
	if distance > context.maxDistance then
		return false, "TooFar"
	end
	local last = context.lastPickupAt
	if last ~= nil and context.now - last < context.cooldownSeconds then
		return false, "Cooldown"
	end
	return true, nil
end

return table.freeze(CollectibleRules)
