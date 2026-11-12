--!strict
--[[
	PlayerState — the client-visible snapshot of a player's progression.

	This is a deliberately small projection of the server-side PlayerData: the server decides
	what each client may see. Never send the raw persisted record to clients.
]]

export type PlayerState = {
	coins: number,
	collectiblesCollected: number,
}

-- ModuleScripts must return exactly one value; type-only modules return an empty frozen table.
return table.freeze({})
