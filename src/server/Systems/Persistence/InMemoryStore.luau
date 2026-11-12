--!strict
--[[
	InMemoryStore — StoreTypes.Store backed by a Lua table.

	Used in Studio play tests (no DataStore access needed; nothing persists between sessions) and
	in automated tests. Values are deep-copied on every read/write to mimic DataStore
	serialization: callers can never alias stored data. `failNext(n)` simulates outages.
]]

local StoreTypes = require(script.Parent.StoreTypes)

local InMemoryStore = {}
InMemoryStore.__index = InMemoryStore

export type InMemoryStore = typeof(setmetatable(
	{} :: {
		_records: { [string]: any },
		_failuresRemaining: number,
		requestCount: number,
	},
	InMemoryStore
))

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

function InMemoryStore.new(): InMemoryStore
	return setmetatable({
		_records = {},
		_failuresRemaining = 0,
		requestCount = 0,
	}, InMemoryStore)
end

-- Makes the next `count` requests fail as if the DataStore were unavailable.
function InMemoryStore.failNext(self: InMemoryStore, count: number)
	self._failuresRemaining = count
end

local function consumeFailure(self: InMemoryStore): boolean
	self.requestCount += 1
	if self._failuresRemaining > 0 then
		self._failuresRemaining -= 1
		return true
	end
	return false
end

function InMemoryStore.update(
	self: InMemoryStore,
	key: string,
	transform: StoreTypes.Transform,
	_userIds: { number }?
): (boolean, string?)
	if consumeFailure(self) then
		return false, "InMemoryStore: simulated failure"
	end
	local nextValue = transform(deepCopy(self._records[key]))
	if nextValue ~= nil then
		self._records[key] = deepCopy(nextValue)
	end
	return true, nil
end

function InMemoryStore.read(self: InMemoryStore, key: string): (boolean, any)
	if consumeFailure(self) then
		return false, "InMemoryStore: simulated failure"
	end
	return true, deepCopy(self._records[key])
end

-- Test helper: write a raw record directly (e.g. legacy or corrupt data).
function InMemoryStore.seed(self: InMemoryStore, key: string, value: any)
	self._records[key] = deepCopy(value)
end

return InMemoryStore
