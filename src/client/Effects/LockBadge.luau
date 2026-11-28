--!strict
--[[
	LockBadge — the "🔒 Crystal Desert" label floating over a shard of a zone the player has not
	unlocked (AmbientController adds and removes it).

	A BillboardGui only renders when adorned to a part or attachment: parented to the shard Model
	with no Adornee, the badge never showed (playtest 2026-11-28). `adorn` points it at the shard's
	crystal (PrimaryPart), which can replicate after the model itself, so callers retry until it
	returns true.

	API: LockBadge.new(text) -> BillboardGui, LockBadge.adorn(badge, model) -> boolean
]]

local Theme = require(script.Parent.Parent.UI.Theme)

local LockBadge = {}

function LockBadge.new(text: string): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "LockBadge"
	gui.Size = UDim2.fromScale(7, 1.6)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	-- Not AlwaysOnTop: in Studio that layer never showed up (checked with screen captures), while
	-- a normal billboard 4.5 studs above the crystal reads fine and hides behind hills naturally.
	gui.AlwaysOnTop = false
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.Font.Body
	label.TextScaled = true
	label.TextColor3 = Theme.Color.Text
	label.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Theme.Color.Outline
	stroke.Parent = label
	label.Parent = gui
	return gui
end

-- Adorns `badge` to the shard's crystal. False while the crystal has not replicated yet.
function LockBadge.adorn(badge: BillboardGui, model: Model): boolean
	local crystal = model.PrimaryPart
	if crystal == nil then
		return false
	end
	if badge.Adornee ~= crystal then
		badge.Adornee = crystal
	end
	return true
end

return table.freeze(LockBadge)
