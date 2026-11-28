--!strict
--[[
	LockBadge: the 🔒 label over shards of locked zones.

	Regression (playtest 2026-11-28): the badge was parented to the shard Model without an Adornee,
	and a BillboardGui only renders on a part or attachment, so no player ever saw a 🔒 badge.
]]

local StarterPlayer = game:GetService("StarterPlayer")

local LockBadge = require(StarterPlayer.StarterPlayerScripts.Client.Effects.LockBadge)

local function shard(withCrystal: boolean): (Model, Part?)
	local model = Instance.new("Model")
	if not withCrystal then
		return model, nil
	end
	local crystal = Instance.new("Part")
	crystal.Name = "Crystal"
	crystal.Parent = model
	model.PrimaryPart = crystal
	return model, crystal
end

return function()
	describe("LockBadge", function()
		it("builds a readable badge with the zone name", function()
			local badge = LockBadge.new("🔒 Crystal Desert")
			local label = badge:FindFirstChild("Text") :: TextLabel
			expect(label).to.be.ok()
			expect(label.Text).to.equal("🔒 Crystal Desert")
			-- AlwaysOnTop billboards did not render in Studio: a plain world billboard does.
			expect(badge.AlwaysOnTop).to.equal(false)
		end)

		it("adorns the badge to the shard's crystal so it renders", function()
			local model, crystal = shard(true)
			local badge = LockBadge.new("🔒 Lava Fields")
			badge.Parent = model
			expect(LockBadge.adorn(badge, model)).to.equal(true)
			expect(badge.Adornee).to.equal(crystal)
		end)

		it("reports a crystal that has not replicated yet, so the caller retries", function()
			local model = shard(false)
			local badge = LockBadge.new("🔒 Lava Fields")
			expect(LockBadge.adorn(badge, model)).to.equal(false)
			expect(badge.Adornee).to.equal(nil)
		end)
	end)
end
