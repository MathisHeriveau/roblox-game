--!strict
--[[
	Integration: SessionStore + PlayerDataSchema + InMemoryStore.

	Simulates several servers (distinct job ids) sharing one store, with a controllable clock,
	to prove the session-locking protocol prevents data loss and duplication.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Persistence = ServerScriptService.Server.Systems.Persistence
local InMemoryStore = require(Persistence.InMemoryStore)
local PlayerDataSchema = require(Persistence.PlayerDataSchema)
local PlayerRecords = require(ServerScriptService.Tests.fixtures.PlayerRecords)
local SessionStore = require(Persistence.SessionStore)

local KEY = "player_1"
local LOCK_EXPIRY = 1800

return function()
	local now = 1000
	local sleeps = 0
	local store: InMemoryStore.InMemoryStore

	local function server(jobId: string, maxLoadAttempts: number?): SessionStore.SessionStore
		return SessionStore.new({
			store = store :: any,
			jobId = jobId,
			lockExpirySeconds = LOCK_EXPIRY,
			maxLoadAttempts = maxLoadAttempts or 3,
			retryDelaySeconds = 1,
			now = function()
				return now
			end,
			sleep = function(_seconds: number)
				sleeps += 1
			end,
		})
	end

	beforeEach(function()
		now = 1000
		sleeps = 0
		store = InMemoryStore.new()
	end)

	describe("load", function()
		it("creates defaults for a new player and locks the record", function()
			local ok, data = server("A"):load(KEY)
			expect(ok).to.equal(true)
			expect(data.coins).to.equal(0)
			local _, record = store:read(KEY)
			expect(record.session.jobId).to.equal("A")
			expect(record.schemaVersion).to.equal(PlayerDataSchema.VERSION)
		end)

		it("migrates a legacy record on load and persists the upgrade", function()
			store:seed(KEY, PlayerRecords.legacyV1())
			local ok, data = server("A"):load(KEY)
			expect(ok).to.equal(true)
			expect(data.coins).to.equal(42)
			local _, record = store:read(KEY)
			expect(record.schemaVersion).to.equal(PlayerDataSchema.VERSION)
			expect(record.data.stats).to.be.ok()
		end)

		it("refuses while another live server holds the lock, after retrying", function()
			store:seed(KEY, PlayerRecords.lockedBy("B", now - 10))
			local ok, reason = server("A", 3):load(KEY)
			expect(ok).to.equal(false)
			expect(reason).to.equal("Locked")
			expect(sleeps).to.equal(2)
		end)

		it("takes over an expired lock from a crashed server", function()
			store:seed(KEY, PlayerRecords.lockedBy("Crashed", now - LOCK_EXPIRY - 1))
			local ok, data = server("A"):load(KEY)
			expect(ok).to.equal(true)
			expect(data.coins).to.equal(7)
		end)

		it("never overwrites corrupt or newer-schema data", function()
			store:seed(KEY, PlayerRecords.corruptCoins())
			local ok, reason = server("A"):load(KEY)
			expect(ok).to.equal(false)
			expect(reason).to.equal("Corrupt")
			local _, record = store:read(KEY)
			expect(record.data.coins).to.equal(-3.5)
			expect(record.session).to.equal(nil)

			store:seed(KEY, PlayerRecords.futureVersion())
			local okFuture, reasonFuture = server("A"):load(KEY)
			expect(okFuture).to.equal(false)
			expect(reasonFuture).to.equal("Corrupt")
			local _, futureRecord = store:read(KEY)
			expect(futureRecord.schemaVersion).to.equal(999)
		end)

		it("retries through transient store outages", function()
			store:failNext(2)
			local ok = server("A", 3):load(KEY)
			expect(ok).to.equal(true)
			expect(sleeps).to.equal(2)
		end)

		it("reports Unavailable when the store stays down", function()
			store:failNext(10)
			local ok, reason = server("A", 3):load(KEY)
			expect(ok).to.equal(false)
			expect(reason).to.equal("Unavailable")
		end)
	end)

	describe("save", function()
		it("persists data while keeping the lock, then releases it", function()
			local a = server("A")
			local _, data = a:load(KEY)
			data.coins = 10
			expect((a:save(KEY, data, false))).to.equal(true)
			local _, kept = store:read(KEY)
			expect(kept.data.coins).to.equal(10)
			expect(kept.session.jobId).to.equal("A")

			expect((a:save(KEY, data, true))).to.equal(true)
			local _, released = store:read(KEY)
			expect(released.session).to.equal(nil)
		end)

		it("hands the session over cleanly between servers", function()
			local a, b = server("A"), server("B", 1)
			local _, data = a:load(KEY)
			data.coins = 5
			expect((b:load(KEY))).to.equal(false)
			a:save(KEY, data, true)
			local ok, loaded = b:load(KEY)
			expect(ok).to.equal(true)
			expect(loaded.coins).to.equal(5)
		end)

		it("cannot overwrite data after losing the lock (no rollback / dupes)", function()
			local a, b = server("A"), server("B")
			local _, staleData = a:load(KEY)
			-- Server A hangs; its lock expires and B takes over and progresses.
			now += LOCK_EXPIRY + 1
			local _, fresh = b:load(KEY)
			fresh.coins = 500
			b:save(KEY, fresh, false)

			staleData.coins = 1
			local ok, failure = a:save(KEY, staleData, true)
			expect(ok).to.equal(false)
			expect(failure).to.equal("LockLost")
			local _, record = store:read(KEY)
			expect(record.data.coins).to.equal(500)
		end)

		it("refuses to save invalid data", function()
			local a = server("A")
			local _, data = a:load(KEY)
			data.coins = 0 / 0
			local ok, failure = a:save(KEY, data, false)
			expect(ok).to.equal(false)
			expect(failure).to.equal("Invalid")
		end)
	end)
end
