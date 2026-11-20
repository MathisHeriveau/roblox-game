--!strict
--[[
	SkyEventController — makes the sky events felt: countdowns, the comet banner and target marker,
	meteor/comet visuals timed on the server clock, bump shockwaves and camera shake.
	The banners live in the HUD's top-centre column (HudController.mountTop).
	Purely cosmetic: shards exist and are collected server-side regardless.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClientNet = require(ReplicatedStorage.Shared.Net.ClientNet)
local CometTracker = require(script.Parent.Parent.Hud.CometTracker)
local EventBanner = require(script.Parent.Parent.UI.Components.EventBanner)
local Format = require(ReplicatedStorage.Shared.Game.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local HudController = require(script.Parent.HudController)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local Theme = require(script.Parent.Parent.UI.Theme)
local Vfx = require(script.Parent.Parent.Effects.Vfx)

local events = GameConfig.Events

local SkyEventController = {
	name = "SkyEventController",
}

local banner: EventBanner.EventBanner
local tracker = CometTracker.new()
-- Removes the current comet's target marker (kept until the banner ends: it shows where the core is).
local removeMarker: (() -> ())? = nil

local function rarityColor(value: unknown): Color3
	return if Rarities.isValid(value) then Rarities.get(value :: number).color else Theme.Color.Gold
end

local function localRootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function clearMarker()
	local remove = removeMarker
	removeMarker = nil
	if remove then
		remove()
	end
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
		clearMarker()
		local color = rarityColor(event.rarity)
		tracker:warn(event.impactAt, string.sub(event.zoneName, 1, 40))
		removeMarker = Vfx.targetMarker(event.position, Theme.Color.Red, 16)
		Vfx.meteor(event.position, color, event.impactAt, events.CometImpactDelaySeconds, 2.6)
	elseif event.kind == "cometImpact" and typeof(event.position) == "Vector3" then
		local here = localRootPosition()
		if here and (here - event.position).Magnitude < 220 then
			Vfx.cameraShake(1.4, 0.9)
		end
		-- Not the end of the comet: the banner now calls players to the core (CometTracker).
		tracker:impact(Workspace:GetServerTimeNow())
	elseif event.kind == "raid" and typeof(event.position) == "Vector3" then
		Vfx.shockwave(event.position, rarityColor(event.rarity), 18)
		Sfx.playAt(Sfx.IMPACT, event.position, 0.5)
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

	local status = tracker:status(Workspace:GetServerTimeNow())
	if status then
		banner.showComet(status.title, status.subtitle)
	else
		clearMarker()
		banner.hideComet()
	end
end

function SkyEventController.init(_self: any)
	banner = EventBanner.new()
	HudController.mountTop(banner.countdowns, HudController.TopSlot.Countdowns)
	HudController.mountTop(banner.comet, HudController.TopSlot.Comet)
end

function SkyEventController.start(_self: any)
	ClientNet.onEvent("WorldEvent", onWorldEvent)
	while true do
		updateTexts()
		task.wait(0.25)
	end
end

return SkyEventController
