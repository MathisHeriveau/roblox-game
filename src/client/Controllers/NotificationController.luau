--!strict
--[[
	NotificationController — stacked toast notifications (server Notify + local messages).
	Drawn under the shop modal (UI/Layers): purchase feedback is shown inside the shop instead.

	Toasts stack upwards from just above the carry pill (bottom centre), newest at the bottom: the
	top of the screen belongs to the HUD's banner column (countdowns, zone and comet banners),
	whose height changes, and toasts used to cover the comet banner.

	Also tints the screen red for a moment (and says "ouch") when the local character loses health:
	lava used to burn silently.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ClientNet = require(ReplicatedStorage.Shared.Net.ClientNet)
local Create = require(script.Parent.Parent.UI.Create)
local Layers = require(script.Parent.Parent.UI.Layers)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Settings = require(script.Parent.Parent.Settings)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local MAX_TOASTS = 4
local LIFETIME_SECONDS = 3.2
local POP_SECONDS = 0.18
-- Distance from the bottom of the screen to the newest toast: clears the carry pill and its hint.
local BOTTOM_OFFSET = 128
-- Hurt feedback: ignore tiny health changes, flash at most this often (lava ticks 4x per second).
local HURT_MIN_DAMAGE = 0.5
local HURT_MIN_INTERVAL = 0.45
local HURT_FLASH_TRANSPARENCY = 0.72

local STYLE_COLORS: { [string]: Color3 } = {
	info = Theme.Color.Blue,
	success = Theme.Color.Green,
	warning = Theme.Color.Gold,
	error = Theme.Color.Red,
	coins = Theme.Color.Gold,
	pickup = Theme.Color.Gold,
	rarity = Theme.Color.Purple,
	alarm = Theme.Color.Red,
}

-- Full-screen red pulse for "your base is being raided".
local flash: Frame

local NotificationController = {
	name = "NotificationController",
}

local gui: ScreenGui
local holder: Frame
local scale: UIScale
local order = 0
local lastHurtAt = -math.huge

local function pulseFlash(transparency: number, seconds: number)
	flash.BackgroundTransparency = transparency
	TweenService:Create(flash, TweenInfo.new(seconds), { BackgroundTransparency = 1 }):Play()
end

local function watchHealth(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	local last = humanoid.Health
	humanoid.HealthChanged:Connect(function(health: number)
		local lost = last - health
		last = health
		local now = os.clock()
		if lost < HURT_MIN_DAMAGE or now - lastHurtAt < HURT_MIN_INTERVAL then
			return
		end
		lastHurtAt = now
		Sfx.play(Sfx.HURT, 0.45)
		if Settings.get("effects") then
			pulseFlash(HURT_FLASH_TRANSPARENCY, 0.35)
		end
	end)
end

function NotificationController.show(text: string, style: string, rarity: number?)
	local color = STYLE_COLORS[style] or Theme.Color.Blue
	if rarity and Rarities.isValid(rarity) then
		color = Rarities.get(rarity).color
	end
	order += 1
	local toast = Toast.new(text, color)
	toast.LayoutOrder = order
	local pop = Instance.new("UIScale")
	pop.Scale = 0.6
	pop.Parent = toast
	toast.Parent = holder
	TweenService:Create(pop, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	local toasts = {}
	for _, child in holder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = 1, #toasts - MAX_TOASTS do
		toasts[index]:Destroy()
	end

	if style == "pickup" or style == "coins" or style == "rarity" then
		Sfx.play(Sfx.PICKUP, 0.35)
	elseif style == "alarm" then
		Sfx.play(Sfx.HURT, 0.8)
		pulseFlash(0.55, 0.9)
	end
	task.delay(LIFETIME_SECONDS, function()
		if toast.Parent == nil then
			return
		end
		local shrink = TweenService:Create(pop, TweenInfo.new(POP_SECONDS), { Scale = 0 })
		shrink.Completed:Once(function()
			toast:Destroy()
		end)
		shrink:Play()
	end)
end

function NotificationController.init(_self: any)
	scale = Instance.new("UIScale")
	holder = Create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM_OFFSET),
		Size = UDim2.fromOffset(900, 260),
		BackgroundTransparency = 1,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	}) :: Frame
	flash = Create("Frame", {
		Name = "AlarmFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Red,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
	}) :: Frame
	gui = Create("ScreenGui", {
		Name = "Notifications",
		ResetOnSpawn = false,
		DisplayOrder = Layers.Toasts,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		-- Full screen so the alarm flash covers everything.
		ScreenInsets = Enum.ScreenInsets.None,
	}, { scale :: Instance, flash, holder }) :: ScreenGui
end

function NotificationController.start(_self: any)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local camera = Workspace.CurrentCamera
	if camera then
		local function rescale()
			scale.Scale = Theme.scaleFor(camera.ViewportSize)
		end
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		rescale()
	end

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(watchHealth)
	if player.Character then
		task.spawn(watchHealth, player.Character)
	end

	ClientNet.onEvent("Notify", function(payload: unknown)
		if type(payload) ~= "table" then
			return
		end
		local data = payload :: any
		if type(data.text) ~= "string" or #data.text > 200 or type(data.style) ~= "string" then
			return
		end
		NotificationController.show(data.text, data.style, if type(data.rarity) == "number" then data.rarity else nil)
	end)
end

return NotificationController
