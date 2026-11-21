--!strict
--[[
	AmbientController — local-only life in the world: Starlings bob and sway on their pedestals,
	shard gems spin, and shards in zones you have not unlocked get a 🔒 badge.

	Animations are client-side changes to server parts (never replicated), limited to things near
	the camera to stay cheap on mobile.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ShardVisuals = require(ReplicatedStorage.Shared.Game.ShardVisuals)
local StateController = require(script.Parent.StateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local STARLING_RANGE = 160
local CRYSTAL_RANGE = 240

local AmbientController = {
	name = "AmbientController",
}

type StarlingInfo = { base: CFrame, phase: number }

local starlings: { [Model]: StarlingInfo } = {}
-- Shard models whose gem spins while resting on the ground.
local shardModels: { [Model]: boolean } = {}
local badges: { [Model]: BillboardGui } = {}

local function addStarling(instance: Instance)
	if instance:IsA("Model") then
		starlings[instance] = { base = instance:GetPivot(), phase = math.random() * math.pi * 2 }
	end
end

local function updateBadge(model: Model)
	local state = StateController.get()
	local tier = model:GetAttribute("Tier")
	local locked = state ~= nil
		and type(tier) == "number"
		and model:GetAttribute("IsComet") ~= true
		and tier > state.zoneTier
	local badge: BillboardGui? = badges[model]
	if locked and badge == nil and type(tier) == "number" then
		local gui = Instance.new("BillboardGui")
		gui.Name = "LockBadge"
		gui.Size = UDim2.fromScale(7, 1.6)
		gui.StudsOffset = Vector3.new(0, 4.5, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 140
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Theme.Font.Body
		label.TextScaled = true
		label.TextColor3 = Theme.Color.Text
		label.Text = `🔒 {Zones.get(tier).name}`
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Theme.Color.Outline
		stroke.Parent = label
		label.Parent = gui
		gui.Parent = model
		badges[model] = gui
	elseif not locked and badge then
		badge:Destroy()
		badges[model] = nil
	end
end

local function addShard(instance: Instance)
	if instance:IsA("Model") then
		shardModels[instance] = true
		updateBadge(instance)
	end
end

local function removeShard(instance: Instance)
	if instance:IsA("Model") then
		badges[instance] = nil
		shardModels[instance] = nil
	end
end

local function step(time: number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local eye = camera.CFrame.Position

	for model, info in starlings do
		if model.Parent == nil then
			starlings[model] = nil
		elseif (info.base.Position - eye).Magnitude < STARLING_RANGE then
			model:PivotTo(
				info.base
					* CFrame.new(0, math.sin(time * 2.2 + info.phase) * 0.35, 0)
					* CFrame.Angles(0, math.sin(time * 0.9 + info.phase) * 0.45, 0)
			)
		end
	end

	for model in shardModels do
		local crystal = model.PrimaryPart
		if model.Parent == nil then
			shardModels[model] = nil
		elseif crystal and crystal.Anchored and (crystal.Position - eye).Magnitude < CRYSTAL_RANGE then
			-- Multi-part gem: pivot the whole model (the vertical beacon spins on its own axis).
			model:PivotTo(CFrame.new(crystal.Position) * CFrame.Angles(0, time * 1.8, 0) * ShardVisuals.TILT)
		end
	end
end

function AmbientController.init(_self: any)
	-- Tags are tracked from start().
end

function AmbientController.start(_self: any)
	for _, instance in CollectionService:GetTagged(ShardVisuals.STARLING_TAG) do
		addStarling(instance)
	end
	CollectionService:GetInstanceAddedSignal(ShardVisuals.STARLING_TAG):Connect(addStarling)

	for _, instance in CollectionService:GetTagged(ShardVisuals.SHARD_TAG) do
		addShard(instance)
	end
	CollectionService:GetInstanceAddedSignal(ShardVisuals.SHARD_TAG):Connect(addShard)
	CollectionService:GetInstanceRemovedSignal(ShardVisuals.SHARD_TAG):Connect(removeShard)
	StateController.changed:connect(function()
		for _, instance in CollectionService:GetTagged(ShardVisuals.SHARD_TAG) do
			if instance:IsA("Model") then
				updateBadge(instance)
			end
		end
	end)

	local time = 0
	RunService.RenderStepped:Connect(function(dt: number)
		time += dt
		step(time)
	end)
end

return AmbientController
