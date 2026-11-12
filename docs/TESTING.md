# Testing

## Layers

| Layer | Tool | Where | Runs in |
|---|---|---|---|
| Formatting | StyLua 2.6 | all `.luau` | `make format-check`, CI, post-edit hook |
| Lint | Selene 0.32 (`roblox+testez` std) | `src`, `tests`, `tools` | `make lint`, CI, post-edit hook |
| Static types | luau-lsp 1.70 `analyze`, strict, Roblox defs (security level None) | `src`, `tests` | `make typecheck`, CI, post-edit hook |
| Architecture rules | `tools/validate-project.luau` | projects, `src`, manifests | `make validate`, CI |
| Unit + integration specs | TestEZ 0.4.1 on Lune 0.11 | `tests/unit`, `tests/integration` | `make test`, CI |
| Engine tests | TestEZ in Roblox Studio | same specs + Studio-only specs | `make studio-test` → Play |
| Manual | Studio Play / multi-client / Device Emulator | — | before release |

## How headless tests work

`tools/test.luau`:

1. `rojo build test.project.json -o build/test.rbxl` — the real place, built from the same
   project mapping Studio uses.
2. `@lune/roblox` deserialises it into a DataModel with real Instances.
3. `tools/lib/RobloxRuntime.luau` executes ModuleScript sources with a Roblox-like environment:
   `script`, `game`, `workspace`, Instance-aware `require`, `task`, Roblox datatypes
   (Vector3, CFrame, Color3, UDim2, Enum, Instance, …), and `__LUNE_RUNTIME__ = true`.
4. TestEZ runs every `*.spec` under `ServerScriptService.Tests.unit` and `.integration`, with a
   reporter that does not depend on `TestService`. Exit code 1 on any failure or if no test ran.

### Limits of the headless runtime

No engine simulation: physics, Touched, replication, Players, RunService events, DataStores and
HTTP do not exist; derived properties such as `Part.Position` are unavailable (use
`CFrame.Position`); destroyed Instances cannot be read. Hence the architecture rule: keep
decisions pure and inject engine facts. Engine-dependent specs use:

```luau
describe("needs the engine", function()
	if __LUNE_RUNTIME__ then
		SKIP()
	end
	...
end)
```

### DataStores

Real DataStores are never used by automated tests. `InMemoryStore` implements the same
contract (UpdateAsync semantics, deep copies, failure injection) and `SessionStore` takes the
store, clock and job id by injection, so the full session-lock protocol is tested headlessly
(`tests/integration/SessionStore.spec.luau`). Verifying the real adapter requires a published
place with API access (see the `persistence` skill) — a manual step.

## Current suite

13 spec files, 84 headless tests + 3 Studio-only:

- unit: Prng, Guard, RateLimiter, Signal, Cleaner, Lifecycle, MapLayout, PlayerDataSchema,
  CollectibleRules, CoinCounter
- integration: SessionStore (locking, takeover, outages, corrupt/future data, stale writes),
  MapBuilder (Instance tree), ServerBoot (Studio only: map + remotes exist, server config not replicated)

## Running in Studio

```bash
make studio-test        # builds build/test.rbxl and opens it
```

Press **Play**. Output shows the TestEZ report and `[TestRunner] ALL TESTS PASSED (n)`; the
result is also stored as attributes `TestsPassed`/`TestsFailed` on ServerScriptService.

## Manual test checklist (demo)

- [ ] Play: map generates (Output: `[MapService] generated seed …`), you spawn on the plateau.
- [ ] Walk into a yellow orb: coin counter increments, orb disappears, reappears after 8 s.
- [ ] HUD stays readable in Device Emulator (phone portrait/landscape, tablet).
- [ ] Test → Clients and Servers (2 players): each player's counter is independent.
- [ ] Stop and Play again: coins reset (InMemoryStore in Studio — expected).
