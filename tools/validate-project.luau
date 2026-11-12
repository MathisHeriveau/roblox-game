--[[
	Project validator (Lune) — enforces configuration and architecture invariants that formatters,
	linters and type checkers cannot see. Run by `make validate`, `make check`, CI and hooks.

	Usage: lune run tools/validate-project.luau [--quiet]

	Errors fail the run (exit 1). Warnings are printed but do not fail.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local quiet = table.find(process.args, "--quiet") ~= nil

local errors: { string } = {}
local warnings: { string } = {}

local function fail(message: string)
	table.insert(errors, message)
end

local function warnAbout(message: string)
	table.insert(warnings, message)
end

local function walk(dir: string, visit: (path: string) -> ())
	if not fs.isDir(dir) then
		return
	end
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			walk(path, visit)
		else
			visit(path)
		end
	end
end

local function endsWith(s: string, suffix: string): boolean
	return suffix == "" or string.sub(s, -#suffix) == suffix
end

local function startsWith(s: string, prefix: string): boolean
	return string.sub(s, 1, #prefix) == prefix
end

-- Removes comments so documentation that *mentions* an API is not flagged as *using* it.
local function stripComments(source: string): string
	local withoutBlocks = string.gsub(source, "%-%-%[(=*)%[.-%]%1%]", "")
	local withoutLines = string.gsub(withoutBlocks, "%-%-[^\n]*", "")
	return withoutLines
end

--------------------------------------------------------------------------------------------------
-- 1. Rojo project files
--------------------------------------------------------------------------------------------------

type Node = { [string]: any }

local function readProject(path: string): Node?
	if not fs.isFile(path) then
		fail(`{path}: missing`)
		return nil
	end
	local ok, decoded = pcall(serde.decode, "json", fs.readFile(path))
	if not ok then
		fail(`{path}: invalid JSON ({decoded})`)
		return nil
	end
	if type(decoded.tree) ~= "table" then
		fail(`{path}: missing "tree"`)
		return nil
	end
	return decoded
end

-- Flattens a project tree into { ["ReplicatedStorage/Shared"] = "src/shared", ... }.
local function collectPaths(node: Node, prefix: string, out: { [string]: any }, projectFile: string)
	local path = node["$path"]
	if path ~= nil then
		out[prefix] = path
		-- Optional paths ({ "optional": "Packages" }) may legitimately be absent.
		local isOptional = type(path) == "table" and type(path.optional) == "string"
		if type(path) == "string" then
			if not fs.isDir(path) and not fs.isFile(path) then
				fail(`{projectFile}: "{prefix}" points to missing path "{path}"`)
			end
		elseif not isOptional then
			fail(`{projectFile}: "{prefix}" has an invalid $path`)
		end
	end
	for key, child in node do
		if type(child) == "table" and not startsWith(key, "$") then
			collectPaths(child, if prefix == "" then key else `{prefix}/{key}`, out, projectFile)
		end
	end
end

local gameProject = readProject("default.project.json")
local testProject = readProject("test.project.json")

if gameProject and testProject then
	local gamePaths, testPaths = {}, {}
	collectPaths(gameProject.tree, "", gamePaths, "default.project.json")
	collectPaths(testProject.tree, "", testPaths, "test.project.json")

	-- The test place must mirror the game place exactly, plus test-only additions.
	for instancePath, source in gamePaths do
		local mirrored = testPaths[instancePath]
		if mirrored == nil then
			fail(`test.project.json: missing "{instancePath}" (present in default.project.json)`)
		elseif serde.encode("json", mirrored) ~= serde.encode("json", source) then
			fail(`test.project.json: "{instancePath}" maps to a different path than default.project.json`)
		end
	end

	-- Tests and dev packages must never be shipped.
	for instancePath, source in gamePaths do
		local text = if type(source) == "string" then source else serde.encode("json", source)
		if string.find(text, "tests", 1, true) or string.find(text, "DevPackages", 1, true) then
			fail(`default.project.json: "{instancePath}" ships test-only content ({text})`)
		end
	end
end

--------------------------------------------------------------------------------------------------
-- 2. Source tree layout
--------------------------------------------------------------------------------------------------

local ENTRY_POINTS = {
	["src/server/init.server.luau"] = true,
	["src/client/init.client.luau"] = true,
}

for entry in ENTRY_POINTS do
	if not fs.isFile(entry) then
		fail(`{entry}: entry point missing`)
	end
end

local sourceFiles: { string } = {}
walk("src", function(path)
	if endsWith(path, ".DS_Store") then
		return
	end
	if endsWith(path, ".lua") then
		fail(`{path}: use the .luau extension`)
	elseif endsWith(path, ".spec.luau") then
		fail(`{path}: specs belong in tests/, not src/`)
	elseif endsWith(path, ".server.luau") or endsWith(path, ".client.luau") then
		if not ENTRY_POINTS[path] then
			fail(
				`{path}: only one Script/LocalScript per side is allowed — make it a ModuleScript booted by Lifecycle`
			)
		end
	end
	if endsWith(path, ".luau") then
		table.insert(sourceFiles, path)
	end
end)

walk("tests", function(path)
	if endsWith(path, ".lua") then
		fail(`{path}: use the .luau extension`)
	end
	local inSpecFolder = startsWith(path, "tests/unit/") or startsWith(path, "tests/integration/")
	if inSpecFolder and endsWith(path, ".luau") and not endsWith(path, ".spec.luau") then
		fail(`{path}: files in tests/unit and tests/integration must end with .spec.luau`)
	end
end)

--------------------------------------------------------------------------------------------------
-- 3. Code rules (comments stripped before matching)
--------------------------------------------------------------------------------------------------

type Rule = {
	pattern: string,
	message: string,
	-- Path prefixes where the pattern is allowed.
	allowedIn: { string }?,
	-- Path prefixes the rule applies to (default: all of src/).
	appliesTo: { string }?,
	severity: "error" | "warning",
}

local RULES: { Rule } = {
	{ pattern = "loadstring%s*%(", message = "loadstring is forbidden", severity = "error" },
	{
		pattern = "[gs]etfenv%s*%(",
		message = "getfenv/setfenv are forbidden (deoptimize all code)",
		severity = "error",
	},
	{
		pattern = "OnServerEvent",
		message = "inbound remotes must go through ServerNet (validation + rate limiting)",
		allowedIn = { "src/server/Systems/ServerNet.luau" },
		severity = "error",
	},
	{
		pattern = "OnServerInvoke",
		message = "inbound remotes must go through ServerNet (validation + rate limiting)",
		allowedIn = { "src/server/Systems/ServerNet.luau" },
		severity = "error",
	},
	{
		pattern = "OnClientInvoke",
		message = "server->client RemoteFunctions are forbidden (a client can hang the server thread)",
		severity = "error",
	},
	{
		pattern = "Instance%.new%(%s*[\"'][%a]*Remote",
		message = "remotes are declared in shared/Net/Remotes.luau and created by ServerNet only",
		allowedIn = { "src/server/Systems/ServerNet.luau" },
		severity = "error",
	},
	{
		pattern = "DataStoreService",
		message = "DataStore access must go through server/Systems/Persistence",
		allowedIn = { "src/server/Systems/Persistence/" },
		severity = "error",
	},
	{
		pattern = "ServerScriptService",
		message = "client/shared code cannot see ServerScriptService",
		appliesTo = { "src/shared/", "src/client/" },
		severity = "error",
	},
	{
		pattern = "ServerStorage",
		message = "client/shared code cannot see ServerStorage",
		appliesTo = { "src/shared/", "src/client/" },
		severity = "error",
	},
	{ pattern = "FIXME", message = "unresolved FIXME", severity = "error" },
	{ pattern = "XXX", message = "unresolved XXX marker", severity = "error" },
	{ pattern = "TODO", message = "TODO left in source (track it in an issue or resolve it)", severity = "warning" },
}

local SECRET_PATTERNS = {
	"_|WARNING:%-DO%-NOT%-SHARE%-THIS", -- .ROBLOSECURITY cookie prefix
	"ghp_%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w", -- GitHub token
	"sk%-ant%-%w", -- Anthropic key
	"%-%-%-%-%-BEGIN [%u ]*PRIVATE KEY%-%-%-%-%-",
}

local function matchesAny(path: string, prefixes: { string }?): boolean
	if prefixes == nil then
		return false
	end
	for _, prefix in prefixes do
		if startsWith(path, prefix) then
			return true
		end
	end
	return false
end

for _, path in sourceFiles do
	local raw = fs.readFile(path)

	if not startsWith(raw, "--!strict") then
		fail(`{path}: must start with --!strict`)
	end

	for _, secret in SECRET_PATTERNS do
		if string.find(raw, secret) then
			fail(`{path}: looks like it contains a secret/credential — remove it immediately`)
		end
	end

	local code = stripComments(raw)
	local commentsOnly = raw -- markers like TODO/FIXME live in comments: scan the raw text
	for _, rule in RULES do
		local applies = rule.appliesTo == nil or matchesAny(path, rule.appliesTo)
		if applies and not matchesAny(path, rule.allowedIn) then
			local isMarker = rule.pattern == "FIXME" or rule.pattern == "XXX" or rule.pattern == "TODO"
			local haystack = if isMarker then commentsOnly else code
			if string.find(haystack, rule.pattern) then
				local message = `{path}: {rule.message}`
				if rule.severity == "error" then
					fail(message)
				else
					warnAbout(message)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------------------------
-- 4. Toolchain / dependency manifests
--------------------------------------------------------------------------------------------------

if fs.isFile("rokit.toml") then
	local rokit = serde.decode("toml", fs.readFile("rokit.toml"))
	for name, spec in rokit.tools or {} do
		if type(spec) ~= "string" or not string.find(spec, "@%d") then
			fail(`rokit.toml: tool "{name}" must be pinned to an exact version`)
		end
	end
else
	fail("rokit.toml: missing")
end

if fs.isFile("wally.toml") then
	local wally = serde.decode("toml", fs.readFile("wally.toml"))
	for section, deps in { dependencies = wally.dependencies, ["dev-dependencies"] = wally["dev-dependencies"] } do
		for alias, spec in deps or {} do
			if type(spec) ~= "string" or not string.find(spec, "@%d") then
				fail(`wally.toml [{section}]: "{alias}" must pin a version`)
			end
		end
	end
	if not fs.isFile("wally.lock") then
		fail("wally.lock: missing — run `wally install` and commit the lockfile")
	end
end

--------------------------------------------------------------------------------------------------
-- Report
--------------------------------------------------------------------------------------------------

for _, message in warnings do
	stdio.ewrite(stdio.color("yellow") .. "warning: " .. message .. stdio.color("reset") .. "\n")
end
for _, message in errors do
	stdio.ewrite(stdio.color("red") .. "error: " .. message .. stdio.color("reset") .. "\n")
end

if #errors > 0 then
	stdio.ewrite(stdio.color("red") .. `validate: {#errors} error(s)` .. stdio.color("reset") .. "\n")
	process.exit(1)
end
if not quiet then
	print(
		stdio.color("green")
			.. `validate: OK ({#sourceFiles} source files, {#warnings} warning(s))`
			.. stdio.color("reset")
	)
end
process.exit(0)
