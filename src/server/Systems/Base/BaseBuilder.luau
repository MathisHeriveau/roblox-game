--!strict
--[[
	BaseBuilder — builds one player base (plot) from a BaseLayout.Plot: wooden floor and fence with
	lanterns, 12 pedestals, a collect pad, an owner sign and the plot's own SpawnLocation.
	Pure Instance construction (no services): testable headlessly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseLayout = require(script.Parent.BaseLayout)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

export type PlotRefs = {
	plot: BaseLayout.Plot,
	model: Model,
	cframe: CFrame,
	pedestals: { BasePart },
	rings: { BasePart },
	-- World CFrame where a Starling floats above each pedestal (index-aligned with `pedestals`).
	starlingAnchors: { CFrame },
	starlings: Folder,
	collectPad: BasePart,
	spawn: SpawnLocation,
	ownerLabel: TextLabel,
	incomeLabel: TextLabel,
	lockLabel: TextLabel,
	vaultLabel: TextLabel,
	-- One Steal prompt per pedestal (index-aligned), enabled by BaseService when stealable.
	stealPrompts: { ProximityPrompt },
	lockPrompt: ProximityPrompt,
	dome: BasePart,
}

local FLOOR_TOP = 1
local PEDESTAL_HEIGHT = 1.4
local WOOD = Color3.fromRGB(163, 116, 74)
local WOOD_DARK = Color3.fromRGB(118, 82, 52)
local PEDESTAL_COLOR = Color3.fromRGB(226, 224, 240)
local RING_COLOR = Color3.fromRGB(0, 180, 255)
local LOCKED_RING_COLOR = Color3.fromRGB(110, 106, 130)
local PAD_COLOR = Color3.fromRGB(64, 222, 120)

local BaseBuilder = {}

local function part(props: { [string]: any }, parent: Instance): Part
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.CanTouch = false
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function label(props: { [string]: any }, parent: Instance): TextLabel
	local instance = Instance.new("TextLabel")
	instance.BackgroundTransparency = 1
	instance.TextScaled = true
	instance.TextColor3 = Color3.new(1, 1, 1)
	for key, value in props do
		(instance :: any)[key] = value
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(28, 16, 70)
	stroke.Parent = instance
	instance.Parent = parent
	return instance
end

local function billboard(name: string, size: UDim2, offset: Vector3, parent: Instance): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = size
	gui.StudsOffset = offset
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	gui.Parent = parent
	return gui
end

function BaseBuilder.build(plot: BaseLayout.Plot, parent: Instance): PlotRefs
	local origin = CFrame.new(plot.x, 0, plot.z) * CFrame.Angles(0, plot.yaw, 0)
	local half = plot.size / 2

	local model = Instance.new("Model")
	model.Name = `Plot{plot.index}`
	model:SetAttribute("PlotIndex", plot.index)
	model:SetAttribute("OwnerUserId", 0)

	local floor = part({
		Name = "Floor",
		Size = Vector3.new(plot.size, FLOOR_TOP, plot.size),
		CFrame = origin * CFrame.new(0, FLOOR_TOP / 2, 0),
		Material = Enum.Material.WoodPlanks,
		Color = WOOD,
	}, model)
	model.PrimaryPart = floor

	-- Fence: back and sides closed, front open around the entrance.
	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = model
	local fenceY = FLOOR_TOP + 1.25
	part({
		Name = "Back",
		Size = Vector3.new(plot.size, 2.5, 1),
		CFrame = origin * CFrame.new(0, fenceY, half - 0.5),
		Material = Enum.Material.Wood,
		Color = WOOD_DARK,
	}, fence)
	for _, side in { -1, 1 } do
		part({
			Name = "Side",
			Size = Vector3.new(1, 2.5, plot.size),
			CFrame = origin * CFrame.new(side * (half - 0.5), fenceY, 0),
			Material = Enum.Material.Wood,
			Color = WOOD_DARK,
		}, fence)
		local segment = half - 5
		part({
			Name = "Front",
			Size = Vector3.new(segment, 2.5, 1),
			CFrame = origin * CFrame.new(side * (5 + segment / 2), fenceY, -half + 0.5),
			Material = Enum.Material.Wood,
			Color = WOOD_DARK,
		}, fence)
		for _, depth in { -1, 1 } do
			local post = part({
				Name = "LanternPost",
				Size = Vector3.new(1.2, 5, 1.2),
				CFrame = origin * CFrame.new(side * (half - 0.6), FLOOR_TOP + 2.5, depth * (half - 0.6)),
				Material = Enum.Material.Wood,
				Color = WOOD_DARK,
			}, fence)
			local lantern = part({
				Name = "Lantern",
				Size = Vector3.new(1, 1.2, 1),
				CFrame = post.CFrame * CFrame.new(0, 3.1, 0),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 196, 92),
				CastShadow = false,
			}, fence)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 190, 110)
			light.Range = 12
			light.Brightness = 1.2
			light.Parent = lantern
		end
	end

	-- Pedestals.
	local pedestalFolder = Instance.new("Folder")
	pedestalFolder.Name = "Pedestals"
	pedestalFolder.Parent = model
	local pedestals: { BasePart } = {}
	local rings: { BasePart } = {}
	local stealPrompts: { ProximityPrompt } = {}
	local anchors: { CFrame } = {}
	for index, point in plot.pedestals do
		local base = origin * CFrame.new(point.x, FLOOR_TOP, point.z)
		local pedestal = part({
			Name = `Pedestal{index}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(PEDESTAL_HEIGHT, 3.6, 3.6),
			CFrame = base * CFrame.new(0, PEDESTAL_HEIGHT / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.SmoothPlastic,
			Color = PEDESTAL_COLOR,
		}, pedestalFolder)
		local ring = part({
			Name = `Ring{index}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 4.1, 4.1),
			CFrame = base * CFrame.new(0, PEDESTAL_HEIGHT - 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Neon,
			Color = RING_COLOR,
			CanCollide = false,
			CastShadow = false,
		}, pedestalFolder)
		table.insert(pedestals, pedestal)
		table.insert(rings, ring)

		local steal = Instance.new("ProximityPrompt")
		steal.Name = "StealPrompt"
		steal.ActionText = "Steal"
		steal.ObjectText = "Starling"
		steal.HoldDuration = GameConfig.Raid.StealHoldSeconds
		steal.MaxActivationDistance = 10
		steal.RequiresLineOfSight = false
		steal.KeyboardKeyCode = Enum.KeyCode.E
		steal.Enabled = false
		steal.Parent = pedestal
		table.insert(stealPrompts, steal)
		-- Starlings face the entrance (local -Z), floating above the pedestal.
		table.insert(anchors, base * CFrame.new(0, PEDESTAL_HEIGHT + 2.4, 0) * CFrame.Angles(0, math.pi, 0))
	end

	local starlings = Instance.new("Folder")
	starlings.Name = "Starlings"
	starlings.Parent = model

	-- Collect pad with the vault counter.
	local padX, padZ = plot.collectPad.x, plot.collectPad.z
	local collectPad = part({
		Name = "CollectPad",
		Size = Vector3.new(6, 0.3, 6),
		CFrame = origin * CFrame.new(padX, FLOOR_TOP + 0.15, padZ),
		Material = Enum.Material.Neon,
		Color = PAD_COLOR,
		CanCollide = false,
		CastShadow = false,
	}, model)
	local padGui = billboard("VaultGui", UDim2.fromScale(8, 2.4), Vector3.new(0, 3.2, 0), collectPad)
	local vaultLabel = label({
		Name = "Vault",
		Size = UDim2.fromScale(1, 0.62),
		Text = "💰 0",
		Font = Enum.Font.LuckiestGuy,
		TextColor3 = Color3.fromRGB(255, 214, 64),
	}, padGui)
	label({
		Name = "Hint",
		Size = UDim2.fromScale(1, 0.38),
		Position = UDim2.fromScale(0, 0.62),
		Text = "STEP HERE TO COLLECT",
		Font = Enum.Font.FredokaOne,
	}, padGui)

	-- Owner sign floating above the back fence.
	local signX, signZ = plot.sign.x, plot.sign.z
	local signAnchor = part({
		Name = "SignAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = origin * CFrame.new(signX, 11, signZ),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	}, model)
	local signGui = billboard("SignGui", UDim2.fromScale(16, 6.5), Vector3.zero, signAnchor)
	local ownerLabel = label({
		Name = "Owner",
		Size = UDim2.fromScale(1, 0.46),
		Text = "Free Base",
		Font = Enum.Font.LuckiestGuy,
	}, signGui)
	local incomeLabel = label({
		Name = "Income",
		Size = UDim2.fromScale(1, 0.27),
		Position = UDim2.fromScale(0, 0.46),
		Text = "",
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(120, 255, 160),
	}, signGui)
	local lockLabel = label({
		Name = "Lock",
		Size = UDim2.fromScale(1, 0.27),
		Position = UDim2.fromScale(0, 0.73),
		Text = "",
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(140, 220, 255),
	}, signGui)

	-- Lock console near the entrance + the shield dome it raises.
	local console = part({
		Name = "LockConsole",
		Size = Vector3.new(2.4, 3, 2.4),
		CFrame = origin * CFrame.new(half - 4, FLOOR_TOP + 1.5, -half + 3.5),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(70, 60, 120),
	}, model)
	part({
		Name = "ConsoleScreen",
		Size = Vector3.new(2, 0.3, 2),
		CFrame = console.CFrame * CFrame.new(0, 1.6, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(110, 210, 255),
		CanCollide = false,
		CastShadow = false,
	}, model)
	local lockPrompt = Instance.new("ProximityPrompt")
	lockPrompt.Name = "LockPrompt"
	lockPrompt.ActionText = "Lock base"
	lockPrompt.ObjectText = "Shield"
	lockPrompt.HoldDuration = 0
	lockPrompt.MaxActivationDistance = 10
	lockPrompt.RequiresLineOfSight = false
	lockPrompt.KeyboardKeyCode = Enum.KeyCode.E
	lockPrompt.Parent = console

	local dome = part({
		Name = "ShieldDome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * plot.size * 1.45,
		CFrame = origin * CFrame.new(0, 1, 0),
		Material = Enum.Material.ForceField,
		Color = Color3.fromRGB(120, 200, 255),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	}, model)

	-- Personal spawn: BaseService sets player.RespawnLocation to it.
	local spawnX, spawnZ = BaseLayout.toWorld(plot, plot.spawn.x, plot.spawn.z)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlotSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.Size = Vector3.new(5, 1, 5)
	spawn.CFrame = CFrame.new(spawnX, FLOOR_TOP + 0.5, spawnZ) * CFrame.Angles(0, plot.yaw + math.pi, 0)
	spawn.Parent = model

	model.Parent = parent

	return {
		plot = plot,
		model = model,
		cframe = origin,
		pedestals = pedestals,
		rings = rings,
		starlingAnchors = anchors,
		starlings = starlings,
		collectPad = collectPad,
		spawn = spawn,
		ownerLabel = ownerLabel,
		incomeLabel = incomeLabel,
		lockLabel = lockLabel,
		vaultLabel = vaultLabel,
		stealPrompts = stealPrompts,
		lockPrompt = lockPrompt,
		dome = dome,
	}
end

-- Shows or hides the shield dome.
function BaseBuilder.setShield(refs: PlotRefs, active: boolean)
	refs.dome.Transparency = if active then 0.35 else 1
end

-- Shows which pedestals are usable (unlocked slots glow blue, locked ones are dimmed).
function BaseBuilder.setUnlockedSlots(refs: PlotRefs, unlocked: number)
	for index, pedestal in refs.pedestals do
		local open = index <= unlocked
		pedestal.Transparency = if open then 0 else 0.55
		refs.rings[index].Color = if open then RING_COLOR else LOCKED_RING_COLOR
		refs.rings[index].Transparency = if open then 0 else 0.6
	end
end

return table.freeze(BaseBuilder)
