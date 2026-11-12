--!strict
--[[
	Server entry point. The ONLY server Script: everything else is a ModuleScript booted here.

	Boot order matters: a service may only depend on services listed before it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lifecycle = require(ReplicatedStorage.Shared.Utils.Lifecycle)
local Services = script.Services

Lifecycle.boot({
	require(Services.PlayerDataService),
	require(Services.PlayerStateService),
	require(Services.MapService),
	require(Services.CollectibleService),
})
