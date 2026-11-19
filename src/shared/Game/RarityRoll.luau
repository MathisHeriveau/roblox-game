--!strict
--[[
	RarityRoll — weighted random selection driven by an injected Prng (deterministic in tests).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prng = require(ReplicatedStorage.Shared.Utils.Prng)

local RarityRoll = {}

-- Returns an index of `weights` with probability proportional to its weight.
function RarityRoll.pick(rng: Prng.Prng, weights: { number }): number
	local total = 0
	for _, weight in weights do
		assert(weight >= 0 and weight == weight, "RarityRoll: weights must be finite and >= 0")
		total += weight
	end
	assert(total > 0, "RarityRoll: at least one weight must be > 0")

	local roll = rng:nextNumber() * total
	local cumulative = 0
	local lastPositive = 1
	for index, weight in weights do
		if weight > 0 then
			cumulative += weight
			lastPositive = index
			if roll < cumulative then
				return index
			end
		end
	end
	-- Floating point safety net: the roll can equal `total` only through rounding.
	return lastPositive
end

return table.freeze(RarityRoll)
