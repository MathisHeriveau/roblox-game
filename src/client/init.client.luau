--!strict
--[[
	Client entry point. The ONLY LocalScript: controllers are ModuleScripts booted here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lifecycle = require(ReplicatedStorage.Shared.Utils.Lifecycle)
local Controllers = script.Controllers

Lifecycle.boot({
	require(Controllers.HudController),
})
