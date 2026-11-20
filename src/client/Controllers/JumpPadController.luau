--!strict
--[[
	JumpPadController — launches the local character when it steps on a jump pad.

	Characters are physically simulated by their own client, so the launch is applied here. Each
	pad carries a precomputed LaunchVelocity and FlightTime (MapLayout.launchVelocity). The
	Humanoid's air control would cancel the horizontal part of a one-off launch, so a LinearVelocity
	holds it for the flight (JumpFlight decides when to let go); gravity does the vertical part.
	Purely movement: no reward depends on it, so client authority is fine.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local JumpFlight = require(script.Parent.Parent.Movement.JumpFlight)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local ShardVisuals = require(ReplicatedStorage.Shared.Game.ShardVisuals)
local Vfx = require(script.Parent.Parent.Effects.Vfx)

local PAD_RADIUS = 4.2
local COOLDOWN_SECONDS = 1.2

local JumpPadController = {
	name = "JumpPadController",
}

type Flight = {
	hold: LinearVelocity,
	attachment: Attachment,
	startedAt: number,
	flightTime: number,
	humanoid: Humanoid,
}

local pads: { [BasePart]: boolean } = {}
local lastLaunch = 0
local flight: Flight? = nil

local function track(instance: Instance)
	if instance:IsA("BasePart") then
		pads[instance] = true
	end
end

local function endFlight()
	local current = flight
	if current then
		current.hold:Destroy()
		current.attachment:Destroy()
	end
	flight = nil
end

local function launch(root: BasePart, humanoid: Humanoid, plan: JumpFlight.Plan)
	endFlight()
	local attachment = Instance.new("Attachment")
	attachment.Name = "JumpPadAttachment"
	attachment.Parent = root
	local hold = Instance.new("LinearVelocity")
	hold.Name = "JumpPadHold"
	hold.Attachment0 = attachment
	hold.RelativeTo = Enum.ActuatorRelativeTo.World
	hold.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	hold.PrimaryTangentAxis = Vector3.xAxis
	hold.SecondaryTangentAxis = Vector3.zAxis
	hold.PlaneVelocity = Vector2.new(plan.velocity.X, plan.velocity.Z)
	-- Only the horizontal plane is constrained: it must win against the Humanoid's air control.
	hold.ForceLimitsEnabled = false
	hold.Parent = root

	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = plan.velocity
	flight = {
		hold = hold,
		attachment = attachment,
		startedAt = os.clock(),
		flightTime = plan.flightTime,
		humanoid = humanoid,
	}
end

local function updateFlight()
	local current = flight
	if current == nil then
		return
	end
	local humanoid = current.humanoid
	local onGround = humanoid.FloorMaterial ~= Enum.Material.Air
	local gone = current.hold.Parent == nil or humanoid.Health <= 0
	if gone or JumpFlight.shouldRelease(os.clock() - current.startedAt, current.flightTime, onGround) then
		endFlight()
	end
end

local function step()
	updateFlight()
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
				local plan = JumpFlight.read(pad)
				if plan then
					lastLaunch = now
					launch(root, humanoid, plan)
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
	-- A new character never inherits a flight (the hold died with the old one).
	Players.LocalPlayer.CharacterAdded:Connect(endFlight)
	-- Checked every frame: at full speed a character crosses a pad in a few frames.
	RunService.Heartbeat:Connect(step)
end

return JumpPadController
