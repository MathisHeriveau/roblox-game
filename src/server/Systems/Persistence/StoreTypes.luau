--!strict
--[[
	StoreTypes — the storage abstraction used by SessionStore.

	Implementations:
	  - RobloxDataStore: real DataStoreService (live servers, or Studio with API access enabled)
	  - InMemoryStore:   process-local table (Studio play tests, unit/integration tests)

	`update` has UpdateAsync semantics:
	  - `transform(current)` returns the new value, or nil to CANCEL the write.
	  - `transform` may run more than once (contention) and MUST NOT yield.
	  - Returns (true, nil) when the request completed (written or cancelled),
	    (false, message) when the store could not be reached after retries.
]]

export type Transform = (current: any) -> any

export type Store = {
	update: (self: Store, key: string, transform: Transform, userIds: { number }?) -> (boolean, string?),
	read: (self: Store, key: string) -> (boolean, any),
}

return table.freeze({})
