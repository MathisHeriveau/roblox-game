--!strict
--[[
	PlayerState — the client-visible snapshot of a player's progression.

	A projection of server-side PlayerData plus runtime facts (shards carried). The server decides
	what each client may see; never send the raw persisted record to clients.
]]

export type PlayerState = {
	coins: number,
	vault: number,
	incomePerSecond: number,
	xp: number,
	level: number,
	levelProgress: number,
	levelGoal: number,
	rebirths: number,
	multiplier: number,
	rebirthCost: number,
	zoneTier: number,
	upgrades: {
		speed: number,
		carry: number,
		magnet: number,
		slots: number,
	},
	carrying: number,
	capacity: number,
	-- Rarity id of the Starling this player is stealing right now, 0 if none.
	carryingStarling: number,
	starlings: number,
	slots: number,
	shardsDelivered: number,
	bumpsLanded: number,
	cometsCaught: number,
}

local PlayerStateTypes = {}

local NUMBER_FIELDS = {
	"coins",
	"vault",
	"incomePerSecond",
	"xp",
	"level",
	"levelProgress",
	"levelGoal",
	"rebirths",
	"multiplier",
	"rebirthCost",
	"zoneTier",
	"carrying",
	"capacity",
	"starlings",
	"slots",
}

-- Shape check for payloads received over the network (the client treats them as untrusted).
function PlayerStateTypes.isPlayerState(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local state = value :: any
	for _, field in NUMBER_FIELDS do
		local n = state[field]
		if type(n) ~= "number" or n ~= n then
			return false
		end
	end
	return type(state.upgrades) == "table"
end

return table.freeze(PlayerStateTypes)
