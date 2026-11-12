--!strict
--[[
	PlayerDataSchema — shape, defaults, validation and migrations of persisted player data.

	Rules (see .claude/skills/persistence/SKILL.md):
	  - VERSION only ever increases. Each bump adds exactly one migration `[oldVersion] = fn`.
	  - Migrations are pure, never yield, never delete a released migration, and receive a deep
	    copy (they may mutate their argument).
	  - Data written by a NEWER schema is never loaded (it would be silently downgraded and lose
	    fields during a rolling update). The session is refused instead.
	  - Everything loaded is validated; invalid data is reported, never "repaired" by overwriting.
]]

export type PlayerData = {
	coins: number,
	stats: {
		collectiblesCollected: number,
		sessions: number,
	},
}

-- Largest integer a double represents exactly; keeps currency arithmetic lossless.
local MAX_SAFE_INTEGER = 2 ^ 53 - 1

local PlayerDataSchema = {}

PlayerDataSchema.VERSION = 2

function PlayerDataSchema.defaults(): PlayerData
	return {
		coins = 0,
		stats = {
			collectiblesCollected = 0,
			sessions = 0,
		},
	}
end

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value :: any do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy :: any
end
PlayerDataSchema.deepCopy = deepCopy

--[[
	MIGRATIONS[n] upgrades data from version n to n + 1.

	v1 -> v2 is the reference example of the pattern: v1 stored only `coins`; v2 introduced
	`stats`. It stays forever so a v1 record (if one existed) still loads correctly.
]]
local MIGRATIONS: { [number]: (data: any) -> any } = {
	[1] = function(data: any): any
		data.stats = {
			collectiblesCollected = 0,
			sessions = 0,
		}
		return data
	end,
}

local function isCount(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value >= 0
		and value <= MAX_SAFE_INTEGER
		and math.floor(value) == value
end

function PlayerDataSchema.validate(data: unknown): (boolean, string?)
	if type(data) ~= "table" then
		return false, "data is not a table"
	end
	local record = data :: any
	if not isCount(record.coins) then
		return false, "coins must be a non-negative safe integer"
	end
	if type(record.stats) ~= "table" then
		return false, "stats must be a table"
	end
	if not isCount(record.stats.collectiblesCollected) then
		return false, "stats.collectiblesCollected must be a non-negative safe integer"
	end
	if not isCount(record.stats.sessions) then
		return false, "stats.sessions must be a non-negative safe integer"
	end
	return true, nil
end

--[[
	Upgrades `data` stored at `version` to the current schema.
	`data == nil` means a brand-new player and yields defaults.
	Returns (true, PlayerData) or (false, reason). Never mutates its input.
]]
function PlayerDataSchema.migrate(data: unknown, version: unknown): (boolean, PlayerData | string)
	if data == nil then
		return true, PlayerDataSchema.defaults()
	end
	if type(version) ~= "number" or version ~= version or math.floor(version) ~= version or version < 1 then
		return false, "missing or invalid schema version"
	end
	local fromVersion = version :: number
	if fromVersion > PlayerDataSchema.VERSION then
		return false, `data uses schema v{fromVersion}, newer than this server (v{PlayerDataSchema.VERSION})`
	end
	if type(data) ~= "table" then
		return false, "data is not a table"
	end

	local working = deepCopy(data) :: any
	for step = fromVersion, PlayerDataSchema.VERSION - 1 do
		local migration = MIGRATIONS[step]
		if migration == nil then
			return false, `no migration from v{step} to v{step + 1}`
		end
		local ok, result = pcall(migration, working)
		if not ok then
			return false, `migration v{step} -> v{step + 1} failed: {result}`
		end
		working = result
	end

	local valid, err = PlayerDataSchema.validate(working)
	if not valid then
		return false, `invalid data after migration: {err}`
	end
	return true, working :: PlayerData
end

return table.freeze(PlayerDataSchema)
