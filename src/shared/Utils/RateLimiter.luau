--!strict
--[[
	RateLimiter — token bucket per key (usually a Player).

	    local limiter = RateLimiter.new({ capacity = 5, refillPerSecond = 2 })
	    if not limiter:tryConsume(player) then return end

	Memory: buckets are created lazily and MUST be released with `remove(key)` when the key goes
	away (e.g. Players.PlayerRemoving). The clock is injectable for deterministic tests.
]]

export type Options = {
	capacity: number,
	refillPerSecond: number,
	clock: (() -> number)?,
}

type Bucket = {
	tokens: number,
	updatedAt: number,
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_capacity: number,
		_refillPerSecond: number,
		_clock: () -> number,
		_buckets: { [any]: Bucket },
	},
	RateLimiter
))

function RateLimiter.new(options: Options): RateLimiter
	assert(options.capacity > 0, "RateLimiter: capacity must be > 0")
	assert(options.refillPerSecond >= 0, "RateLimiter: refillPerSecond must be >= 0")
	return setmetatable({
		_capacity = options.capacity,
		_refillPerSecond = options.refillPerSecond,
		_clock = options.clock or os.clock,
		_buckets = {},
	}, RateLimiter)
end

function RateLimiter.tryConsume(self: RateLimiter, key: any, cost: number?): boolean
	local amount = cost or 1
	local now = self._clock()
	local bucket = self._buckets[key]
	if bucket == nil then
		bucket = { tokens = self._capacity, updatedAt = now }
		self._buckets[key] = bucket
	else
		local elapsed = math.max(0, now - bucket.updatedAt)
		bucket.tokens = math.min(self._capacity, bucket.tokens + elapsed * self._refillPerSecond)
		bucket.updatedAt = now
	end

	if bucket.tokens >= amount then
		bucket.tokens -= amount
		return true
	end
	return false
end

function RateLimiter.remove(self: RateLimiter, key: any)
	self._buckets[key] = nil
end

function RateLimiter.size(self: RateLimiter): number
	local count = 0
	for _ in self._buckets do
		count += 1
	end
	return count
end

return RateLimiter
