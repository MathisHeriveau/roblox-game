--[[
	Headless test runner (Lune).

	Usage:
	  lune run tools/test.luau                 -- build test place, run every spec
	  lune run tools/test.luau -- <pattern>    -- only tests whose full name matches <pattern>
	  lune run tools/test.luau --no-build      -- reuse build/test.rbxl (CI builds it explicitly)

	It builds `test.project.json` with Rojo, loads the resulting place with RobloxRuntime and runs
	TestEZ against ServerScriptService.Tests. Exit code is non-zero on any failure, so it is safe
	to use in CI, Makefile targets and Claude Code hooks.
]]

local process = require("@lune/process")
local stdio = require("@lune/stdio")

local RobloxRuntime = require("./lib/RobloxRuntime")

local PLACE_PATH = "build/test.rbxl"

local function parseArgs(args: { string })
	local options = { build = true, pattern = nil :: string? }
	for _, arg in args do
		if arg == "--no-build" then
			options.build = false
		elseif arg ~= "--" then
			options.pattern = arg
		end
	end
	return options
end

local function color(name: string, text: string): string
	return stdio.color(name :: any) .. text .. stdio.color("reset")
end

local function buildPlace()
	local result = process.exec("rojo", { "build", "test.project.json", "-o", PLACE_PATH })
	if not result.ok then
		stdio.ewrite(result.stderr .. result.stdout)
		stdio.ewrite(color("red", "rojo build failed\n"))
		process.exit(1)
	end
end

-- TestEZ reporter that does not depend on TestService (unavailable headlessly).
local function makeReporter(TestEnum: any)
	local reporter = {}

	local function visit(node: any, depth: number, lines: { string })
		if node.status == TestEnum.TestStatus.Skipped then
			table.insert(lines, string.rep("  ", depth) .. color("yellow", "~ " .. node.planNode.phrase))
			return
		end
		local label = node.planNode.phrase
		if node.status == TestEnum.TestStatus.Success then
			label = color("green", "✓ ") .. label
		elseif node.status == TestEnum.TestStatus.Failure then
			label = color("red", "✗ " .. label)
		end
		table.insert(lines, string.rep("  ", depth) .. label)
		table.sort(node.children, function(a, b)
			return a.planNode.phrase:lower() < b.planNode.phrase:lower()
		end)
		for _, child in node.children do
			visit(child, depth + 1, lines)
		end
	end

	function reporter.report(results: any)
		local lines = {}
		for _, child in results.children do
			visit(child, 0, lines)
		end
		print(table.concat(lines, "\n"))
		print("")
		for _, message in results.errors do
			print(color("red", message))
			print("")
		end
		local summary = `{results.successCount} passed, {results.failureCount} failed, {results.skippedCount} skipped`
		if results.failureCount > 0 or #results.errors > 0 then
			print(color("red", summary))
		else
			print(color("green", summary))
		end
	end

	return reporter
end

local options = parseArgs(process.args)
if options.build then
	buildPlace()
end

local runtime = RobloxRuntime.fromPlaceFile(PLACE_PATH)
local ServerScriptService = runtime.game:GetService("ServerScriptService")

local testEZModule = ServerScriptService:FindFirstChild("DevPackages")
	and ServerScriptService.DevPackages:FindFirstChild("TestEZ")
if not testEZModule then
	stdio.ewrite(color("red", "TestEZ not found in DevPackages. Run `wally install` (or `make install`).\n"))
	process.exit(1)
end

local TestEZ = runtime.require(testEZModule)
local TestEnum = runtime.require(testEZModule.Parent._Index["roblox_testez@0.4.1"].testez.TestEnum)

local testsRoot = ServerScriptService:FindFirstChild("Tests")
if not testsRoot then
	stdio.ewrite(color("red", "ServerScriptService.Tests is missing from test.project.json\n"))
	process.exit(1)
end

local roots = {}
for _, name in { "unit", "integration" } do
	local folder = testsRoot:FindFirstChild(name)
	if folder then
		table.insert(roots, folder)
	end
end

local results = TestEZ.TestBootstrap:run(roots, makeReporter(TestEnum), {
	testNamePattern = options.pattern,
	extraEnvironment = {},
})

if results.failureCount > 0 or #results.errors > 0 then
	process.exit(1)
end
if results.successCount == 0 then
	stdio.ewrite(color("red", "No tests were executed — treating as failure.\n"))
	process.exit(1)
end
process.exit(0)
