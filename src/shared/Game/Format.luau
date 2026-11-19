--!strict
--[[
	Format — number and time formatting for UI and notifications. Never throws: hostile or odd input
	(NaN, ±inf, negatives) renders as a safe value.
]]

local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }

local function isFiniteNonNegative(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

-- 1234567 -> "1,234,567".
function Format.number(value: number): string
	if not isFiniteNonNegative(value) then
		return "0"
	end
	local digits = tostring(math.floor(value))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if grouped:sub(1, 1) == "," then
		grouped = grouped:sub(2)
	end
	return grouped
end

-- 999 -> "999", 1250 -> "1.25K", 45600 -> "45.6K", 1234567 -> "1.23M". Three significant digits.
function Format.compact(value: number): string
	if not isFiniteNonNegative(value) then
		return "0"
	end
	if value < 1000 then
		return tostring(math.floor(value))
	end
	local exponent = 0
	local scaled = value
	while scaled >= 1000 and exponent < #SUFFIXES do
		scaled /= 1000
		exponent += 1
	end
	local text: string
	if scaled >= 100 then
		text = tostring(math.floor(scaled))
	elseif scaled >= 10 then
		text = string.format("%.1f", math.floor(scaled * 10) / 10)
	else
		text = string.format("%.2f", math.floor(scaled * 100) / 100)
	end
	-- Trim trailing zeros: "1.50" -> "1.5", "2.00" -> "2".
	text = text:gsub("(%.%d-)0+$", "%1"):gsub("%.$", "")
	return text .. SUFFIXES[exponent]
end

-- 65 -> "1:05", 3723 -> "1:02:03". Negative/invalid -> "0:00".
function Format.duration(seconds: number): string
	if not isFiniteNonNegative(seconds) then
		return "0:00"
	end
	local total = math.floor(seconds)
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

return table.freeze(Format)
