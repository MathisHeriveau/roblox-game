--!strict
--[[
	Motion — the UI's candy feel, in one place:

	  Motion.popIn(scale)        a modal (or anything with a UIScale) bounces open to its size
	  Motion.bindPress(button)   squash on press, swell a little on hover, settle on release
	  Motion.pulse(target, on)   an attention pulse (badges "!") while `on`

	Cosmetic only: every call is protected, so a failed tween (or a headless test runtime without
	TweenService) never breaks the UI, it just does not animate.
]]

local TweenService = game:GetService("TweenService")

local Motion = {}

type Style = "pop" | "press" | "release" | "pulse"

-- Built on first use (TweenInfo does not exist in the headless test runtime).
local styles: { [Style]: TweenInfo }? = nil

local function style(name: Style): TweenInfo?
	if styles == nil then
		local ok, built = pcall(function(): { [Style]: TweenInfo }
			return {
				pop = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				press = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				release = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				pulse = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			}
		end)
		styles = if ok then built else {}
	end
	return (styles :: { [Style]: TweenInfo })[name]
end

local pulses: { [Instance]: Tween } = setmetatable({}, { __mode = "k" }) :: any

local function play(target: Instance, name: Style, goal: { [string]: any }): Tween?
	local info = style(name)
	if info == nil then
		return nil
	end
	local ok, tween = pcall(function()
		local created = TweenService:Create(target, info, goal)
		created:Play()
		return created
	end)
	return if ok then tween else nil
end

-- Bounces `scale` from a bit smaller up to its current value (its resting size).
function Motion.popIn(scale: UIScale)
	local target = scale.Scale
	scale.Scale = target * 0.82
	if play(scale, "pop", { Scale = target }) == nil then
		scale.Scale = target
	end
end

local function pressScale(button: GuiObject): UIScale
	local existing = button:FindFirstChild("PressScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = "PressScale"
	scale.Parent = button
	return scale
end

-- Press / hover feedback. Skips buttons that already own a UIScale (e.g. the pulsing PLAY), since
-- a GuiObject only honours one UIScale.
function Motion.bindPress(button: GuiButton)
	local other = button:FindFirstChildOfClass("UIScale")
	if other and other.Name ~= "PressScale" then
		return
	end
	pcall(function()
		local scale = pressScale(button)
		button.MouseEnter:Connect(function()
			play(scale, "release", { Scale = 1.05 })
		end)
		button.MouseLeave:Connect(function()
			play(scale, "release", { Scale = 1 })
		end)
		button.MouseButton1Down:Connect(function()
			play(scale, "press", { Scale = 0.9 })
		end)
		button.MouseButton1Up:Connect(function()
			play(scale, "release", { Scale = 1.05 })
		end)
	end)
end

-- Starts or stops a gentle size pulse on `target` (through its own UIScale).
function Motion.pulse(target: GuiObject, on: boolean)
	local running = pulses[target]
	if running then
		running:Cancel()
		pulses[target] = nil
	end
	local scale = target:FindFirstChild("PulseScale") :: UIScale?
	if not on then
		if scale then
			scale.Scale = 1
		end
		return
	end
	if scale == nil then
		local created = Instance.new("UIScale")
		created.Name = "PulseScale"
		created.Parent = target
		scale = created
	end
	local tween = play(scale :: UIScale, "pulse", { Scale = 1.25 })
	if tween then
		pulses[target] = tween
	end
end

return table.freeze(Motion)
