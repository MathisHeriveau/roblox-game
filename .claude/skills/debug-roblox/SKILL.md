---
name: debug-roblox
description: Diagnose problems in this Roblox project — failing checks/tests, Rojo sync issues, Studio runtime errors, replication and timing bugs, DataStore failures, performance and memory leaks. Use when something fails, behaves differently in Studio vs tests, or is slow.
---

# Debugging Roblox projects

Always find the root cause before changing code. Reproduce → isolate → explain → fix → add a
regression test.

## 1. Which layer fails?

| Symptom | Start here |
|---|---|
| `make check` fails | run each gate: `make format-check`, `make lint`, `make typecheck`, `make validate`, `make test` |
| Spec fails headlessly only | Lune runtime gap (see §3) vs real bug |
| Works in tests, fails in Studio | engine behaviour (yields, replication, StreamingEnabled, physics) |
| Studio shows old code | Rojo sync (§4) |
| Works solo, fails with 2+ players | replication/ownership/per-player state (§5) |

## 2. Reading failures

- Type errors: `file [DataModel path](line,col): TypeError: ...` — the DataModel path tells you
  how the module is required. Unknown property on `script.Parent.X` usually means sourcemap is
  stale: `make sourcemap` (the VS Code extension regenerates it automatically).
- Spec failures print the TestEZ path + stack trace with `[string "ServerScriptService.Tests..."]`
  frames; the top frame inside `src` modules is usually the culprit.
- Run one spec: `lune run tools/test.luau -- "SessionStore"`.

## 3. Headless (Lune) vs engine differences

Lune provides a real Instance tree and datatypes but no engine: no physics, no events firing,
no Players, no DataStores; derived properties (`Part.Position`) are unavailable; destroyed
Instances cannot be read; only the RunService stubs in `tools/lib/RobloxRuntime.luau` exist.
Fix by keeping logic pure and injecting engine facts — not by adding engine fakes everywhere.

## 4. Rojo sync

- `make dev` must be running; in Studio: Plugins → Rojo → Connect (port 34872).
- Plugin/server version mismatch → `make studio-plugin` (installs the plugin matching rokit.toml).
- Files not syncing: check they are inside a `$path` of `default.project.json`; `.spec.luau` files
  are deliberately excluded from the game project (use `make dev-test` for the test place).
- Script type: `init.server.luau` → Script, `init.client.luau` → LocalScript, else ModuleScript.

## 5. Runtime (Studio)

- Output window: filter by `[ServiceName]` (Log scopes). Errors in `start()` are logged by
  Lifecycle with a traceback; an `init()` failure stops boot entirely — read the first error.
- Test → Clients and Servers (2 players) to reproduce multiplayer issues; switch between the
  Server and Client views to compare state.
- Timing: anything the client reads may not exist yet → `WaitForChild(name, timeout)`; with
  StreamingEnabled, distant parts may never exist on the client.
- Races: look for yields (`task.wait`, `WaitForChild`, DataStore calls, `InvokeServer`) between a
  check and the action that depends on it.

## 6. DataStores

- "You must publish this place" / 403 → place unpublished or API access disabled (see the
  `persistence` skill). Default Studio sessions use InMemoryStore.
- Throttling warnings → too many requests; check autosave interval, avoid per-change saves.
- Kicked with "could not load your progress" → read the `PlayerDataService` log line: `Locked`
  (another server holds the session), `Unavailable` (outage), `Corrupt` (validation/migration).

## 7. Performance & memory

- MicroProfiler (Ctrl+F6) for frame spikes; Script Performance window for per-script cost.
- Developer Console (F9) → Memory → `LuaHeap` growth across joins/leaves indicates leaks:
  check per-player tables are cleared on PlayerRemoving and connections are in a Cleaner.
- Instance count: `#workspace:GetDescendants()`; physics: set `CanTouch/CanQuery = false` on
  static geometry, anchor what does not move.
- Profile before optimising; record the before/after numbers in the PR.
