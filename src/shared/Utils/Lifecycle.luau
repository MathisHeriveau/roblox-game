--!strict
--[[
	Lifecycle — boots services (server) and controllers (client) in two explicit phases.

	  1. `init()` — runs synchronously, in list order. Wire dependencies, create state.
	                MUST NOT yield. Failure aborts the boot (fail fast and loud).
	  2. `start()` — each runs in its own thread after every init() succeeded. May yield.
	                A failure is logged and isolated to that module.

	The boot order is the order of the list passed to `boot` — explicit, reviewable, and free of
	hidden discovery magic. A module that depends on another must appear after it.
]]

-- Every service/controller implements both phases (an empty body is fine) — explicit by design.
export type Module = {
	name: string,
	init: (self: any) -> (),
	start: (self: any) -> (),
}

local Lifecycle = {}

function Lifecycle.boot(modules: { Module }, spawner: ((() -> ()) -> ())?)
	local spawnFn = spawner or function(fn: () -> ())
		task.spawn(fn)
	end

	local seen: { [string]: boolean } = {}
	for index, module in modules do
		assert(type(module) == "table", `Lifecycle: module #{index} is not a table`)
		assert(type(module.name) == "string", `Lifecycle: module #{index} has no name`)
		assert(type(module.init) == "function", `Lifecycle: {module.name} has no init()`)
		assert(type(module.start) == "function", `Lifecycle: {module.name} has no start()`)
		assert(not seen[module.name], `Lifecycle: duplicate module name "{module.name}"`)
		seen[module.name] = true
	end

	for _, module in modules do
		local thread = coroutine.create(module.init)
		local ok, err = coroutine.resume(thread, module)
		if not ok then
			error(`Lifecycle: {module.name}.init() failed: {err}`, 0)
		end
		if coroutine.status(thread) ~= "dead" then
			error(`Lifecycle: {module.name}.init() yielded — init must be synchronous`, 0)
		end
	end

	for _, module in modules do
		local start = module.start
		spawnFn(function()
			local ok, err = xpcall(start :: any, debug.traceback, module)
			if not ok then
				warn(`Lifecycle: {module.name}.start() failed: {err}`)
			end
		end)
	end
end

return table.freeze(Lifecycle)
