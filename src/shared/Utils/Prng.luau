--!strict
--[[
	Prng — deterministic, seedable pseudo-random generator (xorshift32).

	Why not Roblox `Random`? Procedural generation must be reproducible bit-for-bit in every
	runtime we use (Roblox server, Roblox client, Lune tests). This implementation only uses
	`bit32`, so the same seed yields the same sequence everywhere. It is NOT cryptographically
	secure — never use it for anything security-sensitive.
]]

local UINT32_RANGE = 4294967296 -- 2^32
local DEFAULT_STATE = 0x9E3779B9
local WARMUP_ROUNDS = 8

local Prng = {}
Prng.__index = Prng

export type Prng = typeof(setmetatable({} :: { _state: number }, Prng))

function Prng.new(seed: number): Prng
	assert(type(seed) == "number" and seed == seed, "Prng.new: seed must be a number")
	local state = bit32.band(math.floor(math.abs(seed)), 0xFFFFFFFF)
	if state == 0 then
		state = DEFAULT_STATE
	end

	local self = setmetatable({ _state = state }, Prng)
	-- Small seeds produce correlated first outputs with xorshift; discard them.
	for _ = 1, WARMUP_ROUNDS do
		self:nextUInt32()
	end
	return self
end

-- Returns an integer in [0, 2^32).
function Prng.nextUInt32(self: Prng): number
	local x = self._state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self._state = x
	return x
end

-- Returns a number in [0, 1).
function Prng.nextNumber(self: Prng): number
	return self:nextUInt32() / UINT32_RANGE
end

-- Returns a number in [min, max).
function Prng.nextRange(self: Prng, min: number, max: number): number
	assert(max >= min, "Prng.nextRange: max must be >= min")
	return min + self:nextNumber() * (max - min)
end

-- Returns an integer in [min, max] (both inclusive).
function Prng.nextInteger(self: Prng, min: number, max: number): number
	assert(math.floor(min) == min and math.floor(max) == max, "Prng.nextInteger: bounds must be integers")
	assert(max >= min, "Prng.nextInteger: max must be >= min")
	return min + math.floor(self:nextNumber() * (max - min + 1))
end

return Prng
