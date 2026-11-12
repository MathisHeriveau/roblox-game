--!strict
--[[
	RobloxDataStore — StoreTypes.Store backed by DataStoreService.

	Requirements (DataStores do NOT work offline):
	  - The place must be published to Roblox.
	  - In Studio: Game Settings > Security > "Enable Studio Access to API Services" (writes to the
	    REAL data of the experience — prefer a separate test experience).
	  - Headless tests (Lune) never touch this module; they use InMemoryStore.

	Reliability: each request is retried with exponential backoff + jitter, and waits for request
	budget before calling so throttling is avoided instead of triggered.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local StoreTypes = require(script.Parent.StoreTypes)

export type Options = {
	maxAttempts: number,
	retryBaseSeconds: number,
}

local log = Log.scope("RobloxDataStore")

-- Upper bound on how long we wait for request budget before trying anyway.
local BUDGET_WAIT_LIMIT_SECONDS = 10

local RobloxDataStore = {}
RobloxDataStore.__index = RobloxDataStore

export type RobloxDataStore = typeof(setmetatable(
	{} :: {
		_store: DataStore,
		_options: Options,
	},
	RobloxDataStore
))

function RobloxDataStore.new(name: string, options: Options): RobloxDataStore
	return setmetatable({
		_store = DataStoreService:GetDataStore(name),
		_options = options,
	}, RobloxDataStore)
end

local function waitForBudget(requestType: Enum.DataStoreRequestType)
	local waited = 0
	while DataStoreService:GetRequestBudgetForRequestType(requestType) <= 0 and waited < BUDGET_WAIT_LIMIT_SECONDS do
		waited += task.wait(0.5)
	end
end

local function withRetries(
	self: RobloxDataStore,
	label: string,
	requestType: Enum.DataStoreRequestType,
	request: () -> any
): (boolean, any)
	local lastError: any = nil
	for attempt = 1, self._options.maxAttempts do
		waitForBudget(requestType)
		local ok, result = pcall(request)
		if ok then
			return true, result
		end
		lastError = result
		log:warn(`{label} failed (attempt {attempt}/{self._options.maxAttempts}): {result}`)
		if attempt < self._options.maxAttempts then
			local backoff = self._options.retryBaseSeconds * 2 ^ (attempt - 1)
			task.wait(backoff + math.random() * self._options.retryBaseSeconds)
		end
	end
	return false, tostring(lastError)
end

function RobloxDataStore.update(
	self: RobloxDataStore,
	key: string,
	transform: StoreTypes.Transform,
	userIds: { number }?
): (boolean, string?)
	local ok, err = withRetries(self, `UpdateAsync({key})`, Enum.DataStoreRequestType.UpdateAsync, function()
		return self._store:UpdateAsync(key, function(current: any)
			-- Returning nil cancels the write. userIds tags the key for GDPR erasure requests.
			return transform(current), userIds
		end)
	end)
	if ok then
		return true, nil
	end
	return false, err
end

function RobloxDataStore.read(self: RobloxDataStore, key: string): (boolean, any)
	return withRetries(self, `GetAsync({key})`, Enum.DataStoreRequestType.GetAsync, function()
		return self._store:GetAsync(key)
	end)
end

return RobloxDataStore
