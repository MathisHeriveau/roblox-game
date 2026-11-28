--!strict
--[[
	ZoneAnnouncer: which zone changes deserve the zone banner.

	Regression: the banner announced "COMET PLAZA" every time a character respawned at its base
	(the tracker kept the zone the previous character died in), covering the base sign.
]]

local StarterPlayer = game:GetService("StarterPlayer")

local ZoneAnnouncer = require(StarterPlayer.StarterPlayerScripts.Client.Hud.ZoneAnnouncer)

return function()
	describe("ZoneAnnouncer:observe", function()
		it("stays silent for the zone a character spawns in, respawns included (regression)", function()
			local announcer = ZoneAnnouncer.new()
			expect(announcer:observe(0)).to.equal(nil)
			expect(announcer:observe(1)).to.equal(1)
			-- Dies in the Meadow, respawns at its base in the plaza.
			announcer:reset()
			expect(announcer:observe(0)).to.equal(nil)
			expect(announcer:observe(0)).to.equal(nil)
		end)

		it("announces each zone change once, walking home included", function()
			local announcer = ZoneAnnouncer.new()
			expect(announcer:observe(1)).to.equal(nil)
			expect(announcer:observe(1)).to.equal(nil)
			expect(announcer:observe(2)).to.equal(2)
			expect(announcer:observe(2)).to.equal(nil)
			expect(announcer:observe(1)).to.equal(1)
			expect(announcer:observe(0)).to.equal(0)
		end)

		it("ignores positions beyond the world without forgetting the current zone", function()
			local announcer = ZoneAnnouncer.new()
			expect(announcer:observe(nil)).to.equal(nil)
			expect(announcer:observe(1)).to.equal(nil)
			expect(announcer:observe(nil)).to.equal(nil)
			expect(announcer:observe(1)).to.equal(nil)
			expect(announcer:observe(3)).to.equal(3)
		end)
	end)

	describe("ZoneAnnouncer.describe", function()
		it("names the hub and the zones, and warns about locked zones", function()
			local hub = ZoneAnnouncer.describe(0, 1)
			expect(string.find(hub.title, "COMET PLAZA", 1, true) ~= nil).to.equal(true)

			local meadow = ZoneAnnouncer.describe(1, 1)
			expect(string.find(meadow.title, "STARTING MEADOW", 1, true) ~= nil).to.equal(true)
			expect(string.find(meadow.subtitle, "Locked", 1, true)).to.equal(nil)

			local lava = ZoneAnnouncer.describe(3, 1)
			expect(string.find(lava.subtitle, "Locked", 1, true) ~= nil).to.equal(true)
			-- Unknown unlock state (no PlayerState yet): no false "locked" warning.
			expect(string.find(ZoneAnnouncer.describe(3, nil).subtitle, "Locked", 1, true)).to.equal(nil)
		end)

		-- Playtest 2026-11-28: walking into a 🔒 shard did nothing at all, with no hint why.
		it("tells a player next to a locked shard which zone to buy and for how much", function()
			local desert = ZoneAnnouncer.lockedShardHint(2, 1)
			expect(string.find(desert, "Crystal Desert shards: unlock the zone in the SHOP", 1, true) ~= nil).to.equal(
				true
			)
			expect(string.find(desert, "400", 1, true) ~= nil).to.equal(true)

			local lavaTooFar = ZoneAnnouncer.lockedShardHint(3, 1)
			expect(string.find(lavaTooFar, "unlock Crystal Desert first", 1, true) ~= nil).to.equal(true)

			local lavaNext = ZoneAnnouncer.lockedShardHint(3, 2)
			expect(string.find(lavaNext, "Lava Fields shards: unlock the zone", 1, true) ~= nil).to.equal(true)
			expect(string.find(lavaNext, "8K", 1, true) ~= nil).to.equal(true)
		end)

		it("keeps texts short enough for the compact banner", function()
			for tier = 0, 4 do
				local text = ZoneAnnouncer.describe(tier, 0)
				local length = utf8.len(text.subtitle) or math.huge
				expect(length <= 48).to.equal(true)
			end
		end)
	end)
end
