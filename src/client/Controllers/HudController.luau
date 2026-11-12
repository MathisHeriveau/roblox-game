--!strict
--[[
	HudController — builds the HUD and keeps it in sync with the server's PlayerState.

	Display only: the client renders what the server sends and never computes authoritative
	values. Initial sync uses GetPlayerState; later updates arrive via PlayerStateChanged.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cleaner = require(ReplicatedStorage.Shared.Utils.Cleaner)
local ClientNet = require(ReplicatedStorage.Shared.Net.ClientNet)
local CoinCounter = require(script.Parent.Parent.UI.Components.CoinCounter)
local Create = require(script.Parent.Parent.UI.Create)
local Log = require(ReplicatedStorage.Shared.Utils.Log)
local PlayerStateTypes = require(ReplicatedStorage.Shared.Types.PlayerState)

type PlayerState = PlayerStateTypes.PlayerState

local log = Log.scope("HudController")

local HudController = {
	name = "HudController",
}

local cleaner = Cleaner.new()
local counter: CoinCounter.CoinCounter? = nil

-- The payload comes from the network: treat it as untrusted even from the server.
local function isPlayerState(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local state = value :: any
	return type(state.coins) == "number" and type(state.collectiblesCollected) == "number"
end

local function render(state: unknown)
	if counter == nil or not isPlayerState(state) then
		return
	end
	local valid = state :: PlayerState
	counter.setState(valid.coins, valid.collectiblesCollected)
end

local screenGui: ScreenGui? = nil

function HudController.init(_self: any)
	-- Build only; parenting may yield (WaitForChild) so it happens in start().
	local created = CoinCounter.new()
	counter = created
	screenGui = cleaner:add(Create("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	}, { created.root }) :: ScreenGui)
end

function HudController.start(_self: any)
	local gui = screenGui
	assert(gui ~= nil, "HudController.start called before init")
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	cleaner:add(ClientNet.onEvent("PlayerStateChanged", render))

	local ok, state = ClientNet.invoke("GetPlayerState")
	if ok then
		render(state)
	else
		log:warn(`initial state request failed: {state}`)
	end
end

return HudController
