---
name: write-tests
description: Write TestEZ specs for this project — unit vs integration placement, headless (Lune) vs Studio-only tests, fixtures, fake clocks, abuse cases, and how to run them. Use when adding behaviour, fixing a bug (regression test first), or improving coverage.
---

# Writing tests

## How tests run

| Command | Runtime | What runs |
|---|---|---|
| `make test` | Lune (headless, CI) | `rojo build test.project.json` → real DataModel → TestEZ over `Tests/unit` + `Tests/integration` |
| `lune run tools/test.luau -- "<pattern>"` | Lune | only tests whose full name matches the Lua pattern |
| `make studio-test` then Play | Roblox engine | same specs + Studio-only specs, via `tests/TestRunner.server.luau` |

The headless runtime loads modules from the same place file Studio uses, so requires work
exactly as in game (`require(ServerScriptService.Server.Systems.Map.MapLayout)`).

## Spec file template

`tests/unit/<Module>.spec.luau` (see [templates/Example.spec.luau](templates/Example.spec.luau)):

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Thing = require(ReplicatedStorage.Shared.Utils.Thing)

return function()
	describe("Thing.method", function()
		it("does the normal thing", function()
			expect(Thing.method(1)).to.equal(2)
		end)
	end)
end
```

TestEZ API: `describe`, `it`, `beforeEach`, `afterEach`, `beforeAll`, `afterAll`, `SKIP()`,
`FOCUS()`; expectations `expect(x).to.equal(y)`, `.never.to.equal`, `.to.be.ok()` (not nil),
`.to.be.a("number")`, `.to.be.near(n, eps)`, `.to.throw()`. Wrap multi-return calls in
parentheses to take the first value: `expect((Guard.number()(5))).to.equal(true)`.

## Placement

- `tests/unit/` — one module, pure logic, deterministic. Instance construction is fine (Lune can
  create Instances); engine *behaviour* is not.
- `tests/integration/` — several modules together (SessionStore + InMemoryStore), built Instance
  trees (MapBuilder), boot checks.
- `tests/fixtures/` — functions returning fresh data (never shared mutable tables).
- Studio-only (physics, Touched, replication, Players, real DataStores, RunService events):

```luau
describe("needs the engine", function()
	if __LUNE_RUNTIME__ then
		SKIP()
	end
	-- ...
end)
```

## What to test (in order)

1. Normal behaviour with representative inputs.
2. Boundaries (0, max, empty, exactly-at-limit).
3. Invalid input and abuse: NaN, ±math.huge, negative, non-integer, wrong type, nil, extra
   arguments, huge/invalid-UTF-8 strings, spam (rate limits).
4. State transitions and cleanup (disconnect, remove, release).
5. Regressions: every fixed bug gets a test that failed before the fix.

## Determinism

- Time: inject a clock (`clock = function() return now end`) and advance `now` manually.
- Randomness: `Prng.new(seed)`; never `math.random` in tested code paths.
- Never `task.wait` real time in specs.

## Headless gotchas (Lune)

- Read `part.CFrame.Position`, not `part.Position`.
- Don't read properties of destroyed Instances; assert through a surviving parent.
- Service methods beyond the stubs in `tools/lib/RobloxRuntime.luau` don't exist; keep engine
  calls out of pure modules or inject them.
- `print`/`warn` output from expected-error tests is normal; only the summary decides.

## Finish

`make test` for the quick loop, `make check` before handing off. Report pass/fail/skip counts.
