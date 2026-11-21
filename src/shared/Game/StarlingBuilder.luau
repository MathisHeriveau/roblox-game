--!strict
--[[
	StarlingBuilder — the plump star creatures of the art style sheet, built from Parts only
	(no external assets): a puffy five-armed body made of overlapping spheres, a real 3D face
	(eyes with highlights, open mouth, blushing cheeks), a per-rarity expression and accessory:

	  Common  happy closed eyes (^ ^)          Rare      floating cyan crystals
	  Epic    wink + purple crystals            Legendary golden crown with a gem
	  Mythic  emerald crystal shards around     Cosmic    golden halo + crystal wings
	  Shiny   white sparkles and a sparkle effect

	Tagged "Starling" so clients animate them locally. `cframe` is the star centre; its -Z axis is
	the facing direction. Preview the result with `make preview-models`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local ShardVisuals = require(ReplicatedStorage.Shared.Game.ShardVisuals)

local StarlingBuilder = {}

StarlingBuilder.TAG = ShardVisuals.STARLING_TAG

local BODY_RADIUS = 1.42
local EYE_COLOR = Color3.fromRGB(34, 20, 48)
local MOUTH_COLOR = Color3.fromRGB(92, 24, 48)
local TONGUE_COLOR = Color3.fromRGB(255, 110, 140)
local BLUSH_COLOR = Color3.fromRGB(255, 132, 170)
local GOLD = Color3.fromRGB(255, 200, 48)
local WHITE = Color3.new(1, 1, 1)
-- Cosmic Starlings are pearly white (the halo and wings carry the pink).
local BODY_OVERRIDE: { [number]: Color3 } = {
	[6] = Color3.fromRGB(255, 236, 255),
}
local ACCENT: { [number]: Color3 } = {
	[2] = Color3.fromRGB(120, 230, 255),
	[3] = Color3.fromRGB(200, 130, 255),
	[5] = Color3.fromRGB(80, 255, 170),
	[6] = Color3.fromRGB(255, 150, 240),
}

local function part(model: Model, props: { [string]: any }): Part
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.CanCollide = false
	instance.CanTouch = false
	instance.CanQuery = false
	instance.CastShadow = false
	instance.Material = Enum.Material.SmoothPlastic
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = model
	return instance
end

local function ball(
	model: Model,
	name: string,
	cframe: CFrame,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): Part
	return part(model, {
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diameter,
		CFrame = cframe,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

-- A small pointed gem: two overlapping diamonds (squares turned 45°) give an elongated rhombus.
local function crystal(model: Model, cframe: CFrame, size: number, color: Color3)
	for _, offset in { 0.24, -0.24 } do
		part(model, {
			Name = "Crystal",
			Size = Vector3.new(size * 0.62, size * 0.62, size * 0.3),
			CFrame = cframe * CFrame.new(0, offset * size, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Color = color,
			Material = Enum.Material.Neon,
		})
	end
end

local function closedEye(model: Model, cframe: CFrame)
	-- "^" made of two short strokes.
	for _, side in { -1, 1 } do
		part(model, {
			Name = "ClosedEye",
			Size = Vector3.new(0.34, 0.11, 0.1),
			CFrame = cframe * CFrame.new(side * 0.13, 0, 0) * CFrame.Angles(0, 0, math.rad(side * -38)),
			Color = EYE_COLOR,
		})
	end
end

local function openEye(model: Model, cframe: CFrame)
	ball(model, "Eye", cframe, 0.74, EYE_COLOR)
	ball(model, "EyeShine", cframe * CFrame.new(-0.13, 0.16, -0.28), 0.26, WHITE, Enum.Material.Neon)
end

function StarlingBuilder.build(rarityId: number, shiny: boolean, cframe: CFrame): Model
	local rarity = Rarities.get(rarityId)
	local bodyColor = BODY_OVERRIDE[rarityId] or rarity.color
	local accent = ACCENT[rarityId] or rarity.color

	local model = Instance.new("Model")
	model.Name = `{rarity.key}Starling`
	model:SetAttribute("Rarity", rarityId)
	model:SetAttribute("Shiny", shiny)

	-- Puffy body: a big core and five tapered arms (two spheres each).
	local core = ball(model, "Core", cframe, BODY_RADIUS * 2, bodyColor)
	for index = 0, 4 do
		local arm = cframe * CFrame.Angles(0, 0, math.rad(index * 72))
		-- Three overlapping spheres taper smoothly towards a rounded point.
		ball(model, "Arm", arm * CFrame.new(0, 1.15, 0.08), 1.75, bodyColor)
		ball(model, "Arm", arm * CFrame.new(0, 1.7, 0.12), 1.3, bodyColor)
		ball(model, "ArmTip", arm * CFrame.new(0, 2.2, 0.15), 0.85, bodyColor)
	end

	-- Face on the front (-Z) of the core.
	local face = cframe * CFrame.new(0, 0, -1.2)
	local leftEye = face * CFrame.new(-0.52, 0.32, 0)
	local rightEye = face * CFrame.new(0.52, 0.32, 0)
	if rarityId == 1 then
		closedEye(model, leftEye * CFrame.new(0, 0, -0.22))
		closedEye(model, rightEye * CFrame.new(0, 0, -0.22))
	elseif rarityId == 3 then
		openEye(model, leftEye)
		closedEye(model, rightEye * CFrame.new(0, 0, -0.22))
	else
		openEye(model, leftEye)
		openEye(model, rightEye)
	end
	ball(model, "Mouth", face * CFrame.new(0, -0.34, 0.02), 0.6, MOUTH_COLOR)
	ball(model, "Tongue", face * CFrame.new(0, -0.48, -0.17), 0.28, TONGUE_COLOR)
	for _, side in { -1, 1 } do
		part(model, {
			Name = "Blush",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.06, 0.42, 0.42),
			-- Cylinder axis (X) turned to face forward, tilted to follow the round body.
			CFrame = cframe
				* CFrame.Angles(0, math.rad(side * -38), 0)
				* CFrame.new(0, -0.1, -BODY_RADIUS + 0.02)
				* CFrame.Angles(0, math.rad(90), 0),
			Color = BLUSH_COLOR,
			Transparency = 0.15,
		})
	end

	-- Rarity accessories.
	if rarityId == 2 or rarityId == 3 then
		for _, offset in { Vector3.new(-2.3, 1.5, 0.3), Vector3.new(2.3, 1.9, 0.3) } do
			crystal(model, cframe * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(offset.X * 6)), 0.75, accent)
		end
	elseif rarityId == 4 then
		local crown = cframe * CFrame.new(0.3, 2.75, 0.1) * CFrame.Angles(0, 0, math.rad(-14))
		part(model, {
			Name = "CrownBand",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 1.45, 1.45),
			CFrame = crown * CFrame.Angles(0, 0, math.rad(90)),
			Color = GOLD,
			Material = Enum.Material.Neon,
		})
		for index = 0, 4 do
			local angle = math.rad(index * 72)
			ball(
				model,
				"CrownPoint",
				crown * CFrame.new(math.cos(angle) * 0.62, 0.45, math.sin(angle) * 0.62),
				0.38,
				GOLD,
				Enum.Material.Neon
			)
		end
		ball(model, "CrownGem", crown * CFrame.new(0, 0.05, -0.6), 0.3, Color3.fromRGB(255, 70, 90), Enum.Material.Neon)
	elseif rarityId == 5 then
		for _, offset in
			{
				Vector3.new(-2.2, 1.7, 0.4),
				Vector3.new(2.2, 1.6, 0.4),
				Vector3.new(-1.9, -1.9, 0.4),
				Vector3.new(1.9, -1.8, 0.4),
			}
		do
			crystal(model, cframe * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(-offset.X * 12)), 0.85, accent)
		end
	elseif rarityId == 6 then
		local halo = cframe * CFrame.new(0, 3.2, 0.2) * CFrame.Angles(math.rad(-12), 0, 0)
		for index = 0, 13 do
			local angle = math.rad(index * (360 / 14))
			ball(
				model,
				"Halo",
				halo * CFrame.new(math.cos(angle) * 0.95, 0, math.sin(angle) * 0.95),
				0.26,
				GOLD,
				Enum.Material.Neon
			)
		end
		for _, side in { -1, 1 } do
			for feather = 0, 2 do
				part(model, {
					Name = "Wing",
					Size = Vector3.new(0.35, 1.5 - feather * 0.3, 0.6),
					CFrame = cframe
						* CFrame.new(side * (2.15 + feather * 0.45), 0.5 + feather * 0.35, 0.7)
						* CFrame.Angles(0, 0, math.rad(side * (-35 - feather * 18))),
					Color = accent,
					Material = Enum.Material.Neon,
					Transparency = 0.3,
				})
			end
		end
	end

	if shiny then
		for _, offset in { Vector3.new(-2, 2.3, -0.4), Vector3.new(2.2, -0.6, -0.4), Vector3.new(-1.4, -2.3, -0.4) } do
			ball(model, "Twinkle", cframe * CFrame.new(offset), 0.3, WHITE, Enum.Material.Neon)
		end
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = rarity.color
		sparkles.Parent = core
	end

	local light = Instance.new("PointLight")
	light.Color = rarity.color
	light.Range = 10
	light.Brightness = 1.6
	light.Parent = core

	model.PrimaryPart = core
	-- Stream atomically: clients pivot the whole model when animating it.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:AddTag(StarlingBuilder.TAG)
	return model
end

return table.freeze(StarlingBuilder)
