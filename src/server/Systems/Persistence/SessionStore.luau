--!strict
--[[
	SessionStore — session-locked load/save of player data on top of any StoreTypes.Store.

	Guarantees:
	  - Only one server owns a player's record at a time (session lock written atomically with
	    UpdateAsync semantics). Another server waits for the lock to be released.
	  - A lock older than `lockExpirySeconds` belongs to a crashed server and is taken over.
	  - A server that lost its lock can never overwrite the new owner's data.
	  - Corrupt, invalid or newer-schema data is never overwritten: the load fails instead.
	  - Invalid in-memory data is never saved.

	Engine-agnostic: the store, clock, sleep function and job id are injected, so the whole
	protocol is covered by headless tests (tests/integration/SessionStore.spec.luau).

	Record format stored under each key:
	  { schemaVersion: number, data: PlayerData, session: { jobId, lockedAt }?, updatedAt: number }
]]

local PlayerDataSchema = require(script.Parent.PlayerDataSchema)
local StoreTypes = require(script.Parent.StoreTypes)

export type Options = {
	store: StoreTypes.Store,
	jobId: string,
	lockExpirySeconds: number,
	maxLoadAttempts: number,
	retryDelaySeconds: number,
	now: () -> number,
	sleep: (seconds: number) -> (),
}

export type LoadFailure = "Locked" | "Unavailable" | "Corrupt"
export type SaveFailure = "LockLost" | "Unavailable" | "Invalid"

type Session = { jobId: string, lockedAt: number }

local SessionStore = {}
SessionStore.__index = SessionStore

export type SessionStore = typeof(setmetatable({} :: { _options: Options }, SessionStore))

function SessionStore.new(options: Options): SessionStore
	assert(options.jobId ~= "", "SessionStore: jobId must not be empty")
	assert(options.maxLoadAttempts >= 1, "SessionStore: maxLoadAttempts must be >= 1")
	return setmetatable({ _options = options }, SessionStore)
end

local function readSession(record: any): Session?
	local session = record.session
	if type(session) == "table" and type(session.jobId) == "string" and type(session.lockedAt) == "number" then
		return session :: Session
	end
	return nil
end

--[[
	Loads and locks `key`. Returns:
	  (true, PlayerData)          on success (data is migrated to the current schema)
	  (false, LoadFailure, msg)   otherwise. "Corrupt" must not be retried automatically.
]]
function SessionStore.load(self: SessionStore, key: string, userIds: { number }?): (boolean, any, string?)
	local options = self._options
	local lastFailure: LoadFailure = "Unavailable"
	local lastMessage = "no attempt made"

	for attempt = 1, options.maxLoadAttempts do
		local outcome: "ok" | "locked" | "corrupt" | nil = nil
		local loadedData: PlayerDataSchema.PlayerData? = nil
		local corruptReason = ""

		local requestOk, requestErr = options.store:update(key, function(current: any): any
			-- Reset captured state: the transform may run several times under contention.
			outcome, loadedData, corruptReason = nil, nil, ""
			local now = options.now()

			if current ~= nil and type(current) ~= "table" then
				outcome, corruptReason = "corrupt", "record is not a table"
				return nil
			end

			if current ~= nil then
				local session = readSession(current)
				if
					session
					and session.jobId ~= options.jobId
					and now - session.lockedAt < options.lockExpirySeconds
				then
					outcome = "locked"
					return nil
				end
			end

			local migrated, result = PlayerDataSchema.migrate(
				if current then current.data else nil,
				if current then current.schemaVersion else nil
			)
			if not migrated then
				outcome, corruptReason = "corrupt", result :: string
				return nil
			end

			outcome = "ok"
			loadedData = result :: PlayerDataSchema.PlayerData
			return {
				schemaVersion = PlayerDataSchema.VERSION,
				data = result,
				session = { jobId = options.jobId, lockedAt = now },
				updatedAt = now,
			}
		end, userIds)

		if not requestOk then
			lastFailure, lastMessage = "Unavailable", requestErr or "store request failed"
		elseif outcome == "ok" and loadedData ~= nil then
			return true, loadedData, nil
		elseif outcome == "corrupt" then
			return false, "Corrupt" :: LoadFailure, corruptReason
		else
			lastFailure, lastMessage = "Locked", "record is locked by another server"
		end

		if attempt < options.maxLoadAttempts then
			options.sleep(options.retryDelaySeconds * attempt)
		end
	end

	return false, lastFailure, lastMessage
end

--[[
	Saves `data` for `key` if this server still owns the session.
	`release = true` also removes the lock (player left / server shutting down).
	Returns (true) or (false, SaveFailure, msg).
]]
function SessionStore.save(
	self: SessionStore,
	key: string,
	data: PlayerDataSchema.PlayerData,
	release: boolean,
	userIds: { number }?
): (boolean, SaveFailure?, string?)
	local valid, validationErr = PlayerDataSchema.validate(data)
	if not valid then
		return false, "Invalid", validationErr
	end

	local options = self._options
	local owned = false
	local snapshot = PlayerDataSchema.deepCopy(data)

	local requestOk, requestErr = options.store:update(key, function(current: any): any
		owned = false
		if type(current) ~= "table" then
			return nil
		end
		local session = readSession(current)
		if session == nil or session.jobId ~= options.jobId then
			return nil
		end
		owned = true
		local now = options.now()
		return {
			schemaVersion = PlayerDataSchema.VERSION,
			data = snapshot,
			session = if release then nil else { jobId = options.jobId, lockedAt = now },
			updatedAt = now,
		}
	end, userIds)

	if not requestOk then
		return false, "Unavailable", requestErr
	end
	if not owned then
		return false, "LockLost", "another server owns this session"
	end
	return true, nil, nil
end

return SessionStore
