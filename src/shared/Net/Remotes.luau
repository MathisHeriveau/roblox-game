--!strict
--[[
	Remotes — single source of truth for every client/server network channel.

	Adding a channel:
	  1. Declare it here (name, kind, direction) and document its payload.
	  2. Server: register a validated handler with ServerNet.onEvent/onInvoke (ClientToServer)
	     or send with ServerNet.fireClient/fireAllClients (ServerToClient).
	  3. Client: use ClientNet.

	Instances are created by the server (ServerNet) under ReplicatedStorage.<FolderName>.
	Clients only ever *wait* for them.
]]

export type Kind = "Event" | "UnreliableEvent" | "Function"
export type Direction = "ServerToClient" | "ClientToServer"

export type Definition = {
	kind: Kind,
	direction: Direction,
}

local definitions: { [string]: Definition } = {
	-- Server -> client. Payload: (state: PlayerState). Coalesced to a few pushes per second.
	PlayerStateChanged = table.freeze({ kind = "Event", direction = "ServerToClient" } :: Definition),

	-- Client -> server. Args: none. Returns: (PlayerState?) — nil while data is still loading.
	GetPlayerState = table.freeze({ kind = "Function", direction = "ClientToServer" } :: Definition),

	-- Client -> server. Args: (kind: "upgrade" | "zone" | "rebirth", id: string?).
	-- Returns: ({ ok: boolean, message: string }). Prices are computed by the server only.
	RequestPurchase = table.freeze({ kind = "Function", direction = "ClientToServer" } :: Definition),

	-- Client -> server. Args: none. The server picks the target (nearest valid carrier in range).
	RequestBump = table.freeze({ kind = "Event", direction = "ClientToServer" } :: Definition),

	-- Server -> client. Payload: ({ text: string, style: string, rarity: number? }).
	Notify = table.freeze({ kind = "Event", direction = "ServerToClient" } :: Definition),

	-- Server -> client. Payload: ({ kind: "meteors" | "cometWarning" | "cometImpact" | "bump", ... }).
	-- Cosmetic triggers for VFX/SFX/banners; gameplay never depends on receiving them.
	WorldEvent = table.freeze({ kind = "Event", direction = "ServerToClient" } :: Definition),

	-- Server -> one client. Payload: (direction: Vector3). The bumped player's client applies it.
	Knockback = table.freeze({ kind = "Event", direction = "ServerToClient" } :: Definition),
}

local Remotes = {
	FolderName = "Remotes",
	Definitions = table.freeze(definitions),
}

return table.freeze(Remotes)
