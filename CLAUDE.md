# CLAUDE.md — Roblox game engineering rules

This file is binding for every agent working in this repository (main session and subagents).
When a rule here conflicts with a habit, the rule wins. Deeper context: `docs/ARCHITECTURE.md`,
`docs/DEVELOPMENT.md`, `docs/TESTING.md`, `docs/DECISIONS.md`.

## What this project is

A code-first Roblox (Luau) game foundation. **All source lives in this repo**; Roblox Studio is
only the runtime/visualiser, synced with Rojo. Maps, UI and systems are generated from code.
The current content is a technical demo (procedural map, collectibles, coins HUD, persistence),
not the final game.

## Commands (run from the repo root)

| Command | Purpose |
|---|---|
| `make check` | **The quality gate**: format-check + lint + strict typecheck + validate + tests. Must pass before any hand-off. |
| `make test` / `lune run tools/test.luau -- "<pattern>"` | Headless TestEZ specs (Lune) |
| `make format` · `make lint` · `make typecheck` · `make validate` | Individual gates |
| `make dev` / `make dev-test` | Rojo live sync of the game / test place into Studio |
| `make build` · `make studio` · `make studio-test` | Build place files (and open them in Studio) |

Tools are pinned in `rokit.toml` (Rojo, StyLua, Selene, Wally, Lune, luau-lsp). Never install
global alternatives or change versions without an ADR in `docs/DECISIONS.md`.

## Architecture (map)

```
src/server/  -> ServerScriptService.Server   (Script: init.server.luau = only server entry point)
  ServerConfig.luau        server-only policy (never replicated)
  Services/*Service.luau   engine glue, booted by Lifecycle in init.server.luau order
  Systems/<Area>/*.luau    pure logic + adapters (Map, Collectibles, Persistence, ServerNet)
src/client/  -> StarterPlayerScripts.Client  (LocalScript: init.client.luau = only client entry)
  Controllers/*Controller.luau   client glue, booted by Lifecycle
  UI/Create.luau, UI/Components/*  programmatic, responsive UI
src/shared/  -> ReplicatedStorage.Shared     (PUBLIC: every client can read it)
  Config/GameConfig.luau   frozen gameplay tuning
  Net/Remotes.luau         every network channel (single source of truth); ClientNet.luau
  Types/                   shared types (PlayerState)
  Utils/                   Guard, RateLimiter, Signal, Cleaner, Log, Lifecycle, Prng
tests/       -> ServerScriptService.Tests    (test place only): unit/, integration/, fixtures/
tools/       Lune scripts: test runner, project validator, typecheck
```

## Architecture rules

1. **One entry point per side.** Everything else is a ModuleScript. Services/controllers expose
   `name`, `init()` (synchronous, never yields) and `start()` (own thread, may yield), and are
   registered explicitly in `init.server.luau` / `init.client.luau` after their dependencies.
2. **Pure core, thin glue.** Decisions (rules, layouts, schemas, validation) live in pure modules
   that take plain data and injected dependencies (clock, Prng, store). Services gather engine
   facts, call pure logic, apply results.
3. **Dependency direction:** client → shared ← server. Shared never requires server/client code.
   Client never references ServerScriptService/ServerStorage. No circular requires.
4. **No hidden global state.** Module-level state is private to its owner and exposed through
   functions. Config is frozen.
5. **Explicit over magic:** explicit boot lists, explicit remote declarations, explicit types.
6. **Reuse the primitives** before writing new ones: Guard, RateLimiter, Signal, Cleaner, Log,
   Lifecycle, Prng, ServerNet/ClientNet, SessionStore, Create.

## Security rules (server authority)

- The server is authoritative. Clients send **intents**, never values. Never trust client input
  for currency, inventory, damage, rewards, progression, positions or permissions.
- Every network channel is declared in `src/shared/Net/Remotes.luau`. Inbound handlers are
  registered **only** via `ServerNet.onEvent/onInvoke` with a `Guard.tuple(...)` validator
  (exact arity, finite numbers, bounded strings) and a per-player rate limit.
- No server→client RemoteFunctions. Clients receive projections (e.g. `PlayerState`), never raw
  persisted records or server errors.
- Detect gameplay events on the server, or re-validate client claims (distance, alive, cooldown,
  ownership) with server-side facts.
- Nothing secret in `src/shared` or `src/client` (it all replicates). No credentials anywhere in
  the repo — hooks and `make validate` block common secret formats.
- Player-visible text from other players must be filtered (TextService) and never RichText.

## Persistence rules

- All DataStore access goes through `src/server/Systems/Persistence` (session-locked
  `SessionStore`). Mutations only via `PlayerDataService.update(player, mutator)`.
- Schema change = bump `PlayerDataSchema.VERSION` + append one migration + validation + fixtures
  + specs. Migrations are append-only and pure.
- Never overwrite unreadable/invalid/newer-schema data. Never save without the session lock.
  Never grant rewards before data is loaded.
