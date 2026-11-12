# Development workflow

## Daily loop

1. `make dev` — starts Rojo's sync server for the game (`default.project.json`).
2. Studio: open a place (or `make studio` to open a freshly built one), then
   **Plugins → Rojo → Connect**. Edits in VS Code sync instantly.
3. Edit code in VS Code. On save: StyLua formats; luau-lsp type-checks; Selene lints.
4. Press **Play** (F5) in Studio to run; **Test → Clients and Servers** for multiplayer.
5. `make check` before every commit.

To work on tests inside Studio, use `make dev-test` (syncs the test place, which also contains
specs, TestEZ and `TestRunner`) and press Play: results appear in Output.

## Working with Claude Code

```bash
cd ~/Roblox/roblox-game
claude                          # uses .claude/settings.json: Opus 5.5, effort xhigh, hooks
claude --agent orchestrator     # optional: whole session as the strict-delegation orchestrator
```

Inside a session:

- Describe a feature, or run `/feature <description>` for the full design → implement → test →
  review pipeline with the specialist agents.
- `/check` runs and fixes the quality gate; `/review` runs security + code review in parallel.
- `/status` shows loaded settings; `/hooks` shows the active hooks; `/agents` lists agents.

Hooks (see `.claude/settings.json`, scripts in `.claude/hooks/`):

| Event | Script | Effect |
|---|---|---|
| SessionStart | `session-start.sh` | reports toolchain/packages/git status to Claude |
| PreToolUse(Bash) | `guard-bash.sh` | blocks destructive/publishing/secret-reading commands |
| PreToolUse(Write/Edit) | `guard-write.sh` | blocks edits to generated files and secrets; asks before config changes |
| PostToolUse(Write/Edit) | `post-edit.sh` | formats, lints, type-checks the edited `.luau`, flags unfinished code |
| Stop | `stop-check.sh` | runs `make check` if relevant files changed; asks Claude to fix failures |

Hooks require `bash` and `jq` (both ship with macOS). Personal overrides go in
`.claude/settings.local.json` (git-ignored).

## Adding things

| Task | How |
|---|---|
| Tool (CLI) | `rokit add owner/repo@x.y.z` → commit `rokit.toml` → ADR in DECISIONS.md |
| Luau package | add to `wally.toml` → `make packages` → commit `wally.lock` → ADR |
| Service / controller | `roblox-system` skill (templates in `.claude/skills/roblox-system/templates`) |
| Remote | declare in `src/shared/Net/Remotes.luau`, register via `ServerNet` |
| Persisted field | `persistence` skill (version bump + migration + specs) |

## Build & publish

- `make build` → `build/game.rbxl` (the same artifact CI uploads).
- **Publishing is manual and deliberate**: open the built place in Studio and use
  *File → Publish to Roblox*, after `make check` is green on `main`. Agents are blocked from
  publishing (`rojo upload`, Open Cloud calls) by design.

## Git

- Branch per change (`feature/…`, `fix/…`, `chore/…`), Conventional Commits, PR to `main`.
- CI (`.github/workflows/ci.yml`) must be green before merging.

## Troubleshooting

| Problem | Fix |
|---|---|
| `rojo: command not found` | open a new terminal (Rokit adds `~/.rokit/bin` via `~/.zshenv`) or run `make tools` |
| Rokit asks to trust a tool | answer **y** — tools come from the pinned GitHub repos in `rokit.toml` |
| Rojo "version mismatch" in Studio | `make studio-plugin` (installs the plugin matching the pinned Rojo) |
| Red squiggles on `script.Parent.X` | sourcemap stale: save any file or `make sourcemap`; reload VS Code window |
| `TestEZ not found` when testing | `make packages` |
| DataStore errors in Studio | expected unless published + API access enabled; default uses InMemoryStore |
| Kicked with "could not load your progress" | see the PlayerDataService log line (Locked / Unavailable / Corrupt) |
