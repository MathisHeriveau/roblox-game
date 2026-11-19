--!strict
--[[
	HazardService — environmental danger: lava pools in the Lava Fields burn characters standing
	in them. Position-based (tile lookup) instead of Touched events: cheap, deterministic, no
	per-part connections.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Server = ServerScriptService.Server
local MapService = require(Server.Services.MapService)
local ServerConfig = require(Server.ServerConfig)

local HazardService = {
	name = "HazardService",
}

local function tick(dt: number)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			local tile = MapService.tileAt(root.Position)
			if tile and tile.kind == "lava" and root.Position.Y < tile.height + 5 then
				humanoid:TakeDamage(GameConfig.Hazards.LavaDamagePerSecond * dt)
			end
		end
	end
end

function HazardService.init(_self: any)
	-- Nothing to prepare: lava tiles come from the map layout.
end

function HazardService.start(_self: any)
	local interval = ServerConfig.Gameplay.HazardTickSeconds
	while true do
		local dt = task.wait(interval)
		tick(dt)
	end
end

return HazardService
