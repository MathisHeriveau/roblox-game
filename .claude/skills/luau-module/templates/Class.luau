--!strict
--[[
	Counter — example of the project's class pattern (copy, rename, adapt).

	    local counter = Counter.new({ max = 10 })
	    counter:increment()
]]

export type Options = {
	max: number,
}

local Counter = {}
Counter.__index = Counter

export type Counter = typeof(setmetatable(
	{} :: {
		_value: number,
		_max: number,
	},
	Counter
))

function Counter.new(options: Options): Counter
	assert(options.max > 0, "Counter: max must be > 0")
	return setmetatable({
		_value = 0,
		_max = options.max,
	}, Counter)
end

-- Returns false (without changing anything) when the counter is already at max.
function Counter.increment(self: Counter): boolean
	if self._value >= self._max then
		return false
	end
	self._value += 1
	return true
end

function Counter.get(self: Counter): number
	return self._value
end

return Counter
