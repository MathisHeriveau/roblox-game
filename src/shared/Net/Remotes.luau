--!strict
--[[
	Remotes — single source of truth for every client/server network channel.

	Adding a channel:
	  1. Declare it here (name, kind, direction) and document its payload.
	  2. Server: register a validated handler with ServerNet.onEvent/onInvoke (ClientToServer)
	     or send with ServerNet.fireClient/fireAllClients (ServerToClient).
	  3. Client: use ClientNet.

	Instances are created by the server at boot (ServerNet.setup) under
	ReplicatedStorage.<FolderName>. Clients only ever *wait* for them.
]]

export type Kind = "Event" | "UnreliableEvent" | "Function"
export type Direction = "ServerToClient" | "ClientToServer"

export type Definition = {
	kind: Kind,
	direction: Direction,
}

local definitions: { [string]: Definition } = {
	-- Server -> client. Payload: (state: PlayerState). Sent when the player's state changes.
	PlayerStateChanged = table.freeze({ kind = "Event", direction = "ServerToClient" } :: Definition),

	-- Client -> server. Args: none. Returns: (PlayerState?) — nil while data is still loading.
	GetPlayerState = table.freeze({ kind = "Function", direction = "ClientToServer" } :: Definition),
}

local Remotes = {
	FolderName = "Remotes",
	Definitions = table.freeze(definitions),
}

return table.freeze(Remotes)
