--!strict
--[[
	NotificationController — stacked toast notifications (server Notify + local messages).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClientNet = require(ReplicatedStorage.Shared.Net.ClientNet)
local Create = require(script.Parent.Parent.UI.Create)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local MAX_TOASTS = 4
local LIFETIME_SECONDS = 3.2

local STYLE_COLORS: { [string]: Color3 } = {
	info = Theme.Color.Blue,
	success = Theme.Color.Green,
	warning = Theme.Color.Gold,
	error = Theme.Color.Red,
	coins = Theme.Color.Gold,
	pickup = Theme.Color.Gold,
	rarity = Theme.Color.Purple,
}

local NotificationController = {
	name = "NotificationController",
}

local gui: ScreenGui
local holder: Frame
local scale: UIScale
local order = 0

function NotificationController.show(text: string, style: string, rarity: number?)
	local color = STYLE_COLORS[style] or Theme.Color.Blue
	if rarity and Rarities.isValid(rarity) then
		color = Rarities.get(rarity).color
	end
	order += 1
	local toast = Toast.new(text, color)
	toast.LayoutOrder = order
	toast.Parent = holder

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
	end
	task.delay(LIFETIME_SECONDS, function()
		toast:Destroy()
	end)
end

function NotificationController.init(_self: any)
	scale = Instance.new("UIScale")
	holder = Create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 190),
		Size = UDim2.fromOffset(900, 260),
		BackgroundTransparency = 1,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	}) :: Frame
	gui = Create("ScreenGui", {
		Name = "Notifications",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	}, { scale :: Instance, holder }) :: ScreenGui
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
