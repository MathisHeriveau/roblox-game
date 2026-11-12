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
		-- Token bucket applied per player to GetPlayerState.
		GetPlayerStateRateLimit = table.freeze({ capacity = 5, refillPerSecond = 1 } :: RateLimiter.Options),
	}),
}

return table.freeze(ServerConfig)
