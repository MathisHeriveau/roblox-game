--!strict
--[[
	StarlingBuilder — the cute star creatures that live on base pedestals (art style sheet).
	Built from Parts only (no external assets): glowing core, five rays, a face, rarity extras
	(crown for Legendary, halo for Cosmic) and sparkles when shiny. Tagged "Starling" so clients
	animate them locally. Pure Instance construction: testable headlessly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local ShardVisuals = require(ReplicatedStorage.Shared.Game.ShardVisuals)

local StarlingBuilder = {}

StarlingBuilder.TAG = ShardVisuals.STARLING_TAG

local function part(props: { [string]: any }, parent: Instance): Part
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.CanCollide = false
	instance.CanTouch = false
	instance.CanQuery = false
	instance.CastShadow = false
	instance.Material = Enum.Material.Neon
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

-- `cframe` is the centre of the star; its -Z axis is the facing direction.
function StarlingBuilder.build(rarityId: number, shiny: boolean, cframe: CFrame): Model
	local rarity = Rarities.get(rarityId)
	local model = Instance.new("Model")
	model.Name = `{rarity.key}Starling`
	model:SetAttribute("Rarity", rarityId)
	model:SetAttribute("Shiny", shiny)

	local core = part({
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.2, 2.2, 2.2),
		CFrame = cframe,
		Color = rarity.color,
	}, model)

	for index = 0, 4 do
		part({
			Name = "Ray",
			Size = Vector3.new(1, 1.5, 0.75),
			CFrame = cframe * CFrame.Angles(0, 0, math.rad(index * 72)) * CFrame.new(0, 1.4, 0),
			Color = rarity.color,
		}, model)
	end

	if rarityId == 4 then
		-- Legendary: tiny golden crown.
		for _, x in { -0.45, 0, 0.45 } do
			part({
				Name = "Crown",
				Size = Vector3.new(0.3, 0.55, 0.3),
				CFrame = cframe * CFrame.new(x, 2.45, 0),
				Color = Color3.fromRGB(255, 205, 64),
			}, model)
		end
	elseif rarityId == 6 then
		-- Cosmic: floating halo.
		part({
			Name = "Halo",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 2.4, 2.4),
			CFrame = cframe * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 240, 180),
		}, model)
	end

	local face = Instance.new("BillboardGui")
	face.Name = "Face"
	face.Size = UDim2.fromScale(2, 1.2)
	face.LightInfluence = 0
	face.MaxDistance = 90
	face.Parent = core
	local eyes = Instance.new("TextLabel")
	eyes.Name = "Eyes"
	eyes.BackgroundTransparency = 1
	eyes.Size = UDim2.fromScale(1, 1)
	eyes.Text = if shiny then "★ᴗ★" else "◕ᴗ◕"
	eyes.TextScaled = true
	eyes.Font = Enum.Font.FredokaOne
	eyes.TextColor3 = Color3.fromRGB(40, 24, 60)
	eyes.Parent = face

	local light = Instance.new("PointLight")
	light.Color = rarity.color
	light.Range = 9
	light.Brightness = 1.4
	light.Parent = core

	if shiny then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = rarity.color
		sparkles.Parent = core
	end

	model.PrimaryPart = core
	-- Stream atomically: clients pivot the whole model when animating it.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:AddTag(StarlingBuilder.TAG)
	return model
end

return table.freeze(StarlingBuilder)
