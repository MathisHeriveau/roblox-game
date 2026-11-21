# Architecture

Comet Raiders: meteor showers drop star shards on a procedurally generated floating island;
players carry them home to hatch income-producing Starlings, raid each other's bases and defend
their own. Game design: [`GAME_DESIGN.md`](GAME_DESIGN.md). This document describes how the code
is organised and why.

## Goals

- **Code-first**: every script, the island, the bases and the whole UI are generated from this
  repository. Studio runs and visualises; it is never the source of truth.
- **Server authoritative**: clients send intents (buy, bump, hold a prompt); the server decides
  every reward, pickup, theft and price, and re-validates with its own facts.
- **Pure core, thin glue**: decisions live in pure modules (rules, layouts, economy, schemas)
  that run headlessly under Lune; services and controllers only gather engine facts and apply
  results.
- **Look at it**: anything visual or physical is also checked in Studio (see
  [`TESTING.md`](TESTING.md)); several engine behaviours below were only found that way.

## DataModel layout (Rojo)

| Filesystem | DataModel | Replicated to clients? |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | yes (public: no secrets) |
| `Packages/` (Wally, optional) | `ReplicatedStorage.Packages` | yes |
| `src/server` | `ServerScriptService.Server` (Script) | no |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` (LocalScript) | yes |
| `tests/`, `DevPackages/` | `ServerScriptService.Tests` / `.DevPackages` (**test place only**) | no |

`default.project.json` builds the game; `test.project.json` = game + tests + TestEZ. `make
validate` checks that the test place mirrors the game place and that test-only content never
ships. In the test place, `tests/TestRunner.server.luau` runs every spec when a Studio play test
starts and sets `TestsPassed` / `TestsFailed` attributes on `ServerScriptService`.

## Boot sequence

One entry point per side, booted by `Shared/Utils/Lifecycle` in two phases: every `init()` runs
synchronously in list order (must not yield; **one error aborts the whole boot**), then every
`start()` runs in its own thread. A module may only depend on modules listed before it.

```
Server (src/server/init.server.luau)
  WorldService        sky, lighting, bloom, Workspace.Gravity (jump pads are tuned for it)
  PlayerDataService   store (InMemory in Studio | DataStore), session-locked SessionStore
  MapService          MapLayout.generate(seed) -> MapBuilder.build -> Workspace.Map (in init)
  BaseService         8 plots around the plaza (Workspace.Bases), income, vault, collect pad, locks
  ShardService        Workspace.Shards; pickup / carry / drop / deliver loop (10 Hz)
  SkyEventService     initial shards, meteor showers, comets (Workspace attributes for countdowns)
  ShopService         RequestPurchase: upgrades, zone unlocks, rebirth
  DailyService        ClaimDaily: 7-day daily gift streak (amounts scale with income)
  CharacterService    WalkSpeed = Speed upgrade x carry slowdown x modifiers
  RaidService         steal Starlings from open bases, carry them home, recover on bump/death
  BumpService         RequestBump: nearest valid carrier drops a shard + knockback
  HazardService       lava damage and void deaths (4 Hz, position based)
  LeaderstatsService  player list columns: Coins, Level, Rebirths
  PlayerStateService  pushes PlayerState snapshots (coalesced), answers GetPlayerState

Client (src/client/init.client.luau)
  StateController        local copy of PlayerState (signal `changed`)
  NotificationController toasts + raid alarm flash
  TitleController        title screen (logo, PLAY, camera orbit); hides registered GUIs until PLAY
  ShopController         shop modal (B key, HUD buttons)
  MenuController         round icon rail ⚙️📊🎁 / 🐾🏆📅 and their panels (Settings, Stats, Gifts,
                         Starling Index with 3D ViewportFrames, Top raiders, Events)
  HudController          coins, star level badge, carry pill, SHOP/REBIRTH pills with "!" badges,
                         top-centre banner column, zone banner
  BaseController         own plot, prompt filtering, base lock pill
  HomeGuideController    golden beam to your base while carrying
  SkyEventController     meteor/comet visuals, countdowns, comet banner (mounted in the HUD column)
  InputController        bump (F / gamepad X / touch button), applies received knockback
  JumpPadController      jump pad launches (held flight)
  AmbientController      Starling bobbing, shard spin, 🔒 badges on shards of locked zones
