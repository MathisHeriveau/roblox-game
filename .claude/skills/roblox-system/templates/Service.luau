--!strict
--[[
	ExampleService — <one sentence: what this service owns>.

	Public API (server only):
	  ExampleService.doSomething(player: Player, ...): boolean

	Owns: <state, instances, remotes>. Depends on: <services listed before it in boot order>.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Cleaner = require(ReplicatedStorage.Shared.Utils.Cleaner)
local Log = require(ReplicatedStorage.Shared.Utils.Log)
local Server = ServerScriptService.Server
local PlayerDataService = require(Server.Services.PlayerDataService)
-- local ExampleRules = require(Server.Systems.Example.ExampleRules) -- pure decisions live here

local log = Log.scope("ExampleService")

local ExampleService = {
	name = "ExampleService",
}

local cleaner = Cleaner.new()
local perPlayer: { [Player]: { lastActionAt: number } } = {}

function ExampleService.init(_self: any)
	-- Synchronous setup only: state, ServerNet handlers, Instances. Never yield here.
end

function ExampleService.start(_self: any)
	cleaner:add(Players.PlayerRemoving:Connect(function(player: Player)
		perPlayer[player] = nil -- per-player state must not outlive the player
	end))
end

function ExampleService.doSomething(player: Player): boolean
	if not PlayerDataService.isLoaded(player) then
		return false
	end
	-- 1. Gather facts from the engine (server-side, never from client arguments).
	-- 2. Ask pure logic for a decision.
	-- 3. Apply through PlayerDataService.update / Instances.
	log:debug("doSomething", player.UserId)
	return true
end

return ExampleService
