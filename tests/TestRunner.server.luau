--!nocheck
-- Type checking disabled: thin glue over TestEZ, an untyped (archived) Lua library.
--[[
	Studio test runner — only present in the TEST place (test.project.json), never shipped.

	Runs every spec under Tests/unit and Tests/integration with the real engine when you press
	Play (or Run) in Studio. Results go to the Output window; the outcome is also exposed as the
	ServerScriptService attributes TestsPassed / TestsFailed for automation.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local TestEZ = require(ServerScriptService.DevPackages.TestEZ)

local results = TestEZ.TestBootstrap:run({
	script.Parent.unit,
	script.Parent.integration,
}, TestEZ.Reporters.TextReporter)

local passed = results.failureCount == 0 and #results.errors == 0
ServerScriptService:SetAttribute("TestsPassed", passed)
ServerScriptService:SetAttribute("TestsFailed", results.failureCount)
if passed then
	print(`[TestRunner] ALL TESTS PASSED ({results.successCount})`)
else
	warn(`[TestRunner] {results.failureCount} TEST(S) FAILED`)
end
