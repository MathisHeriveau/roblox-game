--!strict
--[[
	HomeGuideController — a glowing golden beam from the character to their own base while they
	carry shards or a stolen Starling. Answers the #1 newcomer question: "where do I bring this?".
	Purely local and cosmetic.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlayerStateTypes = require(ReplicatedStorage.Shared.Types.PlayerState)
local StateController = require(script.Parent.StateController)
local Theme = require(script.Parent.Parent.UI.Theme)

type PlayerState = PlayerStateTypes.PlayerState

local HomeGuideController = {
	name = "HomeGuideController",
}

local beam: Beam? = nil
local homeAttachment: Attachment? = nil
local active = false

local function ownFloor(): BasePart?
	local bases = Workspace:FindFirstChild("Bases")
	if bases == nil then
		return nil
	end
	for _, plot in bases:GetChildren() do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
			return plot.PrimaryPart
		end
	end
	return nil
end

local function clear()
	if beam then
		beam:Destroy()
		beam = nil
	end
	if homeAttachment then
		homeAttachment:Destroy()
		homeAttachment = nil
	end
end

local function show()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local floor = ownFloor()
	if root == nil or not root:IsA("BasePart") or floor == nil then
		clear()
		return
	end
	if beam and beam.Attachment0 and beam.Attachment0.Parent == root and homeAttachment then
		return
	end
	clear()
	local from = Instance.new("Attachment")
	from.Name = "HomeGuideFrom"
	from.Position = Vector3.new(0, -1, 0)
	from.Parent = root
	local to = Instance.new("Attachment")
	to.Name = "HomeGuideTo"
	to.Position = Vector3.new(0, 6, 0)
	to.Parent = floor
	homeAttachment = to

	local created = Instance.new("Beam")
	created.Attachment0 = from
	created.Attachment1 = to
	created.Color = ColorSequence.new(Theme.Color.Gold, Theme.Color.GoldDark)
	created.Transparency = NumberSequence.new(0.15, 0.55)
	created.LightEmission = 1
	created.Width0 = 1.4
	created.Width1 = 3
	created.FaceCamera = true
	created.CurveSize0 = 8
	created.CurveSize1 = -8
	created.Segments = 24
	created.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	created.TextureMode = Enum.TextureMode.Wrap
	created.TextureLength = 4
	created.TextureSpeed = 2
	created.Parent = root
	beam = created
end

local function update(state: PlayerState?)
	active = state ~= nil and (state.carrying > 0 or state.carryingStarling > 0)
	if active then
		show()
	else
		clear()
	end
end

function HomeGuideController.init(_self: any)
	StateController.changed:connect(update)
end

function HomeGuideController.start(_self: any)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		clear()
		task.defer(function()
			update(StateController.get())
		end)
	end)
	update(StateController.get())
end

return HomeGuideController
