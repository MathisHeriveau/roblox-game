--!strict
--[[
	HazardService — environmental danger: lava pools in the Lava Fields burn characters standing
	in them, and characters that fall off the floating island die (and respawn) once they drop
	below GameConfig.Hazards.VoidKillHeight. Position-based (tile lookup) instead of Touched
	events: cheap, deterministic, no per-part connections. Decisions live in HazardRules.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Server = ServerScriptService.Server
local HazardRules = require(Server.Systems.Hazards.HazardRules)
local MapService = require(Server.Services.MapService)
local ServerConfig = require(Server.ServerConfig)

local HazardService = {
	name = "HazardService",
}

local function tick(dt: number)
	local hazards = GameConfig.Hazards
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			local position = root.Position
			local hazard = HazardRules.classify(position.Y, MapService.tileAt(position), hazards.VoidKillHeight)
			if hazard == "void" then
				-- Health = 0 rather than TakeDamage: a spawn ForceField must not save a falling player.
				humanoid.Health = 0
			elseif hazard == "lava" then
				humanoid:TakeDamage(hazards.LavaDamagePerSecond * dt)
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
