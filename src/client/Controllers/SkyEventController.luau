--!strict
--[[
	SkyEventController — makes the sky events felt: countdowns, the comet banner and target marker,
	meteor/comet visuals timed on the server clock, bump shockwaves and camera shake.
	Purely cosmetic: shards exist and are collected server-side regardless.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClientNet = require(ReplicatedStorage.Shared.Net.ClientNet)
local Create = require(script.Parent.Parent.UI.Create)
local EventBanner = require(script.Parent.Parent.UI.Components.EventBanner)
local Format = require(ReplicatedStorage.Shared.Game.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local Theme = require(script.Parent.Parent.UI.Theme)
local Vfx = require(script.Parent.Parent.Effects.Vfx)

local events = GameConfig.Events

local SkyEventController = {
	name = "SkyEventController",
}

type CometInfo = {
	position: Vector3,
	impactAt: number,
	zoneName: string,
	removeMarker: () -> (),
}

local gui: ScreenGui
local scale: UIScale
local banner: EventBanner.EventBanner
local comet: CometInfo? = nil

local function rarityColor(value: unknown): Color3
	return if Rarities.isValid(value) then Rarities.get(value :: number).color else Theme.Color.Gold
end

local function localRootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function clearComet()
	local current = comet
	if current then
		current.removeMarker()
	end
	comet = nil
	banner.hideComet()
end

local function onWorldEvent(payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local event = payload :: any
	if event.kind == "meteors" and type(event.impacts) == "table" and type(event.impactAt) == "number" then
		local count = 0
		for _, impact in event.impacts do
			count += 1
			if count > 40 then
				break
			end
			if type(impact) == "table" and typeof(impact.position) == "Vector3" then
				Vfx.meteor(impact.position, rarityColor(impact.rarity), event.impactAt, events.ImpactDelaySeconds, 1)
			end
		end
	elseif
		event.kind == "cometWarning"
		and typeof(event.position) == "Vector3"
		and type(event.impactAt) == "number"
		and type(event.zoneName) == "string"
	then
		clearComet()
		local color = rarityColor(event.rarity)
		comet = {
			position = event.position,
			impactAt = event.impactAt,
			zoneName = string.sub(event.zoneName, 1, 40),
			removeMarker = Vfx.targetMarker(event.position, Theme.Color.Red, 16),
		}
		Vfx.meteor(event.position, color, event.impactAt, events.CometImpactDelaySeconds, 2.6)
	elseif event.kind == "cometImpact" and typeof(event.position) == "Vector3" then
		local here = localRootPosition()
		if here and (here - event.position).Magnitude < 220 then
			Vfx.cameraShake(1.4, 0.9)
		end
		clearComet()
	elseif event.kind == "bump" and typeof(event.position) == "Vector3" then
		Vfx.shockwave(event.position, Theme.Color.Gold, 10)
		Sfx.playAt(Sfx.BUMP, event.position, 0.7)
	end
end

local function countdown(attribute: string): number?
	local at = Workspace:GetAttribute(attribute)
	if type(at) ~= "number" then
		return nil
	end
	return at - Workspace:GetServerTimeNow()
end

local function updateTexts()
	local meteorIn = countdown("NextMeteorAt")
	local cometIn = countdown("NextCometAt")
	local meteorText = if meteorIn == nil
		then ""
		elseif meteorIn > 0 then `☄️ Meteor shower in {Format.duration(meteorIn)}`
		else "☄️ Meteor shower!"
	local cometText = if cometIn == nil
		then ""
		elseif cometIn > 0 then `🌠 Next comet in {Format.duration(cometIn)}`
		else ""
	banner.setCountdowns(meteorText, cometText)

	local current = comet
	if current then
		local remaining = current.impactAt - Workspace:GetServerTimeNow()
		if remaining < -4 then
			clearComet()
		else
			banner.showComet(
				"COMET INCOMING!",
				if remaining > 0
					then `Crash in {Format.duration(remaining)} · {current.zoneName}`
					else `Crashed in {current.zoneName}: grab the core!`
			)
		end
	end
end

function SkyEventController.init(_self: any)
	scale = Instance.new("UIScale")
	banner = EventBanner.new()
	banner.root.Position = UDim2.new(0.5, 0, 0, 10)
	gui = Create("ScreenGui", {
		Name = "SkyEvents",
		ResetOnSpawn = false,
		DisplayOrder = 4,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	}, { scale :: Instance, banner.root }) :: ScreenGui
end

function SkyEventController.start(_self: any)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local camera = Workspace.CurrentCamera
	if camera then
		local function rescale()
			scale.Scale = Theme.scaleFor(camera.ViewportSize)
		end
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		rescale()
	end
	ClientNet.onEvent("WorldEvent", onWorldEvent)
	while true do
		updateTexts()
		task.wait(0.25)
	end
end

return SkyEventController
