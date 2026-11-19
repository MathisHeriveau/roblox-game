--!strict
--[[
	InputController — player actions: BUMP (F key, gamepad X, or the on-screen touch button) and
	applying knockback when this player gets bumped (the client owns its character's physics).
	The client only *asks* to bump; the server decides who (if anyone) is hit.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientNet = require(ReplicatedStorage.Shared.Net.ClientNet)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local Theme = require(script.Parent.Parent.UI.Theme)
local Vfx = require(script.Parent.Parent.Effects.Vfx)

local BUMP_ACTION = "CometRaidersBump"
-- Client-side courtesy throttle; the server enforces the real cooldown.
local LOCAL_THROTTLE_SECONDS = 0.35

local InputController = {
	name = "InputController",
}

local lastBump = 0

local function characterParts(): (BasePart?, Humanoid?)
	local character = Players.LocalPlayer.Character
	if character == nil then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil, character:FindFirstChildOfClass("Humanoid")
end

local function bump()
	local now = os.clock()
	if now - lastBump < LOCAL_THROTTLE_SECONDS then
		return
	end
	lastBump = now
	ClientNet.fireServer("RequestBump")
	local root = characterParts()
	if root then
		Vfx.shockwave(root.Position - Vector3.new(0, 2.5, 0), Theme.Color.TextDim, 6)
	end
end

local function onKnockback(direction: unknown)
	if typeof(direction) ~= "Vector3" then
		return
	end
	local flat = (direction :: Vector3) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.01 or flat.Magnitude > 2 then
		return
	end
	local root, humanoid = characterParts()
	if root == nil or humanoid == nil then
		return
	end
	local force = GameConfig.Bump.KnockbackForce
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	root:ApplyImpulse((flat.Unit * force + Vector3.new(0, force * 0.5, 0)) * root.AssemblyMass)
	Sfx.play(Sfx.HURT, 0.6)
end

function InputController.init(_self: any)
	-- Bindings are created in start(), once remotes exist.
end

function InputController.start(_self: any)
	ContextActionService:BindAction(BUMP_ACTION, function(_name: string, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			bump()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle(BUMP_ACTION, "BUMP")
	ContextActionService:SetPosition(BUMP_ACTION, UDim2.new(1, -200, 1, -150))
	ClientNet.onEvent("Knockback", onKnockback)
end

return InputController
