--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataSchema = require(ServerScriptService.Server.Systems.Persistence.PlayerDataSchema)
local PlayerRecords = require(ServerScriptService.Tests.fixtures.PlayerRecords)

return function()
	describe("PlayerDataSchema", function()
		it("produces valid defaults", function()
			expect((PlayerDataSchema.validate(PlayerDataSchema.defaults()))).to.equal(true)
		end)

		it("returns fresh defaults each time (no shared mutable state)", function()
			local a = PlayerDataSchema.defaults()
			a.coins = 99
			expect(PlayerDataSchema.defaults().coins).to.equal(0)
		end)

		it("treats missing data as a new player", function()
			local ok, data = PlayerDataSchema.migrate(nil, nil)
			expect(ok).to.equal(true)
			expect((data :: PlayerDataSchema.PlayerData).coins).to.equal(0)
		end)

		it("migrates v1 records to the current version, preserving values", function()
			local record = PlayerRecords.legacyV1()
			local ok, result = PlayerDataSchema.migrate(record.data, record.schemaVersion)
			expect(ok).to.equal(true)
			local data = result :: PlayerDataSchema.PlayerData
			expect(data.coins).to.equal(42)
			expect(data.stats.collectiblesCollected).to.equal(0)
			expect(data.stats.sessions).to.equal(0)
		end)

		it("never mutates the input while migrating", function()
			local record = PlayerRecords.legacyV1()
			PlayerDataSchema.migrate(record.data, record.schemaVersion)
			expect(record.data.stats).to.equal(nil)
		end)

		it("refuses data from a newer schema", function()
			local record = PlayerRecords.futureVersion()
			local ok, reason = PlayerDataSchema.migrate(record.data, record.schemaVersion)
			expect(ok).to.equal(false)
			expect(string.find(reason :: string, "newer", 1, true) ~= nil).to.equal(true)
		end)

		it("refuses records with a missing or invalid version", function()
			expect((PlayerDataSchema.migrate({ coins = 1 }, nil))).to.equal(false)
			expect((PlayerDataSchema.migrate({ coins = 1 }, 0))).to.equal(false)
			expect((PlayerDataSchema.migrate({ coins = 1 }, 1.5))).to.equal(false)
		end)

		it("rejects invalid values", function()
			local record = PlayerRecords.corruptCoins()
			expect((PlayerDataSchema.migrate(record.data, record.schemaVersion))).to.equal(false)
			local data = PlayerDataSchema.defaults()
			data.coins = 0 / 0
			expect((PlayerDataSchema.validate(data))).to.equal(false)
			data.coins = 2 ^ 60
			expect((PlayerDataSchema.validate(data))).to.equal(false)
		end)
	end)
end
