--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataSchema = require(ServerScriptService.Server.Systems.Persistence.PlayerDataSchema)
local PlayerRecords = require(ServerScriptService.Tests.fixtures.PlayerRecords)

local function migrated(record: any): PlayerDataSchema.PlayerData
	local ok, result = PlayerDataSchema.migrate(record.data, record.schemaVersion)
	assert(ok, result)
	return result :: PlayerDataSchema.PlayerData
end

return function()
	describe("PlayerDataSchema", function()
		it("produces valid, independent defaults", function()
			expect((PlayerDataSchema.validate(PlayerDataSchema.defaults()))).to.equal(true)
			local a = PlayerDataSchema.defaults()
			a.coins = 99
			a.starlings[1] = { rarity = 1, shiny = false }
			expect(PlayerDataSchema.defaults().coins).to.equal(0)
			expect(#PlayerDataSchema.defaults().starlings).to.equal(0)
		end)

		it("treats missing data as a new player", function()
			local ok, data = PlayerDataSchema.migrate(nil, nil)
			expect(ok).to.equal(true)
			expect((data :: PlayerDataSchema.PlayerData).zoneTier).to.equal(1)
		end)

		it("migrates v1 records through v2 to v3, keeping coins", function()
			local data = migrated(PlayerRecords.legacyV1())
			expect(data.coins).to.equal(42)
			expect(data.stats.sessions).to.equal(0)
			expect(data.zoneTier).to.equal(1)
			expect(#data.starlings).to.equal(0)
			expect(data.upgrades.carry).to.equal(0)
		end)

		it("migrates v2 records to v3, keeping coins and stats", function()
			local data = migrated(PlayerRecords.legacyV2())
			expect(data.coins).to.equal(1234)
			expect(data.stats.collectiblesCollected).to.equal(56)
			expect(data.stats.sessions).to.equal(7)
			expect(data.stats.shardsDelivered).to.equal(0)
			expect(data.vault).to.equal(0)
		end)

		it("never mutates the input while migrating", function()
			local record = PlayerRecords.legacyV1()
			PlayerDataSchema.migrate(record.data, record.schemaVersion)
			expect(record.data.stats).to.equal(nil)
		end)

		it("refuses data from a newer schema or with a bad version", function()
			local future = PlayerRecords.futureVersion()
			local ok, reason = PlayerDataSchema.migrate(future.data, future.schemaVersion)
			expect(ok).to.equal(false)
			expect(string.find(reason :: string, "newer", 1, true) ~= nil).to.equal(true)
			expect((PlayerDataSchema.migrate({ coins = 1 }, nil))).to.equal(false)
			expect((PlayerDataSchema.migrate({ coins = 1 }, 1.5))).to.equal(false)
		end)

		it("rejects invalid currency", function()
			expect((PlayerDataSchema.migrate(PlayerRecords.corruptCoins().data, 2))).to.equal(false)
			local data = PlayerDataSchema.defaults()
			data.coins = 0 / 0
			expect((PlayerDataSchema.validate(data))).to.equal(false)
			data.coins = 2 ^ 60
			expect((PlayerDataSchema.validate(data))).to.equal(false)
		end)

		it("rejects out-of-range progression", function()
			local data = PlayerDataSchema.defaults()
			data.zoneTier = 0
			expect((PlayerDataSchema.validate(data))).to.equal(false)
			data = PlayerDataSchema.defaults()
			data.upgrades.speed = 11
			expect((PlayerDataSchema.validate(data))).to.equal(false)
			data = PlayerDataSchema.defaults()
			data.upgrades.magnet = -1
			expect((PlayerDataSchema.validate(data))).to.equal(false)
		end)

		it("rejects malformed or oversized Starling lists", function()
			local data = PlayerDataSchema.defaults()
			data.starlings = { { rarity = 9, shiny = false } }
			expect((PlayerDataSchema.validate(data))).to.equal(false)
			data.starlings = { { rarity = 1, shiny = "yes" :: any } }
			expect((PlayerDataSchema.validate(data))).to.equal(false)
			data.starlings = { [2] = { rarity = 1, shiny = false } } :: any
			expect((PlayerDataSchema.validate(data))).to.equal(false)
			local tooMany = {}
			for _ = 1, PlayerDataSchema.MAX_STARLINGS + 1 do
				table.insert(tooMany, { rarity = 1, shiny = false })
			end
			data.starlings = tooMany
			expect((PlayerDataSchema.validate(data))).to.equal(false)
		end)
	end)
end
