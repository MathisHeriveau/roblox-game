--!strict
--[[
	Server entry point. The ONLY server Script: everything else is a ModuleScript booted here.

	Boot order matters: a service may only depend on services listed before it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lifecycle = require(ReplicatedStorage.Shared.Utils.Lifecycle)
local Services = script.Services

Lifecycle.boot({
	require(Services.WorldService),
	require(Services.PlayerDataService),
	require(Services.MapService),
	require(Services.BaseService),
	require(Services.ShardService),
	require(Services.SkyEventService),
	require(Services.ShopService),
	require(Services.CharacterService),
	require(Services.BumpService),
	require(Services.HazardService),
	require(Services.LeaderstatsService),
	require(Services.PlayerStateService),
})
