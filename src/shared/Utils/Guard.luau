--!strict
--[[
	Guard — runtime validation for UNTRUSTED values (remote arguments, DataStore records).

	Type annotations do not exist at runtime: an exploiter can send any value through a remote,
	including NaN, ±inf, huge strings, invalid UTF-8, tables with metatables or Instances they
	should not reference. Every remote handler validates its arguments with a Guard before use.

	    local validate = Guard.tuple(Guard.string({ maxLength = 32 }), Guard.integer({ min = 1, max = 99 }))
	    local ok, err = validate({ ... }, select("#", ...))
]]

export type Check = (value: unknown) -> (boolean, string?)
export type TupleCheck = (args: { unknown }, count: number) -> (boolean, string?)

export type NumberOptions = {
	min: number?,
	max: number?,
	integer: boolean?,
}

export type StringOptions = {
	minLength: number?,
	maxLength: number,
	pattern: string?,
}

local Guard = {}

local function isFiniteNumber(value: unknown): boolean
	-- NaN is the only value not equal to itself; ±inf fails the comparison against math.huge.
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Guard.number(options: NumberOptions?): Check
	local min = options and options.min
	local max = options and options.max
	local integer = options ~= nil and options.integer == true
	return function(value: unknown): (boolean, string?)
		if not isFiniteNumber(value) then
			return false, "expected a finite number"
		end
		local n = value :: number
		if integer and math.floor(n) ~= n then
			return false, "expected an integer"
		end
		if min ~= nil and n < min then
			return false, `expected a number >= {min}`
		end
		if max ~= nil and n > max then
			return false, `expected a number <= {max}`
		end
		return true, nil
	end
end

function Guard.integer(options: NumberOptions?): Check
	return Guard.number({
		min = options and options.min,
		max = options and options.max,
		integer = true,
	})
end

-- `maxLength` is mandatory: unbounded strings from clients are a memory/bandwidth attack vector.
function Guard.string(options: StringOptions): Check
	local minLength = options.minLength or 0
	local maxLength = options.maxLength
	local pattern = options.pattern
	return function(value: unknown): (boolean, string?)
		if type(value) ~= "string" then
			return false, "expected a string"
		end
		local s = value :: string
		if #s > maxLength * 4 then
			-- Cheap byte-length pre-check before the UTF-8 scan (a code point is at most 4 bytes).
			return false, `expected at most {maxLength} characters`
		end
		local length = utf8.len(s)
		if length == nil then
			return false, "expected valid UTF-8"
		end
		if length < minLength or length > maxLength then
			return false, `expected between {minLength} and {maxLength} characters`
		end
		if pattern ~= nil and string.match(s, pattern) == nil then
			return false, "string does not match the expected format"
		end
		return true, nil
	end
end

function Guard.boolean(): Check
	return function(value: unknown): (boolean, string?)
		if type(value) ~= "boolean" then
			return false, "expected a boolean"
		end
		return true, nil
	end
end

-- Accepts exactly one of the given primitive values (e.g. an allow-list of action names).
function Guard.oneOf(allowed: { string | number | boolean }): Check
	local lookup: { [any]: boolean } = {}
	for _, v in allowed do
		lookup[v] = true
	end
	return function(value: unknown): (boolean, string?)
		local t = type(value)
		if (t == "string" or t == "number" or t == "boolean") and lookup[value :: any] == true then
			return true, nil
		end
		return false, "value is not one of the allowed options"
	end
end

function Guard.instanceOf(className: string): Check
	return function(value: unknown): (boolean, string?)
		if typeof(value) ~= "Instance" then
			return false, `expected an Instance ({className})`
		end
		if not (value :: Instance):IsA(className) then
			return false, `expected an Instance of class {className}`
		end
		return true, nil
	end
end

function Guard.optional(check: Check): Check
	return function(value: unknown): (boolean, string?)
		if value == nil then
			return true, nil
		end
		return check(value)
	end
end

--[[
	Validates a full argument list. `count` must be `select("#", ...)` so that trailing nils and
	extra arguments are detected — clients must send exactly the expected arity.
]]
function Guard.tuple(...: Check): TupleCheck
	local checks = { ... }
	local expected = #checks
	return function(args: { unknown }, count: number): (boolean, string?)
		if count > expected then
			return false, `expected at most {expected} argument(s), got {count}`
		end
		for index, check in checks do
			local ok, err = check(args[index])
			if not ok then
				return false, `argument #{index}: {err or "invalid"}`
			end
		end
		return true, nil
	end
end

return table.freeze(Guard)
