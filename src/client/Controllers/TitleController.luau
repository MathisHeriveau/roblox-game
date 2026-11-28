--!strict
--[[
	TitleController — the title screen shown on join: the COMET RAIDERS logo over a slow camera
	orbit of the island, and a big PLAY button (Enter / Space / gamepad A also work).

	While it shows, the character controls and the Roblox chat window are disabled and the
	HUD/menu ScreenGuis registered with `TitleController.hideWhileShowing(gui)` (from their init())
	stay hidden. PLAY gives the camera back to the character, behind it, and reveals them. Must
	boot before any controller that registers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.UI.Create)
local Layers = require(script.Parent.Parent.UI.Layers)
local Logo = require(script.Parent.Parent.UI.Components.Logo)
local PillButton = require(script.Parent.Parent.UI.Components.PillButton)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local Theme = require(script.Parent.Parent.UI.Theme)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local RENDER_STEP = "CometRaidersTitleCamera"
local ORBIT_SPEED = 0.05 -- radians per second
local ORBIT_RADIUS = Zones.outerRadius(3) * Zones.TILE_SIZE * 1.05
local ORBIT_HEIGHT = ORBIT_RADIUS * 0.5
local FOCUS = Vector3.new(0, 18, 0)
local NIGHT = Color3.fromRGB(26, 27, 143)
-- Studs between the character and the camera when PLAY hands the camera back.
local PLAY_CAMERA_DISTANCE = 14

local TitleController = {
	name = "TitleController",
}

local showing = true
local hidden: { ScreenGui } = {}
local gui: ScreenGui
local content: Frame
local scale: UIScale
local playButton: PillButton.PillButton
local controls: any = nil

function TitleController.isShowing(): boolean
	return showing
end

-- Hides `target` until PLAY is pressed (no-op once the title is gone).
function TitleController.hideWhileShowing(target: ScreenGui)
	if showing then
		target.Enabled = false
		table.insert(hidden, target)
	end
end

-- SetCoreGuiEnabled errors while the core scripts are still loading: retry for a few seconds.
local function setChatEnabled(enabled: boolean)
	task.spawn(function()
		for _ = 1, 20 do
			-- A late "hide" retry must never win over PLAY.
			if not enabled and not showing then
				return
			end
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Chat, enabled) then
				return
			end
			task.wait(0.25)
		end
	end)
end

local function playerControls(): any
	local ok, result = pcall(function(): any
		local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts", 5)
		local module = scripts and scripts:WaitForChild("PlayerModule", 5)
		return (require :: any)(module):GetControls()
	end)
	return if ok then result else nil
end

local function orbit()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local startedAt = os.clock()
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 2, function()
		-- The default camera scripts reset the type when the character spawns: re-assert it.
		camera.CameraType = Enum.CameraType.Scriptable
		local angle = (os.clock() - startedAt) * ORBIT_SPEED + math.rad(200)
		local position = Vector3.new(math.cos(angle) * ORBIT_RADIUS, ORBIT_HEIGHT, math.sin(angle) * ORBIT_RADIUS)
		camera.CFrame = CFrame.lookAt(position, FOCUS)
	end)
end

local function play()
	if not showing then
		return
	end
	showing = false
	Sfx.play(Sfx.CLICK, 0.6)
	RunService:UnbindFromRenderStep(RENDER_STEP)

	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		-- Start behind the character, looking where it faces (its base and the meadow beyond),
		-- instead of keeping whatever direction the title orbit had reached.
		if root and root:IsA("BasePart") then
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			if look.Magnitude > 0.01 then
				look = look.Unit
				local focus = root.Position + Vector3.new(0, 2, 0)
				camera.CFrame = CFrame.lookAt(focus - look * PLAY_CAMERA_DISTANCE + Vector3.new(0, 5, 0), focus)
			end
		end
	end
	if controls then
		pcall(function()
			controls:Enable()
		end)
	end
	setChatEnabled(true)
	for _, target in hidden do
		target.Enabled = true
	end
	table.clear(hidden)

	local slide = TweenService:Create(
		content,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Position = UDim2.fromScale(0.5, -0.6) }
	)
	slide:Play()
	local backdrop = gui:FindFirstChild("Backdrop") :: Frame?
	if backdrop then
		TweenService:Create(backdrop, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	end
	task.delay(0.5, function()
		gui.Enabled = false
	end)
end

function TitleController.init(_self: any)
	scale = Instance.new("UIScale")
	local logo = Logo.new()
	logo.root.Position = UDim2.fromScale(0.5, 0.34)

	-- ★ (monochrome, outlined) rather than the ⭐ emoji, which vanishes on the gold pill.
	playButton = PillButton.new("★", "PLAY", Theme.Color.Gold, Theme.Color.GoldDark, Vector2.new(300, 92))
	playButton.root.AnchorPoint = Vector2.new(0.5, 0.5)
	playButton.root.Position = UDim2.fromScale(0.5, 0.76)
	-- Reuse the button's press scale: a GuiObject honours only one UIScale.
	local pulse = playButton.root:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	pulse.Parent = playButton.root
	TweenService
		:Create(
			pulse,
			TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.07 }
		)
		:Play()

	local tagline = Create("TextLabel", {
		Name = "Tagline",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromOffset(720, 36),
		Font = Theme.Font.Body,
		Text = "Catch falling stars  •  Hatch Starlings  •  Raid your friends!",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
	}) :: TextLabel
	Theme.textOutline(tagline, 2.5)

	local hint = Create("TextLabel", {
		Name = "Hint",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.88),
		Size = UDim2.fromOffset(420, 24),
		Font = Theme.Font.Body,
		Text = "Press Enter or click PLAY",
		TextColor3 = Theme.Color.TextDim,
		TextScaled = true,
	}) :: TextLabel
	Theme.textOutline(hint, 1.5)

	content = Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	}, { scale :: Instance, logo.root, tagline, playButton.root, hint }) :: Frame

	-- Night-sky tint at the top and bottom, the island visible in the middle.
	local backdrop = Create("Frame", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = NIGHT,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
	}) :: Frame
	local tint = Instance.new("UIGradient")
	tint.Rotation = 90
	tint.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.45, 0.8),
		NumberSequenceKeypoint.new(0.7, 0.75),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	tint.Parent = backdrop

	gui = Create("ScreenGui", {
		Name = "Title",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = Layers.Title,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, { backdrop :: Instance, content }) :: ScreenGui
end

function TitleController.start(_self: any)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local camera = Workspace.CurrentCamera
	if camera then
		local function rescale()
			scale.Scale = Theme.scaleFor(camera.ViewportSize)
		end
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		rescale()
	end

	playButton.root.Activated:Connect(play)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not showing then
			return
		end
		local key = input.KeyCode
		if
			key == Enum.KeyCode.Return
			or key == Enum.KeyCode.Space
			or key == Enum.KeyCode.ButtonA
			or key == Enum.KeyCode.ButtonStart
		then
			play()
		end
	end)

	orbit()
	setChatEnabled(false)
	controls = playerControls()
	if controls then
		-- ControlModule:Disable() calls Player:Move, which warns until the character AND its Humanoid
		-- have replicated (CharacterAdded fires before the Humanoid arrives).
		local player = Players.LocalPlayer
		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("Humanoid", 10)
		if showing then
			pcall(function()
				controls:Disable()
			end)
		end
	end
end

return TitleController
