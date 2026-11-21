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

	History: v1 coins only · v2 + stats · v3 Comet Raiders progression (vault, xp, rebirths, zones,
	upgrades, Starlings, lastSeen, more stats) · v4 Starling Index + daily reward streak.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

export type Starling = {
	rarity: number,
	shiny: boolean,
}

export type PlayerData = {
	coins: number,
	-- Income waiting at the base, banked by stepping on the collect pad.
	vault: number,
	xp: number,
	rebirths: number,
	-- Highest unlocked zone tier (1..Zones.COUNT).
	zoneTier: number,
	upgrades: {
		speed: number,
		carry: number,
		magnet: number,
		slots: number,
	},
	starlings: { Starling },
	-- os.time() of the last save, for offline earnings. 0 = never saved.
	lastSeen: number,
	-- Starling Index: discovered rarity/shiny entries (keys from Economy.indexKey).
	discovered: { [string]: boolean },
	-- os.time() of the last daily reward claim (0 = never) and the current streak day.
	dailyLastClaim: number,
	dailyStreak: number,
	stats: {
		collectiblesCollected: number,
		sessions: number,
		shardsDelivered: number,
		bumpsLanded: number,
		cometsCaught: number,
	},
}

-- Largest integer a double represents exactly; keeps currency arithmetic lossless.
local MAX_SAFE_INTEGER = 2 ^ 53 - 1
-- Hard cap on stored Starlings (base slots + every pedestal upgrade).
local MAX_STARLINGS = 4 + (Upgrades.get("slots") :: Upgrades.Upgrade).maxLevel

local PlayerDataSchema = {}

PlayerDataSchema.VERSION = 4
PlayerDataSchema.MAX_STARLINGS = MAX_STARLINGS

function PlayerDataSchema.defaults(): PlayerData
	return {
		coins = 0,
		vault = 0,
		xp = 0,
		rebirths = 0,
		zoneTier = 1,
		upgrades = { speed = 0, carry = 0, magnet = 0, slots = 0 },
		starlings = {},
		lastSeen = 0,
		discovered = {},
		dailyLastClaim = 0,
		dailyStreak = 0,
		stats = {
			collectiblesCollected = 0,
			sessions = 0,
			shardsDelivered = 0,
			bumpsLanded = 0,
			cometsCaught = 0,
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
	MIGRATIONS[n] upgrades data from version n to n + 1. Append-only: never edit a shipped one.
]]
local MIGRATIONS: { [number]: (data: any) -> any } = {
	-- v1 -> v2: v1 stored only `coins`; v2 introduced `stats`.
	[1] = function(data: any): any
		data.stats = {
			collectiblesCollected = 0,
			sessions = 0,
		}
		return data
	end,
	-- v2 -> v3: Comet Raiders progression. Existing coins and stats are kept.
	[2] = function(data: any): any
		data.vault = 0
		data.xp = 0
		data.rebirths = 0
		data.zoneTier = 1
		data.upgrades = { speed = 0, carry = 0, magnet = 0, slots = 0 }
		data.starlings = {}
		data.lastSeen = 0
		data.stats.shardsDelivered = 0
		data.stats.bumpsLanded = 0
		data.stats.cometsCaught = 0
		return data
	end,
	-- v3 -> v4: Starling Index (Starlings already owned count as discovered) + daily streak.
	[3] = function(data: any): any
		data.discovered = {}
		for _, starling in data.starlings or {} do
			if type(starling) == "table" and type(starling.rarity) == "number" then
				data.discovered[`r{starling.rarity}{if starling.shiny == true then "s" else ""}`] = true
			end
		end
		data.dailyLastClaim = 0
		data.dailyStreak = 0
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

local function isIntegerInRange(value: unknown, min: number, max: number): boolean
	return isCount(value) and (value :: number) >= min and (value :: number) <= max
end

local function validateStarlings(starlings: unknown): (boolean, string?)
	if type(starlings) ~= "table" then
		return false, "starlings must be a table"
	end
	local list = starlings :: { [any]: any }
	local count = 0
	for key in list do
		count += 1
		if type(key) ~= "number" or math.floor(key) ~= key or key < 1 then
			return false, "starlings must be an array"
		end
	end
	if count ~= #list then
		return false, "starlings must be a contiguous array"
	end
	if count > MAX_STARLINGS then
		return false, `at most {MAX_STARLINGS} starlings`
	end
	for index, starling in list do
		if type(starling) ~= "table" then
			return false, `starlings[{index}] must be a table`
		end
		if not Rarities.isValid(starling.rarity) then
			return false, `starlings[{index}].rarity is invalid`
		end
		if type(starling.shiny) ~= "boolean" then
			return false, `starlings[{index}].shiny must be a boolean`
		end
	end
	return true, nil
end

function PlayerDataSchema.validate(data: unknown): (boolean, string?)
	if type(data) ~= "table" then
		return false, "data is not a table"
	end
	local record = data :: any
	for _, field in { "coins", "vault", "xp", "rebirths", "lastSeen", "dailyLastClaim" } do
		if not isCount(record[field]) then
			return false, `{field} must be a non-negative safe integer`
		end
	end
	if not isIntegerInRange(record.dailyStreak, 0, 7) then
		return false, "dailyStreak must be an integer within [0, 7]"
	end
	if type(record.discovered) ~= "table" then
		return false, "discovered must be a table"
	end
	local entries = 0
	for key, value in record.discovered do
		entries += 1
		if type(key) ~= "string" or string.match(key, "^r[1-6]s?$") == nil or value ~= true then
			return false, "discovered has an invalid entry"
		end
	end
	if entries > Rarities.COUNT * 2 then
		return false, "discovered has too many entries"
	end
	if not isIntegerInRange(record.zoneTier, 1, Zones.COUNT) then
		return false, `zoneTier must be an integer within [1, {Zones.COUNT}]`
	end

	if type(record.upgrades) ~= "table" then
		return false, "upgrades must be a table"
	end
	for _, upgrade in Upgrades.list do
		if not isIntegerInRange(record.upgrades[upgrade.id], 0, upgrade.maxLevel) then
			return false, `upgrades.{upgrade.id} must be an integer within [0, {upgrade.maxLevel}]`
		end
	end

	local starlingsOk, starlingsErr = validateStarlings(record.starlings)
	if not starlingsOk then
		return false, starlingsErr
	end

	if type(record.stats) ~= "table" then
		return false, "stats must be a table"
	end
	for _, field in { "collectiblesCollected", "sessions", "shardsDelivered", "bumpsLanded", "cometsCaught" } do
		if not isCount(record.stats[field]) then
			return false, `stats.{field} must be a non-negative safe integer`
		end
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
