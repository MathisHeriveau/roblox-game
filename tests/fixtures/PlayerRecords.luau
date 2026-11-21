--!strict
--[[
	Persisted record fixtures for persistence tests. Each entry is a raw DataStore value exactly as
	SessionStore would find it under a key.
]]

local PlayerRecords = {}

-- A record written by schema v1 (before `stats` existed).
function PlayerRecords.legacyV1(): any
	return {
		schemaVersion = 1,
		data = { coins = 42 },
		updatedAt = 1700000000,
	}
end

-- A record written by schema v2 (before Comet Raiders progression existed).
function PlayerRecords.legacyV2(): any
	return {
		schemaVersion = 2,
		data = { coins = 1234, stats = { collectiblesCollected = 56, sessions = 7 } },
		updatedAt = 1700000000,
	}
end

-- A record written by schema v3 (before the Starling Index and daily rewards existed).
function PlayerRecords.legacyV3(): any
	return {
		schemaVersion = 3,
		data = {
			coins = 5000,
			vault = 12,
			xp = 300,
			rebirths = 1,
			zoneTier = 2,
			upgrades = { speed = 1, carry = 0, magnet = 2, slots = 0 },
			starlings = { { rarity = 2, shiny = false }, { rarity = 4, shiny = true }, { rarity = 2, shiny = false } },
			lastSeen = 1700000000,
			stats = {
				collectiblesCollected = 3,
				sessions = 9,
				shardsDelivered = 40,
				bumpsLanded = 2,
				cometsCaught = 1,
			},
		},
		updatedAt = 1700000000,
	}
end

-- A record written by a newer server (rolling update) — must never be loaded or overwritten.
function PlayerRecords.futureVersion(): any
	return {
		schemaVersion = 999,
		data = { coins = 1, stats = { collectiblesCollected = 0, sessions = 1 }, newField = true },
		updatedAt = 1700000000,
	}
end

-- Corrupt data: negative, non-integer currency.
function PlayerRecords.corruptCoins(): any
	return {
		schemaVersion = 2,
		data = { coins = -3.5, stats = { collectiblesCollected = 0, sessions = 0 } },
		updatedAt = 1700000000,
	}
end

-- A current-version record locked by another live server.
function PlayerRecords.lockedBy(jobId: string, lockedAt: number): any
	return {
		schemaVersion = 2,
		data = { coins = 7, stats = { collectiblesCollected = 7, sessions = 3 } },
		session = { jobId = jobId, lockedAt = lockedAt },
		updatedAt = lockedAt,
	}
end

return table.freeze(PlayerRecords)
