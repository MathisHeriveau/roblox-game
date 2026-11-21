--!strict
--[[
	Vfx — client-only visual effects: falling meteors timed to land exactly when the server makes
	the shard collectable, impact flashes, shockwaves, the comet target marker and camera shake.

	Everything here is cosmetic and local (parented under Workspace.LocalEffects on this client).
	Gameplay never depends on it.
]]

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Settings = require(script.Parent.Parent.Settings)
local Sfx = require(script.Parent.Sfx)

local METEOR_COLOR = Color3.fromRGB(255, 140, 40)
-- Meteors come from the same corner of the sky as in the key art.
local METEOR_DIRECTION = Vector3.new(-0.55, 1, 0.35).Unit

local Vfx = {}

local folder: Folder? = nil
local function container(): Folder
	local current = folder
	if current and current.Parent then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = "LocalEffects"
	created.Parent = Workspace
	folder = created
	return created
end

local function effectPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = container()
	return part
end

function Vfx.shockwave(position: Vector3, color: Color3, radius: number)
	if not Settings.get("effects") then
		return
	end
	local ring = effectPart({
		Name = "Shockwave",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 2, 2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.15,
	})
	TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.7)
end

function Vfx.impact(position: Vector3, color: Color3, scale: number)
	-- With effects off (⚙️ Settings) the impact is still heard, just not flashed.
	if not Settings.get("effects") then
		Sfx.playAt(Sfx.IMPACT, position, math.min(1, 0.35 + 0.25 * scale))
		return
	end
	local flash = effectPart({
		Name = "Flash",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2 * scale,
		CFrame = CFrame.new(position),
		Color = color,
		Transparency = 0.1,
	})
	TweenService:Create(flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 16 * scale,
		Transparency = 1,
	}):Play()
	Debris:AddItem(flash, 0.6)
	Vfx.shockwave(position, color, 14 * scale)
	Sfx.playAt(Sfx.IMPACT, position, math.min(1, 0.35 + 0.25 * scale))
end

--[[
	Launches a meteor that lands at `position` exactly at server time `impactAt`, after a flight of
	`travel` seconds. Late events (lag) shorten the flight; very late ones just play the impact.
]]
function Vfx.meteor(position: Vector3, color: Color3, impactAt: number, travel: number, scale: number)
	local function launch()
		local remaining = impactAt - Workspace:GetServerTimeNow()
		if remaining <= 0.05 then
			Vfx.impact(position, color, scale)
			return
		end
		local distance = 40 + 230 * math.min(1, remaining / travel)
		local rock = effectPart({
			Name = "Meteor",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 3 * scale,
			CFrame = CFrame.new(position + METEOR_DIRECTION * distance),
			Color = METEOR_COLOR,
		})
		local fire = Instance.new("Fire")
		fire.Size = 7 * scale
		fire.Heat = 18
		fire.Color = METEOR_COLOR
		fire.SecondaryColor = color
		fire.Parent = rock

		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0, 1.2 * scale, 0)
		top.Parent = rock
		local bottom = Instance.new("Attachment")
		bottom.Position = Vector3.new(0, -1.2 * scale, 0)
		bottom.Parent = rock
		local trail = Instance.new("Trail")
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Lifetime = 0.5
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Color = ColorSequence.new(METEOR_COLOR, color)
		trail.Transparency = NumberSequence.new(0.05, 1)
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.Parent = rock

		local light = Instance.new("PointLight")
		light.Color = METEOR_COLOR
		light.Range = 18 * scale
		light.Brightness = 3
		light.Parent = rock

		local tween = TweenService:Create(rock, TweenInfo.new(remaining, Enum.EasingStyle.Linear), {
			CFrame = CFrame.new(position),
		})
		tween.Completed:Connect(function()
			rock:Destroy()
			Vfx.impact(position, color, scale)
		end)
		tween:Play()
	end

	local startIn = impactAt - travel - Workspace:GetServerTimeNow()
	if startIn > 0 then
		task.delay(startIn, launch)
	else
		launch()
	end
end

-- Pulsing danger ring + light column at a comet's target. Returns a function that removes it.
function Vfx.targetMarker(position: Vector3, color: Color3, radius: number): () -> ()
	local ring = effectPart({
		Name = "CometTarget",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.35,
	})
	local column = effectPart({
		Name = "CometColumn",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(160, radius * 0.6, radius * 0.6),
		CFrame = CFrame.new(position + Vector3.new(0, 80, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.8,
	})
	local pulse = TweenService:Create(
		ring,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Size = Vector3.new(0.3, radius * 1.4, radius * 1.4), Transparency = 0.6 }
	)
	pulse:Play()
	return function()
		pulse:Cancel()
		ring:Destroy()
		column:Destroy()
	end
end

local shaking = false
function Vfx.cameraShake(intensity: number, duration: number)
	local camera = Workspace.CurrentCamera
	if camera == nil or shaking or not Settings.get("effects") then
		return
	end
	shaking = true
	local elapsed = 0
	RunService:BindToRenderStep("CometRaidersShake", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		elapsed += dt
		if elapsed >= duration then
			RunService:UnbindFromRenderStep("CometRaidersShake")
			shaking = false
			return
		end
		local power = intensity * (1 - elapsed / duration)
		camera.CFrame = camera.CFrame
			* CFrame.new((math.random() - 0.5) * power, (math.random() - 0.5) * power, 0)
			* CFrame.Angles(0, 0, (math.random() - 0.5) * power * 0.02)
	end)
end

return table.freeze(Vfx)