- DataStores do not work offline. Studio uses `InMemoryStore` by default
  (`ServerConfig.Persistence.UseInMemoryStoreInStudio`). Real DataStores need a published place +
  "Enable Studio Access to API Services" — a user action.

## Coding standards

- `--!strict` first line of every file in `src/` (and specs). Annotate public signatures.
- Naming (Roblox Lua Style Guide): PascalCase modules/types/files, camelCase functions/locals/
  fields, LOUD_SNAKE_CASE constants, `_private` fields, `<Name>Service` / `<Name>Controller`.
- `.luau` extension only. StyLua formats (tabs, 120 cols); Selene denies deprecated APIs
  (`wait`, `spawn`, `delay`, `tick`) — use `task.*` and `os.clock()`.
- Expected failures return `(false, reason)`; programmer errors `error()`/`assert` with the module
  name. Wrap failing engine calls (DataStore, HTTP) in `pcall` with retries where it makes sense.
- Performance: event-driven, no per-frame work without profiling, `CanTouch/CanQuery=false` on
  static geometry, parent built trees once, connections in a `Cleaner`, per-player tables cleared
  on `PlayerRemoving`. Consider mobile (instance counts, UI size).
- Comments explain *why*. Module header states purpose, API and constraints.
- No `TODO`/`FIXME` left in `src/` (validate warns/fails) — finish it or track it in an issue.

## Testing rules

- New behaviour ships with TestEZ specs. Pure logic → `tests/unit/`; module interactions and
  Instance trees → `tests/integration/`; engine-only behaviour → Studio-only spec guarded by
  `if __LUNE_RUNTIME__ then SKIP() end` + manual steps in the report.
- Bug fix → failing regression test first.
- Cover abuse inputs (NaN, ±inf, wrong types, extra args, huge strings, spam) for anything that
  touches client input. Inject clocks/Prng; never wait real time.
- Never delete, skip or weaken a test to make `make check` pass.

## Git conventions

- Branch per change: `feature/…`, `fix/…`, `chore/…`, `docs/…`. Do not commit directly to `main`
  once the remote exists.
- Conventional Commits: `feat(collectibles): add respawn cooldown`, `fix(persistence): …`.
- Commit only when asked. Never force-push, rewrite history, `--no-verify`, or push without the
  user's explicit request. `make check` must be green before committing.
- Never commit build outputs, `DevPackages/`, `Packages/`, `sourcemap.json`, `.env` or secrets.

## Documentation rules

- Update `docs/ARCHITECTURE.md` when adding a service, system, remote or data field.
- Record significant decisions (new dependency, pattern, data format, trade-off) as an ADR in
  `docs/DECISIONS.md`; every dependency is listed there with purpose, version, maintenance status.
- Module headers stay accurate; README stays accurate for setup steps.

## Agent collaboration

Agents (`.claude/agents/`): `orchestrator` (lead), `roblox-architect` (design only),
`gameplay-engineer`, `ui-engineer`, `backend-engineer` (network + persistence), `qa-engineer`
(tests), `security-auditor` and `code-reviewer` (read-only reviewers).
Skills (`.claude/skills/`): roblox-system, luau-module, procedural-map, multiplayer-feature,
ui-component, persistence, write-tests, security-review, debug-roblox.
Commands: `/feature <description>` (full pipeline), `/check`, `/review`.

Protocol for non-trivial work (the main session acts as orchestrator):
1. Acceptance criteria first. Ask the user only for genuine product decisions.
2. Design with `roblox-architect` when a change spans layers, adds remotes or persisted data.
3. Delegate with explicit file ownership — two agents never edit the same file concurrently.
   Brief = goal, acceptance criteria, owned files, exact interfaces, skills to apply.
4. Integrate: read every diff, run `make check`.
5. Review: `security-auditor` + `code-reviewer` in parallel for anything touching remotes,
   rewards, data, permissions or input. Fix Critical/High before reporting.
6. Report honestly: what was verified headlessly, what needs manual Studio testing, open risks.

Small, local changes (a fix in one module) can be done directly — still with specs and
`make check`.

## Guardrails (enforced by hooks in `.claude/settings.json`)

- **Blocked**: destructive shell commands (recursive deletes of project/home paths, force push,
  reset --hard, clean -f, --no-verify), publishing/uploading (`rojo upload`, Open Cloud, wally
  publish), curl|sh, sudo, reading secrets; writing to generated files (DevPackages/, build/,
  sourcemap.json, wally.lock) or writing credentials.
- **Confirmation required**: edits to `.claude/settings.json`, hooks, CI workflows, rokit/wally
  manifests and Rojo project files.
- **Automatic**: every edited `.luau` is formatted, linted, type-checked and scanned for
  unfinished code; `make check` runs when a turn ends with relevant changes.
- Publishing the game, spending Robux/money, and pushing to remotes are **user actions only**.
