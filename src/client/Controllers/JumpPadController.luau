--!strict
--[[
	JumpPadController — launches the local character when it steps on a jump pad.

	Characters are physically simulated by their own client, so the launch is applied here. Each
	pad carries a precomputed LaunchVelocity (MapLayout.launchVelocity) that lands exactly on the
	target island or shore. Purely movement: no reward depends on it, so client authority is fine.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Sfx = require(script.Parent.Parent.Effects.Sfx)
local ShardVisuals = require(ReplicatedStorage.Shared.Game.ShardVisuals)
local Vfx = require(script.Parent.Parent.Effects.Vfx)

local PAD_RADIUS = 4.2
local COOLDOWN_SECONDS = 1.2

local JumpPadController = {
	name = "JumpPadController",
}

local pads: { [BasePart]: boolean } = {}
local lastLaunch = 0

local function track(instance: Instance)
	if instance:IsA("BasePart") then
		pads[instance] = true
	end
end

local function step()
	local now = os.clock()
	if now - lastLaunch < COOLDOWN_SECONDS then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local position = root.Position
	for pad in pads do
		if pad.Parent == nil then
			pads[pad] = nil
		else
			local offset = position - pad.Position
			local height = offset.Y
			offset *= Vector3.new(1, 0, 1)
			if offset.Magnitude <= PAD_RADIUS and height > -1 and height < 7 then
				local velocity = pad:GetAttribute("LaunchVelocity")
				if typeof(velocity) == "Vector3" then
					lastLaunch = now
					humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
					root.AssemblyLinearVelocity = velocity
					Sfx.play(Sfx.BUMP, 0.6)
					Vfx.shockwave(pad.Position, pad.Color, 9)
				end
				return
			end
		end
	end
end

function JumpPadController.init(_self: any)
	-- Pads are discovered by tag in start().
end

function JumpPadController.start(_self: any)
	for _, instance in CollectionService:GetTagged(ShardVisuals.JUMP_PAD_TAG) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(ShardVisuals.JUMP_PAD_TAG):Connect(track)
	-- Checked every frame: at full speed a character crosses a pad in a few frames.
	RunService.Heartbeat:Connect(step)
end

return JumpPadController
