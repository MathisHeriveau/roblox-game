--!strict
--[[
	Client entry point. The ONLY LocalScript: controllers are ModuleScripts booted here.
	Order matters: a controller may only depend on controllers listed before it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lifecycle = require(ReplicatedStorage.Shared.Utils.Lifecycle)
local Controllers = script.Controllers

Lifecycle.boot({
	require(Controllers.StateController),
	require(Controllers.NotificationController),
	require(Controllers.ShopController),
	require(Controllers.HudController),
	require(Controllers.BaseController),
	require(Controllers.SkyEventController),
	require(Controllers.InputController),
	require(Controllers.JumpPadController),
	require(Controllers.AmbientController),
})
