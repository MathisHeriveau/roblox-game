--!strict
--[[
	ShardBuilder — star shard models from the art style sheet: a faceted crystal (glass shell
	around a glowing neon core, pointed caps) plus a tall light beacon visible across the island.

	  Legendary  golden crown ring under the tip    Mythic  orbiting ring of light beads
	  Cosmic     a second crossing crystal          Rare/Epic  a small satellite crystal
	  Comet core bigger and burning

	All gem parts are welded to `crystal` (the shell, PrimaryPart) so the shard moves as one piece
	when carried. Anchoring, placement and visibility go through this module (setAnchored,
	placeAt, setVisible). Clients spin anchored shards via their model pivot.
	Preview the result with `make preview-models`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local ShardVisuals = require(ReplicatedStorage.Shared.Game.ShardVisuals)

export type ShardParts = {
	model: Model,
	crystal: BasePart,
	beacon: BasePart,
	-- Every part of the gem itself (crystal included, beacon excluded).
	gems: { BasePart },
}

local BEACON_HEIGHT = 90
local BEACON_TRANSPARENCY = 0.62
local SHELL_TRANSPARENCY = 0.18
local GOLD = Color3.fromRGB(255, 200, 48)

local ShardBuilder = {}

ShardBuilder.TAG = ShardVisuals.SHARD_TAG
ShardBuilder.CRYSTAL_TAG = ShardVisuals.CRYSTAL_TAG
-- Resting orientation of the crystal (square prism turned 45°, facets towards the viewer).
ShardBuilder.TILT = ShardVisuals.TILT

local function scaleOf(isComet: boolean): number
	return if isComet then 1.7 else 1
end

function ShardBuilder.crystalCFrame(position: Vector3, isComet: boolean): CFrame
	return CFrame.new(position + Vector3.new(0, 1.7 * scaleOf(isComet), 0)) * ShardBuilder.TILT
end

function ShardBuilder.beaconCFrame(position: Vector3): CFrame
	return CFrame.new(position + Vector3.new(0, BEACON_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

local function gemPart(model: Model, gems: { BasePart }, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part:SetAttribute("BaseTransparency", part.Transparency)
	part.Parent = model
	table.insert(gems, part)
	return part
end

-- One crystal: square prism (facets) with pointed caps and a neon core, around `origin`.
local function crystalBody(
	model: Model,
	gems: { BasePart },
	origin: CFrame,
	s: number,
	color: Color3,
	primary: boolean
): Part
	local shell = gemPart(model, gems, {
		Name = if primary then "Crystal" else "Facet",
		Size = Vector3.new(0.9 * s, 1.7 * s, 0.9 * s),
		CFrame = origin,
		Color = color,
		Material = Enum.Material.Glass,
		Reflectance = 0.15,
		Transparency = SHELL_TRANSPARENCY,
	})
	gemPart(model, gems, {
		Name = "Core",
		Size = Vector3.new(0.55 * s, 1.4 * s, 0.55 * s),
		CFrame = origin,
		Color = color,
		Material = Enum.Material.Neon,
	})
	for _, side in { 1, -1 } do
		-- A cube balanced on a vertex makes a faceted pointed cap.
		gemPart(model, gems, {
			Name = "Cap",
			Size = Vector3.one * 0.66 * s,
			CFrame = origin * CFrame.new(0, side * 0.86 * s, 0) * CFrame.Angles(math.rad(45), 0, math.rad(35.264)),
			Color = color,
			Material = Enum.Material.Glass,
			Reflectance = 0.15,
			Transparency = SHELL_TRANSPARENCY,
		})
	end
	return shell
end

function ShardBuilder.build(rarityId: number, shiny: boolean, isComet: boolean, position: Vector3): ShardParts
	local rarity = Rarities.get(rarityId)
	local s = scaleOf(isComet)
	local gems: { BasePart } = {}

	local model = Instance.new("Model")
	model.Name = if isComet then "CometCore" else `{rarity.key}Shard`
	model:SetAttribute("Rarity", rarityId)
	model:SetAttribute("Shiny", shiny)
	model:SetAttribute("IsComet", isComet)

	local origin = ShardBuilder.crystalCFrame(position, isComet)
	local crystal = crystalBody(model, gems, origin, s, rarity.color, true)
	crystal:AddTag(ShardBuilder.CRYSTAL_TAG)

	if rarityId == 2 or rarityId == 3 then
		crystalBody(
			model,
			gems,
			origin * CFrame.new(0.95 * s, -0.55 * s, 0) * CFrame.Angles(0, 0, math.rad(-28)),
			0.45 * s,
			rarity.color,
			false
		)
	elseif rarityId == 4 then
		for index = 0, 6 do
			local angle = math.rad(index * (360 / 7))
			gemPart(model, gems, {
				Name = "CrownPoint",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.3 * s,
				CFrame = origin * CFrame.new(math.cos(angle) * 0.62 * s, 0.62 * s, math.sin(angle) * 0.62 * s),
				Color = GOLD,
				Material = Enum.Material.Neon,
			})
		end
	elseif rarityId == 5 then
		local orbit = origin * CFrame.Angles(math.rad(70), 0, math.rad(18))
		for index = 0, 13 do
			local angle = math.rad(index * (360 / 14))
			gemPart(model, gems, {
				Name = "Orbit",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.2 * s,
				CFrame = orbit * CFrame.new(math.cos(angle) * 1.25 * s, math.sin(angle) * 1.25 * s, 0),
				Color = Color3.fromRGB(160, 255, 210),
				Material = Enum.Material.Neon,
			})
		end
	elseif rarityId == 6 then
		crystalBody(
			model,
			gems,
			origin * CFrame.Angles(0, 0, math.rad(55)),
			0.8 * s,
			Color3.fromRGB(200, 170, 255),
			false
		)
	end
	if shiny then
		for _, offset in { Vector3.new(-1.1, 1.2, -0.3), Vector3.new(1.2, 0.4, -0.3) } do
			gemPart(model, gems, {
				Name = "Twinkle",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.22 * s,
				CFrame = origin * CFrame.new(offset * s),
				Color = Color3.new(1, 1, 1),
				Material = Enum.Material.Neon,
			})
		end
	end

	-- Everything moves with the crystal (shell = PrimaryPart).
	for _, gem in gems do
		if gem ~= crystal then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = crystal
			weld.Part1 = gem
			weld.Parent = gem
		end
	end

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
	-- Stream the whole shard at once (clients animate it by tag).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:AddTag(ShardBuilder.TAG)
	return { model = model, crystal = crystal, beacon = beacon, gems = gems }
end

-- Anchors the gem (resting on the ground) or frees it (carried, welded to a character).
function ShardBuilder.setAnchored(parts: ShardParts, anchored: boolean)
	for _, gem in parts.gems do
		gem.Anchored = anchored
		gem.Massless = not anchored
	end
end

-- Hides/shows the whole shard (used while the meteor is still falling).
function ShardBuilder.setVisible(parts: ShardParts, visible: boolean)
	for _, gem in parts.gems do
		local base = gem:GetAttribute("BaseTransparency")
		gem.Transparency = if visible then (if type(base) == "number" then base else 0) else 1
	end
	parts.beacon.Transparency = if visible then BEACON_TRANSPARENCY else 1
	for _, child in parts.crystal:GetChildren() do
		if child:IsA("PointLight") or child:IsA("ParticleEmitter") or child:IsA("Sparkles") or child:IsA("Fire") then
			-- Every effect class above has an `Enabled` property.
			(child :: any).Enabled = visible
		end
	end
end

-- Moves an anchored shard to rest on the ground at `position` (every gem part keeps its offset).
function ShardBuilder.placeAt(parts: ShardParts, position: Vector3)
	local isComet = parts.model:GetAttribute("IsComet") == true
	local from = parts.crystal.CFrame
	local to = ShardBuilder.crystalCFrame(position, isComet)
	local offsets = {}
	for index, gem in parts.gems do
		offsets[index] = from:ToObjectSpace(gem.CFrame)
	end
	for index, gem in parts.gems do
		gem.CFrame = to * offsets[index]
	end
	parts.beacon.CFrame = ShardBuilder.beaconCFrame(position)
end

function ShardBuilder.setBeaconVisible(parts: ShardParts, visible: boolean)
	parts.beacon.Transparency = if visible then BEACON_TRANSPARENCY else 1
end

return table.freeze(ShardBuilder)
