--!strict
--[[
	ShardBuilder — star shard models: a glowing gem (cube balanced on a vertex) plus a tall light
	beacon visible from across the island. Comet cores are bigger and burn.

	Models are tagged "Shard" (crystals "ShardCrystal") so clients can spin them and badge locked
	ones. Everything is anchored and non-colliding: the server detects pickups by distance.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local ShardVisuals = require(ReplicatedStorage.Shared.Game.ShardVisuals)

export type ShardParts = {
	model: Model,
	crystal: BasePart,
	beacon: BasePart,
}

local BEACON_HEIGHT = 90
local BEACON_TRANSPARENCY = 0.62

local ShardBuilder = {}

ShardBuilder.TAG = ShardVisuals.SHARD_TAG
ShardBuilder.CRYSTAL_TAG = ShardVisuals.CRYSTAL_TAG
ShardBuilder.TILT = ShardVisuals.TILT

local function crystalSize(isComet: boolean): number
	return if isComet then 3 else 1.7
end

function ShardBuilder.crystalCFrame(position: Vector3, isComet: boolean): CFrame
	return CFrame.new(position + Vector3.new(0, crystalSize(isComet) * 1.1, 0)) * ShardBuilder.TILT
end

function ShardBuilder.beaconCFrame(position: Vector3): CFrame
	return CFrame.new(position + Vector3.new(0, BEACON_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

function ShardBuilder.build(rarityId: number, shiny: boolean, isComet: boolean, position: Vector3): ShardParts
	local rarity = Rarities.get(rarityId)
	local size = crystalSize(isComet)

	local model = Instance.new("Model")
	model.Name = if isComet then "CometCore" else `{rarity.key}Shard`
	model:SetAttribute("Rarity", rarityId)
	model:SetAttribute("Shiny", shiny)
	model:SetAttribute("IsComet", isComet)

	local crystal = Instance.new("Part")
	crystal.Name = "Crystal"
	crystal.Size = Vector3.new(size, size, size)
	crystal.CFrame = ShardBuilder.crystalCFrame(position, isComet)
	crystal.Anchored = true
	crystal.CanCollide = false
	crystal.CanTouch = false
	crystal.CanQuery = false
	crystal.Material = Enum.Material.Neon
	crystal.Color = rarity.color
	crystal:AddTag(ShardBuilder.CRYSTAL_TAG)
	crystal.Parent = model

	local light = Instance.new("PointLight")
	light.Color = rarity.color
	light.Range = if isComet then 24 else 14
	light.Brightness = 2.4
	light.Parent = crystal

	local particles = Instance.new("ParticleEmitter")
	particles.Rate = if isComet then 18 else 6
	particles.Lifetime = NumberRange.new(0.8, 1.4)
	particles.Speed = NumberRange.new(1, 2.5)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.LightEmission = 1
	particles.Size = NumberSequence.new(if isComet then 0.6 else 0.35, 0)
	particles.Color = ColorSequence.new(rarity.color)
	particles.Parent = crystal

	if shiny then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = rarity.color
		sparkles.Parent = crystal
	end
	if isComet then
		local fire = Instance.new("Fire")
		fire.Size = 6
		fire.Heat = 6
		fire.Color = rarity.color
		fire.SecondaryColor = Color3.new(1, 1, 1)
		fire.Parent = crystal
	end

	local beacon = Instance.new("Part")
	beacon.Name = "Beacon"
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Size = Vector3.new(BEACON_HEIGHT, if isComet then 2.4 else 0.9, if isComet then 2.4 else 0.9)
	beacon.CFrame = ShardBuilder.beaconCFrame(position)
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanTouch = false
	beacon.CanQuery = false
	beacon.CastShadow = false
	beacon.Material = Enum.Material.Neon
	beacon.Color = rarity.color
	beacon.Transparency = BEACON_TRANSPARENCY
	beacon.Parent = model

	model.PrimaryPart = crystal
	-- Stream the whole shard at once (clients animate the crystal by tag).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:AddTag(ShardBuilder.TAG)
	return { model = model, crystal = crystal, beacon = beacon }
end

-- Hides/shows the whole shard (used while the meteor is still falling).
function ShardBuilder.setVisible(parts: ShardParts, visible: boolean)
	parts.crystal.Transparency = if visible then 0 else 1
	parts.beacon.Transparency = if visible then BEACON_TRANSPARENCY else 1
	for _, child in parts.crystal:GetChildren() do
		if child:IsA("PointLight") or child:IsA("ParticleEmitter") or child:IsA("Sparkles") or child:IsA("Fire") then
			-- Every effect class above has an `Enabled` property.
			(child :: any).Enabled = visible
		end
	end
end

-- Moves an anchored shard to rest on the ground at `position`.
function ShardBuilder.placeAt(parts: ShardParts, position: Vector3)
	local isComet = parts.model:GetAttribute("IsComet") == true
	parts.crystal.CFrame = ShardBuilder.crystalCFrame(position, isComet)
	parts.beacon.CFrame = ShardBuilder.beaconCFrame(position)
end

function ShardBuilder.setBeaconVisible(parts: ShardParts, visible: boolean)
	parts.beacon.Transparency = if visible then BEACON_TRANSPARENCY else 1
end

return table.freeze(ShardBuilder)
