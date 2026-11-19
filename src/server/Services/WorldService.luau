--!strict
--[[
	WorldService — the Comet Raiders atmosphere: violet dusk sky full of stars, glow (bloom) for
	the neon shards and Starlings, and quick respawns when falling off the floating island.

	Also removes leftovers of Studio place templates at runtime (the template "Baseplate" would
	otherwise cover the void under the island). Never touches the saved place.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Log = require(ReplicatedStorage.Shared.Utils.Log)

local log = Log.scope("WorldService")

local WorldService = {
	name = "WorldService",
}

local function findOrCreate(className: string, parent: Instance): Instance
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Parent = parent
	return created
end

local function removeTemplateLeftovers()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
		log:info("removed template Baseplate")
	end
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
			log:info("removed template SpawnLocation")
		end
	end
end

function WorldService.init(_self: any)
	local world = GameConfig.World
	removeTemplateLeftovers()

	Lighting.ClockTime = world.ClockTime
	Lighting.Brightness = world.Brightness
	Lighting.Ambient = world.Ambient
	Lighting.OutdoorAmbient = world.OutdoorAmbient
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true

	local atmosphere = findOrCreate("Atmosphere", Lighting) :: Atmosphere
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.12
	atmosphere.Color = world.AtmosphereColor
	atmosphere.Decay = world.AtmosphereDecay
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.4

	local sky = findOrCreate("Sky", Lighting) :: Sky
	sky.StarCount = world.StarCount
	sky.CelestialBodiesShown = true
	sky.MoonAngularSize = 14

	local bloom = findOrCreate("BloomEffect", Lighting) :: BloomEffect
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.3

	local grading = findOrCreate("ColorCorrectionEffect", Lighting) :: ColorCorrectionEffect
	grading.Saturation = 0.18
	grading.Contrast = 0.06
	grading.Brightness = 0.02
	grading.TintColor = Color3.fromRGB(255, 246, 255)

	Workspace.FallenPartsDestroyHeight = world.FallenPartsDestroyHeight
	-- Jump pad trajectories are computed for this gravity (GameConfig.Map.Gravity).
	Workspace.Gravity = GameConfig.Map.Gravity
end

function WorldService.start(_self: any)
	-- Static world settings: nothing to run.
end

return WorldService
