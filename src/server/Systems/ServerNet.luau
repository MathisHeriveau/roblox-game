--!strict
--[[
	ServerNet — the server side of the network layer. Every inbound remote goes through here.

	Inbound pipeline for each request (in this order):
	  1. Direction check   — the channel must be declared ClientToServer in Remotes.luau.
	  2. Rate limit        — token bucket per player per channel; excess requests are dropped.
	  3. Validation        — Guard tuple check on the raw arguments (arity, types, ranges).
	  4. Handler           — runs with validated arguments; errors are caught and logged.

	Clients receive no error details (avoid leaking server internals).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guard = require(ReplicatedStorage.Shared.Utils.Guard)
local Log = require(ReplicatedStorage.Shared.Utils.Log)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

export type InboundOptions = {
	validate: Guard.TupleCheck,
	rateLimit: RateLimiter.Options,
}

local log = Log.scope("ServerNet")

local ServerNet = {}

local folder: Folder? = nil
local remotes: { [string]: Instance } = {}
local limiters: { RateLimiter.RateLimiter } = {}
local handled: { [string]: boolean } = {}

local CLASS_BY_KIND: { [Remotes.Kind]: string } = {
	Event = "RemoteEvent",
	UnreliableEvent = "UnreliableRemoteEvent",
	Function = "RemoteFunction",
}

-- Creates the Remotes folder and every declared remote. Idempotent.
function ServerNet.setup()
	if folder then
		return
	end
	local container = Instance.new("Folder")
	container.Name = Remotes.FolderName

	for name, definition in Remotes.Definitions do
		local remote = Instance.new(CLASS_BY_KIND[definition.kind])
		remote.Name = name
		remote.Parent = container
		remotes[name] = remote
	end

	-- Parent last so clients never observe a half-built folder.
	container.Parent = ReplicatedStorage
	folder = container

	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:remove(player)
		end
	end)
end

local function getRemote(name: string, expectedDirection: Remotes.Direction): Instance
	assert(folder ~= nil, "ServerNet.setup() must be called before using remotes")
	local definition = Remotes.Definitions[name]
	assert(definition ~= nil, `ServerNet: unknown remote "{name}"`)
	assert(
		definition.direction == expectedDirection,
		`ServerNet: "{name}" is declared {definition.direction}, not {expectedDirection}`
	)
	return remotes[name]
end

-- RemoteEvent and UnreliableRemoteEvent expose the same API; treat both as RemoteEvent.
local function asEvent(name: string, remote: Instance): RemoteEvent
	if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
		return remote :: any
	end
	error(`ServerNet: "{name}" is not an event`)
end

local function makeGate(name: string, options: InboundOptions)
	local limiter = RateLimiter.new(options.rateLimit)
	table.insert(limiters, limiter)
	local validate = options.validate

	return function(player: Player, args: { unknown }, count: number): boolean
		if not limiter:tryConsume(player) then
			log:debug(`rate limited {name} for {player.UserId}`)
			return false
		end
		local ok, err = validate(args, count)
		if not ok then
			log:warn(`rejected {name} from {player.UserId}: {err}`)
			return false
		end
		return true
	end
end

function ServerNet.onEvent(name: string, options: InboundOptions, handler: (player: Player, ...any) -> ())
	assert(not handled[name], `ServerNet: "{name}" already has a handler`)
	handled[name] = true
	local remote = getRemote(name, "ClientToServer")
	local gate = makeGate(name, options)

	local function onServerEvent(player: Player, ...: any)
		local count = select("#", ...)
		local args = { ... }
		if not gate(player, args, count) then
			return
		end
		local ok, err = pcall(handler :: any, player, ...)
		if not ok then
			log:error(`handler for {name} failed: {err}`)
		end
	end

	asEvent(name, remote).OnServerEvent:Connect(onServerEvent)
end

function ServerNet.onInvoke(name: string, options: InboundOptions, handler: (player: Player, ...any) -> ...any)
	assert(not handled[name], `ServerNet: "{name}" already has a handler`)
	handled[name] = true
	local remote = getRemote(name, "ClientToServer")
	assert(remote:IsA("RemoteFunction"), `ServerNet: "{name}" is not a RemoteFunction`)
	local gate = makeGate(name, options)

	remote.OnServerInvoke = function(player: Player, ...: any): ...any
		local count = select("#", ...)
		local args = { ... }
		if not gate(player, args, count) then
			return nil
		end
		local results = table.pack(pcall(handler, player, ...))
		if not results[1] then
			log:error(`handler for {name} failed: {results[2]}`)
			return nil
		end
		return table.unpack(results, 2, results.n)
	end
end

function ServerNet.fireClient(name: string, player: Player, ...: any)
	asEvent(name, getRemote(name, "ServerToClient")):FireClient(player, ...)
end

function ServerNet.fireAllClients(name: string, ...: any)
	asEvent(name, getRemote(name, "ServerToClient")):FireAllClients(...)
end

return table.freeze(ServerNet)
