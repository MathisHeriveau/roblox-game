---
name: roblox-system
description: Create a new Roblox server Service or client Controller wired into the Lifecycle boot (init/start), with a pure-logic module, config and specs. Use when adding any new game system, service, controller or manager.
argument-hint: "[ServiceOrControllerName] [server|client]"
---

# Creating a Roblox system

A "system" = thin engine glue (Service on the server, Controller on the client) + pure logic
module(s) + config + specs. Follow these steps in order.

## 1. Decide placement

| Kind | Location | Sees |
|---|---|---|
| Server service | `src/server/Services/<Name>Service.luau` | everything (never replicated) |
| Server pure logic | `src/server/Systems/<Area>/<Thing>.luau` | plain data only |
| Client controller | `src/client/Controllers/<Name>Controller.luau` | ReplicatedStorage, LocalPlayer |
| Shared pure logic/types | `src/shared/...` | **public**: every client can read it |

Rules: shared code never requires server or client modules; client code never references
ServerScriptService/ServerStorage (`make validate` enforces both).

## 2. Write the pure logic first

Pure = takes plain values + injected dependencies (clock, Prng, store), returns results, no
`game:GetService` calls for runtime behaviour, no yields. Examples in the repo:
`Systems/Collectibles/CollectibleRules.luau`, `Systems/Map/MapLayout.luau`.

## 3. Write the service/controller from the template

Start from [templates/Service.luau](templates/Service.luau) or
[templates/Controller.luau](templates/Controller.luau). Contract (enforced by `Lifecycle.boot`):

- `name: string` — unique.
- `init(self)` — synchronous. Create state, register remote handlers, build Instances.
  **Must not yield** (no WaitForChild, task.wait, DataStore calls). Boot fails loudly otherwise.
- `start(self)` — runs in its own thread after every init succeeded. Connect events, start loops.
- Both functions exist even if empty (write a comment explaining why it is empty).

Resource hygiene: every `RBXScriptConnection`, Instance or thread goes into a module-level
`Cleaner`; every per-player table entry is removed on `Players.PlayerRemoving`.

## 4. Register it in boot order

Server: `src/server/init.server.luau`. Client: `src/client/init.client.luau`. A module may only
depend on modules listed **before** it.

## 5. Configuration

Gameplay tuning → `src/shared/Config/GameConfig.luau` (frozen, public).
Server-only policy (limits, anti-cheat thresholds you prefer not to advertise, store names) →
`src/server/ServerConfig.luau`. No magic numbers in logic.

## 6. Networking (if needed)

Use the `multiplayer-feature` skill: declare in `Remotes.luau`, register via `ServerNet` with a
Guard validator + rate limit, consume with `ClientNet`.

## 7. Tests

Unit specs for the pure logic in `tests/unit/`, integration specs in `tests/integration/` if
several modules interact (see the `write-tests` skill). Engine-only behaviour → Studio-only spec +
manual steps.

## 8. Verify

`make check` must pass. Then, in Studio (`make dev` + Rojo Connect, or `make studio`), press Play
and check the Output window for `[YourService]` logs and errors.

## Checklist

- [ ] Pure logic separated and unit-tested
- [ ] `init` does not yield; `start` owns long-running work
- [ ] Registered in boot order after its dependencies
- [ ] Cleaner owns connections; per-player state cleared on leave
- [ ] No client-trusted values; remotes validated + rate limited
- [ ] Config values, not magic numbers
- [ ] `make check` green; docs/ARCHITECTURE.md updated if the system is significant