```

The island is built during `init()` so terrain, plots and spawns exist before any character.

## Modules

### Shared (`ReplicatedStorage.Shared`, public)

| Module | Responsibility |
|---|---|
| `Config/GameConfig` | Frozen gameplay tuning: map, bases, economy, events, carry, bump, raid, hazards, world. |
| `Config/Zones` | Hub + 4 zones (Meadow, Crystal Desert, Lava Fields, Floating Sky Islands): rings, warp, unlock costs, rarity weights. `tierAt(x, z)` is shared by client and server. |
| `Config/Rarities`, `Config/Upgrades` | Six rarities (income, xp, colours; ids persisted). Speed, Backpack, Magnet, Pedestals upgrades (ids persisted). |
| `Game/Economy` | Every number of the progression: income, upgrade costs/effects, deliveries (hatch or sell), zone unlocks, rebirth, XP levels, offline earnings. Mutating functions validate first and error inside `PlayerDataService.update`. |
| `Game/Format`, `Game/RarityRoll`, `Game/ShardVisuals` | Safe number/time formatting; weighted rolls on an injected Prng; tags and visual constants shared by builders and client animation. |
| `Net/Remotes`, `Net/ClientNet` | Declaration of every channel (below); client API (`onEvent`, `fireServer`, `invoke` never throws). |
| `Types/PlayerState` | The client-visible projection of player data + runtime facts, and its validator. |
| `Utils/*` | `Guard` (untrusted value validation), `RateLimiter`, `Signal`, `Cleaner`, `Lifecycle`, `Log`, `Prng` (xorshift32, identical in Roblox and Lune). |

### Server (`ServerScriptService.Server`)

| Module | Responsibility |
|---|---|
| `ServerConfig` | Server-only policy: DataStore name, autosave, lock expiry, retries, rate limits, loop rates. |
| `Systems/ServerNet` | Creates remotes; inbound pipeline: direction → per-player rate limit → `Guard.tuple` → handler. |
| `Systems/Notifier` | Toasts to one or all players (`Notify`). |
| `Systems/Map/MapLayout` | Pure, seeded island: tiles (hub, 3 mainland zones, sky islands), lava pools, props, landmarks, jump pads with precomputed `velocity` + `flightTime`, shard landing candidates. |
| `Systems/Map/MapBuilder` | Layout → smooth Terrain (through an injected `TerrainWriter`) + Parts (props, landmarks, pads, bounds, plaza spawn). Compensates the engine's terrain surface offset (below). |
| `Systems/Base/BaseLayout` | Pure plot geometry: ring around the hub, entrance facing the centre, 12 pedestals, collect pad, spawn clear of the pad. |
| `Systems/Base/BaseBuilder` | Plot Instances (floor, fence, pedestals with Steal prompts, collect pad, sign, lock console, shield dome, SpawnLocation). |
| `Systems/Base/CollectPadRules` | Pure: the vault is banked once per visit to the pad. |
| `Systems/Shards/ShardRules` | Pure anti-exploit rules: pickup (distance, zone lock, capacity, drop protection), plausible delivery (anti-teleport), bump target and cooldown. |
| `Systems/Shards/SkySchedule`, `ShardBuilder` | Pure meteor/comet scheduling (counts, tiles, rarities) on an injected Prng; shard and comet core models. |
| `Systems/Raid/RaidRules` | Pure raid decisions: who can steal from whom (locks, beginner protection, busy, distance), base locks. |
| `Systems/Hazards/HazardRules` | Pure: `safe` / `lava` / `void` for a character root height and the tile under it. |
| `Systems/Persistence/*` | `PlayerDataSchema` (v4, migrations, validation), `StoreTypes`, `RobloxDataStore`, `InMemoryStore`, session-locked `SessionStore`. |
| `Services/*` | The engine glue listed in the boot sequence. Each header documents its public API. |

### Client (`StarterPlayerScripts.Client`)

| Module | Responsibility |
|---|---|
| `Controllers/*` | The glue listed in the boot sequence. |
| `UI/Create`, `UI/Theme`, `UI/Layers`, `UI/Modal` | Declarative Instance factory; art style helpers (candy gradient, gloss) and `scaleFor(viewport)`; one table of ScreenGui `DisplayOrder`s (HUD < base status < toasts < panels = shop < title); at most one modal open at a time. |
| `UI/Components/*` | `CoinPill`, `LevelBadge` (star), `CarryIndicator`, `PillButton` (wide candy button), `RoundButton` (round icon button), `Panel` (modal window; `Panel.connect` wires its clicks), `Logo`, `ShopCard`, `Toast`, `EventBanner` (countdowns + comet banner), `ZoneBanner`. Pure Instance construction, tested headlessly. |
| `Menu/MenuViews` | Pure view models of the menu panels (Index, Daily, Stats, Leaderboard, Events). |
| `Settings` | Local per-session toggles (sounds, effects, guide beam) read by `Sfx`, `Vfx`, `HomeGuideController`. |
| `Hud/ZoneAnnouncer` | Pure: which zone changes get the zone banner (never the zone you spawn in) and its texts. |
| `Hud/CometTracker` | Pure: comet banner state from the warning until a few seconds after the crash. |
| `Bases/PromptFilter` | Hides Steal/Lock prompts locally without losing the server's `Enabled` value. |
| `Movement/JumpFlight` | Pure: validates pad attributes and decides when a held jump pad flight ends. |
| `Effects/Sfx`, `Effects/Vfx` | Built-in sounds; local meteors, shockwaves, target markers, camera shake. |

## Gameplay data flow

- **Shards**: `SkyEventService` picks tiles and rarities (`SkySchedule`), `ShardService` spawns
  them (collectable after the impact delay). Pickups are detected by the server from character
  positions (magnet radius, zone lock unless comet core, capacity). Carried shards float above
  the head and slow the carrier. Entering your own plot delivers them: each trip must be
  physically plausible (`ShardRules.deliveryPlausible`, checked against every sky island's
  return pad trip by `TravelPlausibility.spec`), then `Economy.deliver` hatches Starlings or sells
  them when the base is full.
- **Income**: each second Starlings fill the base vault; stepping onto the collect pad banks it
  (once per visit). Offline time fills the vault at a reduced, capped rate.
- **Raids**: bases are locked at join (grace period) and by the owner at their console. On an
  open base, other players hold a Steal prompt; `RaidService` hides the Starling and sticks it
  to the thief, and data changes only when the thief reaches their own base. Bumping the thief,
  their death or leaving sends the Starling home with no data change.
- **Bumps**: the client only says "bump"; the server picks the nearest valid carrier
  (`ShardRules.bumpTarget`), drops their top shard (or recovers a stolen Starling) and sends the
  victim's client a `Knockback`.
- **Hazards**: lava tiles burn (25 HP/s); falling below `GameConfig.Hazards.VoidKillHeight` kills
  (respawn at your plot).
- **Progression**: `ShopService` sells upgrades, the next zone and rebirth (needs the last zone;
  resets coins, vault, zones, upgrades and Starlings for a permanent income multiplier).
- **Starling Index**: the first delivery of each rarity x shiny variant (12 entries) records it
  in `discovered`, pays a one-time discovery reward and adds +2 % income forever
  (`Economy.multiplier(rebirths, indexCount)`; survives rebirths). `Economy.baseIncome(data)` is
  the single income formula for the sign, the vault tick and offline earnings.
- **Daily gifts**: `DailyService` lets a player claim once per 20 h; the streak goes up to day 7
  (triple reward) and resets after 48 h without a claim. Rewards scale with base income.

## Networking

| Channel | Kind | Direction | Validation | Rate limit |
|---|---|---|---|---|
| `PlayerStateChanged` | Event | Server → client | server-built projection | coalesced, ≥ 0.2 s apart |
| `GetPlayerState` | Function | Client → server | `Guard.tuple()` (no arguments) | 5 burst, 1/s |
| `RequestPurchase` | Function | Client → server | `kind ∈ {upgrade, zone, rebirth}`, `id?` letters only, ≤ 16 chars | 8 burst, 3/s |
| `ClaimDaily` | Function | Client → server | `Guard.tuple()` (server decides eligibility and amount) | 3 burst, 0.2/s |
| `RequestBump` | Event | Client → server | `Guard.tuple()` (server picks the target) | 3 burst, 1/s |
| `Notify` | Event | Server → client | client checks types and length | n/a |
| `WorldEvent` | Event | Server → client(s) | cosmetic only (`meteors`, `cometWarning`, `cometImpact`, `raid`, `bump`) | n/a |
| `Knockback` | Event | Server → one client | client applies a bounded impulse | n/a |

Proximity prompts (Steal, Lock) are engine-validated triggers; their handlers re-check ownership,
locks and distance on the server.

### Replicated state without remotes

| Where | Attributes / tags | Read by |
|---|---|---|
| `Workspace` | `NextMeteorAt`, `NextCometAt`, `CometZone` (server time) | countdowns |
| `Workspace.Bases.Plot<n>` | `PlotIndex`, `OwnerUserId`, `LockedUntil` | BaseController (own plot, lock pill) |
| Shards (tag `Shard`, crystals `ShardCrystal`) | `ShardId`, `Rarity`, `Shiny`, `Tier`, `IsComet`, `HolderUserId` | AmbientController (spin, 🔒 badges) |
| Starlings (tag `Starling`, built by `Shared/Game/StarlingBuilder`) | — | AmbientController (bobbing); the Index builds untagged copies in ViewportFrames |
| `Player.leaderstats` | `Coins`, `Level`, `Rebirths` | player list, 🏆 Top panel |
| Jump pads (tag `JumpPad`) | `LaunchVelocity`, `FlightTime`, `Island`, `Kind` | JumpPadController |
| `Workspace.Map` | `Seed` | tests, debugging |

## Persistence

Record per key `player_<UserId>` in DataStore `PlayerData_v1`:

```
{ schemaVersion: number, data: PlayerData, session: { jobId, lockedAt }?, updatedAt: number }
```

Schema **v4**: `coins, vault, xp, rebirths, zoneTier, upgrades { speed, carry, magnet, slots },
starlings { rarity, shiny }[], lastSeen, discovered { [r1..r6 / r1s..r6s]: true },
dailyLastClaim, dailyStreak, stats { collectiblesCollected, sessions, shardsDelivered,
bumpsLanded, cometsCaught }` (migrations v1 → v2 → v3 → v4 kept; v3 → v4 counts owned Starlings
as discovered).

- **Load** (UpdateAsync): refuse while another live server holds the lock (retry with backoff,
  then kick); take over locks older than 30 min; migrate; refuse corrupt or newer-schema data
  without writing. No reward before data is loaded.
- **Save**: only while owning the lock; released on leave/shutdown; invalid data is never saved.
  Autosave every 120 s refreshes the lock.
- **Studio**: `InMemoryStore` unless `UseInMemoryStoreInStudio = false` on a published place with
  API access enabled.

## Engine behaviours the code relies on

Found by playtesting in Studio; each has a regression test.

| Behaviour | Consequence in code |
|---|---|
| `Workspace.FallenPartsDestroyHeight` needs the PluginOrOpenCloud capability: writing it from a game Script throws (and aborted the whole server boot). | Void deaths are detected by `HazardService` / `HazardRules` instead (`WorldService.spec`). |
| A client write to a replicated property sticks until the server changes it again. | `PromptFilter` remembers and restores the server value of hidden prompts. |
| A Humanoid steers its horizontal velocity in the air (to a stop without input), cancelling a one-off launch. | `JumpPadController` holds the planned horizontal velocity with a plane `LinearVelocity` for `FlightTime` (`JumpFlight.spec`, `MapBuilder.spec`). |
| Terrain renders a `FillBlock` top half a voxel (2 studs) above the block, at any height. | `MapBuilder` fills surface blocks `TERRAIN_SURFACE_OFFSET` lower so the walkable surface matches the layout (`TerrainSurface.spec`, Studio only). |
| A standing R15 root is ~3.3 studs above the ground; terrain rises up to ~2.2 studs at a lava pit's rim. | `HazardRules.LAVA_REACH = 6`. |
| Engine numbers are float32. | Specs compare engine properties with `.to.be.near`. |

## Testing

`make check` = format + lint + strict typecheck + validate + every spec headlessly under Lune.
Pure logic is in `tests/unit`, Instance trees and module interactions in `tests/integration`;
engine-only behaviour (server boot, terrain surface) runs in Studio and is skipped under Lune.
Details: [`TESTING.md`](TESTING.md).

## Extending

- New system → `roblox-system` skill. New remote → `multiplayer-feature` skill. New persisted
  field → `persistence` skill. New UI → `ui-component` skill. Map generation →
  `procedural-map` skill (and look at `make preview` plus in-engine captures).
- New ScreenGui → add its layer to `UI/Layers` and call `TitleController.hideWhileShowing` if it
  must stay hidden behind the title screen. New modal → `UI/Components/Panel` (one at a time via
  `UI/Modal`). New menu panel → a builder in `MenuController` + a pure view in `MenuViews`.
  New top-centre banner → `HudController.mountTop`.
- Third-party runtime libraries go in `wally.toml [dependencies]` → `ReplicatedStorage.Packages`
  (requires an ADR in [`DECISIONS.md`](DECISIONS.md)).
