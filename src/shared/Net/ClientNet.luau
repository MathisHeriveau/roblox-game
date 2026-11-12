--!strict
--[[
	ClientNet — the client side of the network layer.

	Clients never create remotes; they wait for the ones the server declared in Remotes.luau.
	Everything the client sends is untrusted by the server, so never send authoritative values
	(currency, damage, rewards, positions to trust) — send *intents* and let the server decide.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(script.Parent.Remotes)

local WAIT_TIMEOUT_SECONDS = 30

local ClientNet = {}

local function getRemote(name: string): Instance
	assert(RunService:IsClient(), "ClientNet can only be used from the client")
	local definition = Remotes.Definitions[name]
	assert(definition ~= nil, `ClientNet: unknown remote "{name}"`)

	local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName, WAIT_TIMEOUT_SECONDS)
	assert(folder ~= nil, "ClientNet: Remotes folder not found (did the server boot?)")
	local remote = folder:WaitForChild(name, WAIT_TIMEOUT_SECONDS)
	assert(remote ~= nil, `ClientNet: remote "{name}" not found`)
	return remote
end

-- RemoteEvent and UnreliableRemoteEvent expose the same API; treat both as RemoteEvent.
local function asEvent(name: string, remote: Instance): RemoteEvent
	if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
		return remote :: any
	end
	error(`ClientNet: "{name}" is not an event`)
end

function ClientNet.onEvent(name: string, handler: (...any) -> ()): RBXScriptConnection
	local definition = Remotes.Definitions[name]
	assert(definition and definition.direction == "ServerToClient", `ClientNet: "{name}" is not a ServerToClient event`)
	return asEvent(name, getRemote(name)).OnClientEvent:Connect(handler)
end

function ClientNet.fireServer(name: string, ...: any)
	local definition = Remotes.Definitions[name]
	assert(definition and definition.direction == "ClientToServer", `ClientNet: "{name}" is not a ClientToServer event`)
	asEvent(name, getRemote(name)):FireServer(...)
end

-- Returns (true, ...results) or (false, errorMessage). Never throws.
function ClientNet.invoke(name: string, ...: any): (boolean, ...any)
	local definition = Remotes.Definitions[name]
	assert(definition and definition.kind == "Function", `ClientNet: "{name}" is not a RemoteFunction`)
	local remote = getRemote(name)
	assert(remote:IsA("RemoteFunction"), `ClientNet: "{name}" is not a RemoteFunction`)
	return pcall(remote.InvokeServer, remote, ...)
end

return table.freeze(ClientNet)
