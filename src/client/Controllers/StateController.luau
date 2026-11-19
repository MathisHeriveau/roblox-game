--!strict
--[[
	StateController — the client's copy of its PlayerState, fed by the server.

	Other controllers read `StateController.get()` and subscribe to `StateController.changed`
	(connect in init: the signal exists before any controller starts).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientNet = require(ReplicatedStorage.Shared.Net.ClientNet)
local Log = require(ReplicatedStorage.Shared.Utils.Log)
local PlayerStateTypes = require(ReplicatedStorage.Shared.Types.PlayerState)
local Signal = require(ReplicatedStorage.Shared.Utils.Signal)

type PlayerState = PlayerStateTypes.PlayerState

local log = Log.scope("StateController")

local StateController = {
	name = "StateController",
	changed = Signal.new() :: Signal.Signal<PlayerState>,
}

local current: PlayerState? = nil

local function accept(value: unknown)
	-- Even server payloads are validated before use.
	if not PlayerStateTypes.isPlayerState(value) then
		return
	end
	local state = value :: PlayerState
	current = state
	StateController.changed:fire(state)
end

function StateController.get(): PlayerState?
	return current
end

function StateController.init(_self: any)
	-- Subscriptions happen in start(): remotes may not exist yet.
end

function StateController.start(_self: any)
	ClientNet.onEvent("PlayerStateChanged", accept)
	local ok, state = ClientNet.invoke("GetPlayerState")
	if ok then
		accept(state)
	else
		log:warn(`initial state request failed: {state}`)
	end
end

return StateController
