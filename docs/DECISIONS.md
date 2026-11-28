# Decisions (ADRs) and dependency register

Format: each ADR states context, decision, consequences. Append new entries; never rewrite
history — supersede instead.

## Dependency register

Every tool and package, its purpose and status (checked 2026-11-12). All are free and open source.

| Dependency | Version | Purpose | Installed via | Maintenance |
|---|---|---|---|---|
| Rokit | 1.2.0 | Toolchain manager (pins every CLI per project) | official install script (`~/.rokit`) | Active (rojo-rbx org) |
| Rojo | 7.7.1 | Filesystem ↔ Studio sync, place builds, sourcemaps | rokit.toml | Active |
| StyLua | 2.6.0 | Formatter | rokit.toml | Active |
| Selene | 0.32.0 | Linter (Roblox std) | rokit.toml | Active |
| Wally | 0.3.2 | Luau package manager | rokit.toml | Maintained (stable, infrequent releases; de-facto standard) |
| Lune | 0.11.1 | Standalone Luau runtime: headless tests + tooling scripts | rokit.toml | Active |
| luau-lsp | 1.70.1 | Language server (VS Code) + `analyze` CLI for strict type checks | rokit.toml + VS Code extension | Active |
| TestEZ | 0.4.1 | BDD test framework (dev-only, test place only) | wally.toml `[dev-dependencies]` | **Archived** by Roblox (stable, feature-complete) — see ADR-004 |
| Roblox Studio | 0.747 (auto-updates) | Engine/runtime | Homebrew cask `robloxstudio` | Active |
| VS Code extensions | luau-lsp 1.70.1, StyLua 1.7.2, Selene 1.5.1, Rojo 2.1.2 | Editor integration | VS Code marketplace | Active |
| actionlint | 1.7.12 | Local lint of GitHub workflows (optional, dev machine only) | Homebrew | Active |
| GitHub Actions | checkout v7.0.1, cache v6.1.0, upload-artifact v7.0.2 (SHA-pinned) | CI on free hosted runners | workflow | Active (GitHub) |

Runtime Luau packages shipped to players: **none**.

---

## ADR-001 — Rokit instead of Aftman/Foreman

**Context.** The brief suggested `aftman.toml`. Aftman's repository is archived; Rokit is its
successor maintained under the rojo-rbx organisation and reads aftman/foreman manifests.
**Decision.** Use Rokit with `rokit.toml`, exact versions only (`make validate` enforces pins).
**Consequences.** One command (`rokit install`) reproduces the toolchain; CI installs Rokit from
the pinned release script. Developers must trust each tool once (security feature).

## ADR-002 — Single entry point per side + explicit Lifecycle

**Context.** Many Scripts with implicit execution order cause races and hidden coupling.
**Decision.** Exactly one Script (server) and one LocalScript (client); everything else is a
ModuleScript with `init` (sync) / `start` (threaded), booted from an explicit ordered list.
**Consequences.** Deterministic boot, fail-fast init errors, isolated start failures, easy
reasoning for humans and agents. Enforced by `make validate`.

## ADR-003 — Pure core / thin engine glue

**Context.** Roblox engine behaviour cannot run in CI.
**Decision.** Decisions live in pure modules with injected dependencies; services only translate
engine events into calls and apply results.
**Consequences.** Most logic is unit-tested headlessly in < 1 s; engine glue stays small and is
verified in Studio.

## ADR-004 — TestEZ on Lune for headless tests

**Context.** CI runners have no Roblox engine. Options: TestEZ (archived, stable, ubiquitous),
Jest-Lua (Roblox-maintained but heavy, last release 2024-12, needs an engine or heavy shims),
custom runner.
**Decision.** Run TestEZ 0.4.1 under Lune against the Rojo-built test place via a small runtime
(`tools/lib/RobloxRuntime.luau`). The same specs also run in Studio (`TestRunner.server.luau`).
**Consequences.** Real DataModel paths and requires in tests; CI-friendly exit codes. TestEZ is
archived: if it ever blocks us, migrate to Jest-Lua (similar describe/it/expect structure;
assertions differ) — specs are isolated in `tests/`.

