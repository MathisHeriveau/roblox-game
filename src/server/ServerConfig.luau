--!strict
--[[
	ServerConfig — server-only policy. Lives in ServerScriptService, never replicated to clients.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

local ServerConfig = {
	Persistence = table.freeze({
		-- Bump the suffix only for a deliberate, documented data reset (see docs/DECISIONS.md).
		DataStoreName = "PlayerData_v1",
		KeyPrefix = "player_",
		-- Studio without "Enable Studio Access to API Services" cannot use DataStores. When true,
		-- Studio sessions use an in-memory store (nothing persists between play tests).
		UseInMemoryStoreInStudio = true,
		AutosaveIntervalSeconds = 120,
		-- A session lock older than this is considered abandoned (crashed server) and is taken over.
		-- Must be much larger than AutosaveIntervalSeconds because autosaves refresh the lock.
		SessionLockExpirySeconds = 30 * 60,
		-- Attempts to acquire a session lock held by another server (it is probably saving).
		MaxLoadAttempts = 6,
		LoadRetryDelaySeconds = 3,
		-- Low-level DataStore request retries (throttling, transient outages).
		RequestMaxAttempts = 4,
		RequestRetryBaseSeconds = 1,
	}),

	Network = table.freeze({
		-- Token buckets applied per player and per channel.
		GetPlayerStateRateLimit = table.freeze({ capacity = 5, refillPerSecond = 1 } :: RateLimiter.Options),
		RequestPurchaseRateLimit = table.freeze({ capacity = 8, refillPerSecond = 3 } :: RateLimiter.Options),
		RequestBumpRateLimit = table.freeze({ capacity = 3, refillPerSecond = 1 } :: RateLimiter.Options),
		ClaimDailyRateLimit = table.freeze({ capacity = 3, refillPerSecond = 0.2 } :: RateLimiter.Options),
		-- Minimum seconds between two PlayerState pushes to the same client (coalescing).
		StatePushIntervalSeconds = 0.2,
	}),

	Gameplay = table.freeze({
		-- Server simulation loops (seconds). Lower = more responsive, more CPU.
		ShardTickSeconds = 0.1,
		CollectTickSeconds = 0.2,
		HazardTickSeconds = 0.25,
	}),
}

return table.freeze(ServerConfig)
