--!strict
--[[
	AmbientController — local-only life in the world: Starlings bob and sway on their pedestals,
	shard gems spin, and shards in zones you have not unlocked get a 🔒 badge. Walking up to such
	a shard explains (toast, at most every HINT_INTERVAL seconds) which zone to buy and its price.

	Animations are client-side changes to server parts (never replicated), limited to things near
	the camera to stay cheap on mobile.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local LockBadge = require(script.Parent.Parent.Effects.LockBadge)
local NotificationController = require(script.Parent.NotificationController)
local ShardVisuals = require(ReplicatedStorage.Shared.Game.ShardVisuals)
local StarlingBob = require(script.Parent.Parent.Effects.StarlingBob)
local StateController = require(script.Parent.StateController)
local ZoneAnnouncer = require(script.Parent.Parent.Hud.ZoneAnnouncer)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local STARLING_RANGE = 160
local CRYSTAL_RANGE = 240
-- Locked-shard hint: shown when within the magnet radius + HINT_REACH studs of a 🔒 shard.
local HINT_REACH = 4
local HINT_INTERVAL = 8
local HINT_CHECK_SECONDS = 0.5

local AmbientController = {
	name = "AmbientController",
}

-- `base` stays nil until the model's core has replicated (see Effects/StarlingBob).
type StarlingInfo = { base: CFrame?, phase: number }

local starlings: { [Model]: StarlingInfo } = {}
-- Shard models whose gem spins while resting on the ground.
local shardModels: { [Model]: boolean } = {}
local badges: { [Model]: BillboardGui } = {}

local function addStarling(instance: Instance)
	if instance:IsA("Model") then
		starlings[instance] = { base = StarlingBob.restPose(instance), phase = math.random() * math.pi * 2 }
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
		local gui = LockBadge.new(`🔒 {Zones.get(tier).name}`)
		LockBadge.adorn(gui, model)
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
			continue
		end
		local base = info.base or StarlingBob.restPose(model)
		info.base = base
		if base and (base.Position - eye).Magnitude < STARLING_RANGE then
			model:PivotTo(base * StarlingBob.offset(time, info.phase))
		end
	end

	for model in shardModels do
		local crystal = model.PrimaryPart
		local badge = badges[model]
		if badge and crystal and badge.Adornee ~= crystal then
			LockBadge.adorn(badge, model)
		end
		if model.Parent == nil then
			shardModels[model] = nil
		elseif crystal and crystal.Anchored and (crystal.Position - eye).Magnitude < CRYSTAL_RANGE then
			-- Multi-part gem: pivot the whole model (the vertical beacon spins on its own axis).
			model:PivotTo(CFrame.new(crystal.Position) * CFrame.Angles(0, time * 1.8, 0) * ShardVisuals.TILT)
		end
	end
end

local function hintLoop()
	local lastHintAt = -math.huge
	while true do
		task.wait(HINT_CHECK_SECONDS)
		local state = StateController.get()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if state and root and root:IsA("BasePart") and os.clock() - lastHintAt >= HINT_INTERVAL then
			local reach = Economy.magnetRadius(state.upgrades.magnet) + HINT_REACH
			for model in badges do
				local tier = model:GetAttribute("Tier")
				if
					model.Parent ~= nil
					and type(tier) == "number"
					and tier >= 1
					and tier <= Zones.COUNT
					and (model:GetPivot().Position - root.Position).Magnitude <= reach
				then
					lastHintAt = os.clock()
					NotificationController.show(ZoneAnnouncer.lockedShardHint(tier, state.zoneTier), "warning")
					break
				end
			end
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

	task.spawn(hintLoop)

	local time = 0
	RunService.RenderStepped:Connect(function(dt: number)
		time += dt
		step(time)
	end)
end

return AmbientController