## ADR-005 — Own seeded PRNG (xorshift32)

**Context.** Procedural content must be identical across servers and in headless tests; Lune does
not implement Roblox's `Random`.
**Decision.** `Shared/Utils/Prng` (bit32-only xorshift32 with warm-up).
**Consequences.** Bit-exact determinism everywhere. Not cryptographically secure (documented).

## ADR-006 — In-house session-locked persistence (no ProfileStore yet)

**Context.** ProfileStore is battle-tested but adds a third-party runtime dependency; the brief
asks for a reusable foundation with schemas, versioning, validation, retries, session consistency
and safe migrations, all testable.
**Decision.** `SessionStore` (UpdateAsync-based lock with expiry, migration and validation on
load, lock-owned saves) over a `Store` abstraction (`RobloxDataStore`, `InMemoryStore`).
**Consequences.** Fully covered by integration specs; small and auditable. Not implemented yet:
MemoryStore-based cross-server messaging, global leaderboards (OrderedDataStore), receipt
processing for purchases (must be added before monetisation — requires idempotent
`ProcessReceipt` with purchase history in the record). Revisit ProfileStore if needs outgrow it.

## ADR-007 — Server-only configuration split

**Context.** Everything in ReplicatedStorage is readable by exploiters.
**Decision.** `shared/Config/GameConfig` for public tuning, `server/ServerConfig` for policy
(store names, limits, lock timings).
**Consequences.** Clear rule for where values go; `ServerBoot.spec` checks ServerConfig is not
replicated.

## ADR-008 — Remotes declared centrally, created by the server

**Context.** Ad-hoc RemoteEvents scattered across scripts are the main source of exploits.
**Decision.** `shared/Net/Remotes.luau` declares channels; `ServerNet` creates them at boot and is
the only place allowed to attach inbound handlers (validation + rate limit mandatory).
`make validate` rejects `OnServerEvent`/`OnServerInvoke` elsewhere and any `OnClientInvoke`.
**Consequences.** One audit point for all network input.

## ADR-009 — Claude Code harness: default session + optional strict orchestrator

**Context.** A custom main-thread agent (`claude --agent orchestrator`) restricts tools and
forces delegation, which is slower and costlier for small edits.
**Decision.** Default sessions use Claude Code's standard agent guided by CLAUDE.md's
orchestration protocol; `orchestrator` is available for full delegation mode; `/feature` runs the
complete pipeline. All agents pin `claude-opus-5-5` with `effort: xhigh` (per project brief).
**Consequences.** Quality first; to reduce usage, lower `effort` in implementer agents to `high`.

## ADR-010 — Starling models built in shared code

**Context.** The 🐾 Starling Index shows every Starling as a 3D model (ViewportFrames), with
silhouettes for the ones not found yet, so the client needs the exact models the server builds.
**Decision.** `StarlingBuilder` moves from `Server/Systems/Base` to `Shared/Game`. It is pure
Instance construction from `Rarities` with nothing secret in it. Index copies are untagged so
`AmbientController` does not animate them.
**Consequences.** One model definition for the world, the Index and `make preview-models`. The
builder is public code from now on: it must stay free of server-only logic.

## ADR-011 — Local art tooling: Blender, rembg, Real-ESRGAN

**Context.** The owner wants the style sheet's art in the game and real 3D models instead of
primitive Parts, with a 0 € budget and without designing blind.
**Decision.** Art is produced by scripts with free, local tools installed outside the repo:
Blender (Homebrew cask, `tools/models/*.py`, run headless, renders a preview to look at) for
meshes; rembg (isnet-anime) and Real-ESRGAN ncnn (x4 anime) for cutting the style sheet's UI art
(`tools/art/`, installed by `tools/art/setup.sh` into `~/.cache/comet-raiders-art`). Outputs
(`assets/ui/*.png`, `assets/models/*.fbx`) are committed; the tools are not dependencies of the
game or of `make check`.
**Consequences.** Re-running a script regenerates its assets deterministically. Roblox only shows
uploaded images and meshes, so the owner imports them in Studio (Asset Manager / Import 3D); the
code keeps its Part/text fallbacks until the ids or imported models are wired in.
