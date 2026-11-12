--!strict
--[[
	Log — scoped, levelled logging. Prefer this over bare print/warn so output can be filtered.

	    local log = Log.scope("PlayerDataService")
	    log:info("loaded", player.UserId)
]]

export type Level = "debug" | "info" | "warn" | "error"

local LEVEL_ORDER: { [Level]: number } = {
	debug = 1,
	info = 2,
	warn = 3,
	error = 4,
}

local minimumLevel: Level = "info"

export type Logger = {
	debug: (self: Logger, ...any) -> (),
	info: (self: Logger, ...any) -> (),
	warn: (self: Logger, ...any) -> (),
	error: (self: Logger, ...any) -> (),
}

local Log = {}

local function format(scope: string, ...: any): string
	local parts = table.create(select("#", ...))
	for index = 1, select("#", ...) do
		parts[index] = tostring((select(index, ...)))
	end
	return `[{scope}] {table.concat(parts, " ")}`
end

local function emit(level: Level, scope: string, ...: any)
	if LEVEL_ORDER[level] < LEVEL_ORDER[minimumLevel] then
		return
	end
	local message = format(scope, ...)
	if level == "warn" or level == "error" then
		-- Never `error()` from a logger: logging must not change control flow.
		warn(message)
	else
		print(message)
	end
end

function Log.scope(scope: string): Logger
	local logger = {}
	function logger.debug(_self: Logger, ...: any)
		emit("debug", scope, ...)
	end
	function logger.info(_self: Logger, ...: any)
		emit("info", scope, ...)
	end
	function logger.warn(_self: Logger, ...: any)
		emit("warn", scope, ...)
	end
	function logger.error(_self: Logger, ...: any)
		emit("error", scope, ...)
	end
	return logger :: any
end

function Log.setLevel(level: Level)
	minimumLevel = level
end

function Log.getLevel(): Level
	return minimumLevel
end

return Log
