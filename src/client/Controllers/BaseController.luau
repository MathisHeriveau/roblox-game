--!strict
--[[
	BaseController — the local player's side of bases and raids:
	  - finds the player's own plot (OwnerUserId attribute set by the server);
	  - hides prompts that make no sense for this player (Steal on their own Starlings, Lock on
	    other people's consoles) — purely cosmetic, the server enforces every rule;
	  - shows the base lock status pill with its countdown, pulsing red when the base is open.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.UI.Create)
local Format = require(game:GetService("ReplicatedStorage").Shared.Game.Format)
local Theme = require(script.Parent.Parent.UI.Theme)

local BaseController = {
	name = "BaseController",
}

local gui: ScreenGui
local scale: UIScale
local pill: Frame
local pillText: TextLabel
local pillStroke: UIStroke
local hooked: { [ProximityPrompt]: boolean } = {}

local function ownPlot(): Model?
	local bases = Workspace:FindFirstChild("Bases")
	if bases == nil then
		return nil
	end
	for _, plot in bases:GetChildren() do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
			return plot
		end
	end
	return nil
end

-- Keeps a prompt disabled locally, even when the server toggles it later.
local function suppress(prompt: ProximityPrompt)
	prompt.Enabled = false
	if hooked[prompt] then
		return
	end
	hooked[prompt] = true
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if hooked[prompt] and prompt.Enabled then
			prompt.Enabled = false
		end
	end)
end

local function release(prompt: ProximityPrompt)
	hooked[prompt] = nil
end

local function refreshPrompts()
	local bases = Workspace:FindFirstChild("Bases")
	if bases == nil then
		return
	end
	local mine = ownPlot()
	for _, plot in bases:GetChildren() do
		for _, prompt in plot:GetDescendants() do
			if prompt:IsA("ProximityPrompt") then
				local isMine = plot == mine
				if (prompt.Name == "StealPrompt" and isMine) or (prompt.Name == "LockPrompt" and not isMine) then
					suppress(prompt)
				elseif hooked[prompt] then
					-- Ownership changed: give control back to the server-replicated value.
					release(prompt)
				end
			end
		end
	end
end

local function updatePill()
	local plot = ownPlot()
	if plot == nil then
		pill.Visible = false
		return
	end
	pill.Visible = true
	local lockedUntil = plot:GetAttribute("LockedUntil")
	local remaining = if type(lockedUntil) == "number" then lockedUntil - Workspace:GetServerTimeNow() else 0
	if remaining > 0 then
		pillText.Text = `🔒 BASE LOCKED {Format.duration(remaining)}`
		pillStroke.Color = Theme.Color.Blue
		pill.BackgroundColor3 = Theme.Color.Panel
	else
		pillText.Text = "🔓 BASE OPEN · lock it at your console!"
		pillStroke.Color = Theme.Color.Red
		-- Gentle pulse to draw attention.
		local pulse = (math.sin(os.clock() * 5) + 1) / 2
		pill.BackgroundColor3 = Theme.Color.Panel:Lerp(Theme.Color.RedDark, pulse * 0.6)
	end
end

function BaseController.init(_self: any)
	scale = Instance.new("UIScale")
	pillText = Create("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Font.Body,
		Text = "",
		TextColor3 = Theme.Color.Text,
		TextScaled = true,
	}) :: TextLabel
	Theme.textOutline(pillText, 2)
	pill = Create("Frame", {
		Name = "LockPill",
		Position = UDim2.fromOffset(18, 172),
		Size = UDim2.fromOffset(300, 40),
		BackgroundColor3 = Theme.Color.Panel,
		Visible = false,
	}, { pillText }) :: Frame
	Theme.corner(pill)
	pillStroke = Theme.border(pill, 3)
	Theme.padding(pill, 7)
	gui = Create("ScreenGui", {
		Name = "BaseStatus",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	}, { scale :: Instance, pill }) :: ScreenGui
end

function BaseController.start(_self: any)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local camera = Workspace.CurrentCamera
	if camera then
		local function rescale()
			scale.Scale = Theme.scaleFor(camera.ViewportSize)
		end
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		rescale()
	end

	local bases = Workspace:WaitForChild("Bases", 30)
	if bases then
		for _, plot in bases:GetChildren() do
			plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refreshPrompts)
		end
		bases.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("ProximityPrompt") then
				refreshPrompts()
			end
		end)
	end
	refreshPrompts()

	while true do
		updatePill()
		task.wait(0.1)
	end
end

return BaseController
