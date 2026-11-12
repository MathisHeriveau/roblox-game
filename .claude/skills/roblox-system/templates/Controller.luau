--!strict
--[[
	ExampleController — <one sentence: what this controller presents or handles on the client>.

	Client-side only. Displays server state and sends *intents*; never computes authoritative values.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cleaner = require(ReplicatedStorage.Shared.Utils.Cleaner)
local ClientNet = require(ReplicatedStorage.Shared.Net.ClientNet)
local Log = require(ReplicatedStorage.Shared.Utils.Log)

local log = Log.scope("ExampleController")

local ExampleController = {
	name = "ExampleController",
}

local cleaner = Cleaner.new()

function ExampleController.init(_self: any)
	-- Build UI/state without yielding (no WaitForChild here).
end

function ExampleController.start(_self: any)
	local _playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	cleaner:add(ClientNet.onEvent("SomeServerToClientEvent", function(payload: unknown)
		if type(payload) ~= "table" then
			log:warn("ignored malformed payload")
			return
		end
		-- render payload
	end))
end

return ExampleController
