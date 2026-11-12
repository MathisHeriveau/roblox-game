--[[
	RobloxRuntime — executes Rojo-built ModuleScripts inside Lune.

	How it works:
	  1. `rojo build` produces a real place file from the same project file Studio uses.
	  2. `@lune/roblox` deserializes it into a DataModel (real Instance tree, real names/parents).
	  3. ModuleScript sources are compiled with `@lune/luau` in a custom environment that
	     provides `script`, `game`, `workspace`, an Instance-aware `require`, `task`, and the
	     Roblox datatypes Lune implements (Vector3, CFrame, Color3, UDim2, Enum, Instance, ...).

	Limits (by design — see docs/TESTING.md):
	  - There is no engine: no physics, no replication, no RunService events, no DataStores,
	    no Players. Engine-dependent code must be covered by Studio tests (tests/integration).
	  - Service *methods* (e.g. RunService:IsStudio()) do not exist unless stubbed below.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local RobloxRuntime = {}

export type Runtime = {
	game: any,
	require: (target: any) -> any,
}

local MODULE_ID_ATTRIBUTE = "__LuneModuleId"

-- Roblox datatypes / globals that Lune implements. Anything missing is simply not injected.
local DATATYPE_GLOBALS = {
	"Instance",
	"Axes",
	"BrickColor",
	"CFrame",
	"Color3",
	"ColorSequence",
	"ColorSequenceKeypoint",
	"Enum",
	"Faces",
	"Font",
	"NumberRange",
	"NumberSequence",
	"NumberSequenceKeypoint",
	"PhysicalProperties",
	"Ray",
	"Rect",
	"Region3",
	"Region3int16",
	"UDim",
	"UDim2",
	"Vector2",
	"Vector2int16",
	"Vector3",
	"Vector3int16",
}

-- Minimal engine stubs so modules that *query* the environment can be loaded headlessly.
local stubsInstalled = false
local function installEngineStubs()
	if stubsInstalled then
		return
	end
	stubsInstalled = true
	roblox.implementMethod("RunService", "IsStudio", function()
		return false
	end)
	roblox.implementMethod("RunService", "IsServer", function()
		return true
	end)
	roblox.implementMethod("RunService", "IsClient", function()
		return false
	end)
	roblox.implementMethod("RunService", "IsRunning", function()
		return false
	end)
end

function RobloxRuntime.fromPlaceFile(placePath: string): Runtime
	installEngineStubs()

	local game = roblox.deserializePlace(fs.readFile(placePath))
	local workspace = game:GetService("Workspace")

	local nextId = 0
	local loaded: { [number]: { value: any } } = {}
	local loading: { [number]: boolean } = {}

	local datatypes = {}
	for _, name in DATATYPE_GLOBALS do
		local value = (roblox :: any)[name]
		if value ~= nil then
			datatypes[name] = value
		end
	end

	local requireModule

	local function moduleId(module: any): number
		local id = module:GetAttribute(MODULE_ID_ATTRIBUTE)
		if typeof(id) ~= "number" then
			nextId += 1
			id = nextId
			module:SetAttribute(MODULE_ID_ATTRIBUTE, id)
		end
		return id :: number
	end

	local function buildEnvironment(module: any)
		local env = {
			script = module,
			game = game,
			workspace = workspace,
			require = requireModule,
			task = task,
			-- Deprecated Roblox global still used by TestEZ internals. Game code must use os.clock().
			tick = os.clock,
			-- Lets specs/modules detect the headless runtime explicitly (never use in game logic).
			__LUNE_RUNTIME__ = true,
		}
		for name, value in datatypes do
			env[name] = value
		end
		return env
	end

	function requireModule(target: any): any
		if typeof(target) ~= "Instance" then
			-- Allow Lune built-ins (e.g. "@lune/fs") for tooling; anything else is a bug.
			if type(target) == "string" and string.sub(target, 1, 6) == "@lune/" then
				return require(target)
			end
			error(`RobloxRuntime: require expects a ModuleScript Instance, got {typeof(target)}`, 2)
		end
		if not target:IsA("ModuleScript") then
			error(`RobloxRuntime: {target:GetFullName()} is a {target.ClassName}, not a ModuleScript`, 2)
		end

		local id = moduleId(target)
		local cached = loaded[id]
		if cached then
			return cached.value
		end
		if loading[id] then
			error(`RobloxRuntime: circular dependency detected while requiring {target:GetFullName()}`, 2)
		end

		loading[id] = true
		local chunk = luau.load(target.Source, {
			debugName = target:GetFullName(),
			environment = buildEnvironment(target),
			injectGlobals = true,
		})
		local ok, result = pcall(chunk)
		loading[id] = nil
		if not ok then
			error(`RobloxRuntime: error while loading {target:GetFullName()}:\n{result}`, 0)
		end
		if result == nil then
			error(`RobloxRuntime: module {target:GetFullName()} did not return a value`, 2)
		end

		loaded[id] = { value = result }
		return result
	end

	return {
		game = game,
		require = requireModule,
	}
end

return RobloxRuntime
