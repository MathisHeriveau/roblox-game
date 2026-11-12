# Architecture

## Goals

- **Code-first**: every script, map and UI element is generated from files in this repository.
  Studio runs and visualises; it is never the source of truth.
- **Server authoritative** multiplayer with validated, rate-limited networking.
- **Testable**: decisions live in pure modules that run headlessly in CI.
- **Genre-agnostic foundation**: services, networking, persistence and UI primitives that any
  game built on top can reuse.

## DataModel layout (Rojo)

| Filesystem | DataModel | Replicated to clients? |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | yes (public) |
| `Packages/` (Wally, optional) | `ReplicatedStorage.Packages` | yes |
| `src/server` | `ServerScriptService.Server` (Script) | no |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` (LocalScript) | yes |
| `tests/`, `DevPackages/` | `ServerScriptService.Tests` / `.DevPackages` (**test place only**) | no |

`default.project.json` builds the game; `test.project.json` = game + tests + TestEZ.
`make validate` guarantees the test place mirrors the game place exactly and that test-only
content never ships.

## Boot sequence

```
Server Script (init.server.luau)
  Lifecycle.boot({ PlayerDataService, PlayerStateService, MapService, CollectibleService })
    1. init() of each, in order, synchronously (a yield or error aborts boot)
         PlayerDataService   choose store (InMemory in Studio | DataStore), build SessionStore
         PlayerStateService  ServerNet.setup() -> creates ReplicatedStorage.Remotes; GetPlayerState handler
         MapService          MapLayout.generate(seed) -> MapBuilder.build -> Workspace.Map
         CollectibleService  (nothing)
    2. start() of each, each in its own thread
         PlayerDataService   PlayerAdded/Removing, autosave loop, BindToClose flush
         PlayerStateService  push PlayerState on loaded/changed
         CollectibleService  bind Touched on every collectible

Client LocalScript (init.client.luau)
  Lifecycle.boot({ HudController })
    init()  build CoinCounter + ScreenGui (no yields)
    start() parent to PlayerGui, listen PlayerStateChanged, invoke GetPlayerState
```

The map is built during `init()` so it exists before any character spawns.

## Modules

### Shared (`ReplicatedStorage.Shared`)

| Module | Responsibility |
|---|---|
| `Config/GameConfig` | Frozen gameplay tuning (map, collectibles, UI). Public. |
| `Net/Remotes` | Declares every channel: name, kind (`Event`/`UnreliableEvent`/`Function`), direction. |
| `Net/ClientNet` | Client API: `onEvent`, `fireServer`, `invoke` (never throws). |
| `Types/PlayerState` | Client-visible projection of player data. |
| `Utils/Guard` | Runtime validators for untrusted values (`number`, `integer`, `string`, `oneOf`, `instanceOf`, `optional`, `tuple`). |
| `Utils/RateLimiter` | Token bucket per key with injectable clock. |
| `Utils/Signal` | In-process events (error-isolated handlers). |
| `Utils/Cleaner` | Owns connections/instances/threads/callbacks; releases in reverse order. |
| `Utils/Lifecycle` | Two-phase boot (`init` sync, `start` threaded). |
| `Utils/Log` | Scoped, levelled logging. |
| `Utils/Prng` | Deterministic xorshift32 PRNG (identical in Roblox and Lune). |

### Server (`ServerScriptService.Server`)

| Module | Responsibility |
|---|---|
| `ServerConfig` | Server-only policy: DataStore name, autosave, lock expiry, retries, rate limits. |
| `Systems/ServerNet` | Creates remotes; inbound pipeline: direction → rate limit → Guard → handler. |
| `Systems/Map/MapLayout` | Pure procedural layout (tiles, heights, spawn, collectibles) from a seed. |
| `Systems/Map/MapBuilder` | Layout → Instances (anchored tiles, invisible bounds, collectibles, SpawnLocation). |
| `Systems/Collectibles/CollectibleRules` | Pure pickup decision (active, alive, loaded, distance, cooldown). |
| `Systems/Persistence/*` | Schema + migrations, Store abstraction (DataStore / in-memory), session-locked SessionStore. |
| `Services/PlayerDataService` | Session lifecycle, `get`/`update`/`isLoaded`, `loaded`/`changed` signals. |
| `Services/PlayerStateService` | Projects PlayerData → PlayerState; pushes updates; answers GetPlayerState. |
| `Services/MapService` | Generates/builds the map at boot; exposes layout and collectible parts. |
| `Services/CollectibleService` | Server-side Touched detection, validation, rewards, respawn. |

### Client (`StarterPlayerScripts.Client`)

| Module | Responsibility |
|---|---|
| `UI/Create` | Declarative Instance factory (props, children, Parent last). |
| `UI/Components/CoinCounter` | Responsive HUD widget + `formatNumber`. |
| `Controllers/HudController` | Builds the HUD, syncs it with PlayerState. |

## Networking

| Channel | Kind | Direction | Validation | Rate limit |
|---|---|---|---|---|
| `PlayerStateChanged` | Event | Server → client | n/a (server-built projection) | n/a |
| `GetPlayerState` | Function | Client → server | `Guard.tuple()` (no arguments allowed) | 5 burst, 1/s |

Pickups are detected server-side (Touched + distance check); no client remote can grant coins.

## Persistence

Record stored per key `player_<UserId>` in DataStore `PlayerData_v1`:

```
{ schemaVersion: number, data: PlayerData, session: { jobId, lockedAt }?, updatedAt: number }
```

- **Load** (UpdateAsync): refuse if another live server holds the lock (retry with backoff, then
  kick); take over locks older than 30 min (crashed server); migrate old schemas; refuse corrupt
  or newer-schema data without writing.
- **Save**: only while owning the lock; `release = true` on leave/shutdown; invalid data is never
  saved. Autosave every 120 s refreshes the lock.
- **Studio**: `InMemoryStore` unless `UseInMemoryStoreInStudio = false` and API access is enabled
  on a published place.
- **GDPR**: UpdateAsync tags keys with the player's UserId for Right-to-Erasure tooling.

Current schema: **v2** `{ coins, stats = { collectiblesCollected, sessions } }` (v1 → v2 migration
kept as the reference example).

## Extending the foundation

- New system → `roblox-system` skill. New remote → `multiplayer-feature` skill. New persisted
  field → `persistence` skill. New UI → `ui-component` skill. New map generator →
  `procedural-map` skill.
- Third-party runtime libraries go in `wally.toml [dependencies]` → `ReplicatedStorage.Packages`
  (requires an ADR).
