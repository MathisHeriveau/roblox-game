--!strict
--[[
	Sfx — sound effects using sounds that ship with every Roblox client (rbxasset://), so the game
	needs no uploaded audio. Positional sounds fade with distance.
]]

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Settings = require(script.Parent.Parent.Settings)

local Sfx = {
	IMPACT = "rbxasset://sounds/impact_explosion_03.mp3",
	PICKUP = "rbxasset://sounds/action_jump_land.mp3",
	CLICK = "rbxasset://sounds/volume_slider.ogg",
	BUMP = "rbxasset://sounds/action_jump.mp3",
	HURT = "rbxasset://sounds/ouch.ogg",
}

-- Sound effects can be muted in ⚙️ Settings.
local function muted(): boolean
	return not Settings.get("sounds")
end

function Sfx.play(soundId: string, volume: number?)
	if muted() then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 6)
end

function Sfx.playAt(soundId: string, position: Vector3, volume: number?)
	if muted() then
		return
	end
	local holder = Instance.new("Part")
	holder.Name = "SoundEmitter"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(position)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.6
	sound.RollOffMaxDistance = 400
	sound.Parent = holder
	holder.Parent = Workspace
	sound:Play()
	Debris:AddItem(holder, 6)
end

return table.freeze(Sfx)
