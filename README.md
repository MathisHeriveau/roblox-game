# roblox-game

A code-first, test-driven foundation for Roblox games, with an AI engineering harness for
Claude Code. All source lives here; Roblox Studio only runs and visualises it, synced by Rojo.

The demo shows the full pipeline end to end:
- a procedurally generated, seeded terrain map with a spawn plateau and boundary walls
- collectibles detected and rewarded by the server
- a coin HUD generated in code
- session-locked, versioned persistence

## Prerequisites

| Requirement | Install |
|---|---|
| macOS / Windows / Linux | — (setup verified on macOS 26, Apple Silicon) |
| Git | preinstalled on macOS (`git --version`) |
| [Rokit](https://github.com/rojo-rbx/rokit) 1.2+ | `curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh \| bash` |
| Roblox Studio | https://create.roblox.com (macOS: `brew install --cask robloxstudio`) — sign in once |
| VS Code + recommended extensions | VS Code proposes them from `.vscode/extensions.json` |
| `make`, `bash`, `jq`, `curl` | preinstalled on macOS (jq ships with macOS 15+; else `brew install jq`) |
| Claude Code (optional) | https://code.claude.com |

Everything is free. Nothing in the setup requires a paid service.

## Installation

```bash
git clone <your-repo-url> roblox-game && cd roblox-game
make install        # rokit install (answer "y" to trust each pinned tool) + wally install + lune setup
make studio-plugin  # installs the Rojo plugin into Roblox Studio (matching the pinned Rojo)
make check          # format, lint, strict types, architecture validation, tests — should be green
```

## First launch

```bash
make dev            # Rojo sync server on port 34872
```

1. Open Roblox Studio and create or open any place (or run `make studio` to open a fresh build).
2. **Plugins → Rojo → Connect**. The project syncs into the place.
3. Press **Play**. You spawn on the plateau of a generated map. Walk into the yellow orbs and the
   coin counter (top right) goes up.

Without live sync: `make studio` builds `build/game.rbxl` and opens it directly.

## Testing

```bash
make test                                 # 84 headless specs (Lune + TestEZ), < 1 s
lune run tools/test.luau -- "SessionStore"  # filter by name
make studio-test                          # open the test place in Studio, press Play
```

See [docs/TESTING.md](docs/TESTING.md) for what runs where and the limits of headless testing.

## Build

```bash
make build          # build/game.rbxl, identical to the CI artifact
```

Publishing is deliberately manual: open the built place in Studio, then
*File → Publish to Roblox*. Automation and agents are blocked from publishing.

## Everyday commands

```
make help           list everything
make dev            live sync the game          make dev-test     live sync the test place
make format         format all Luau             make lint         Selene
make typecheck      strict luau-lsp analysis    make validate     architecture rules
make test           headless specs              make check        all of the above (CI)
make build          build/game.rbxl             make studio       build + open in Studio
```

## Using the AI harness (Claude Code)

```bash
cd roblox-game && claude          # Opus 5.5, effort xhigh, hooks and agents from .claude/
```

- Describe a feature, or run `/feature <description>`. The orchestrator gets a design from
  `roblox-architect`, delegates to `gameplay-engineer`, `backend-engineer`, `ui-engineer` and
  `qa-engineer`, then runs `security-auditor` and `code-reviewer`, and finishes on a green
  `make check`.
- `/check`: run the quality gate and fix failures. `/review`: security and code review of your
  changes.
- Hooks block destructive and publishing commands, protect generated files and secrets,
  auto-format, lint and type-check every edit, and run `make check` before Claude finishes.

Rules for agents and humans: [CLAUDE.md](CLAUDE.md).

## Architecture overview

```
src/server  ->  ServerScriptService.Server      Services (glue) + Systems (pure logic, adapters)
src/client  ->  StarterPlayerScripts.Client     Controllers + programmatic UI
src/shared  ->  ReplicatedStorage.Shared        Config, Net (remote declarations), Types, Utils
tests/      ->  ServerScriptService.Tests       unit / integration / fixtures (test place only)
tools/         Lune scripts: test runner, validator, typecheck
```

Details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Workflow:
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md). Decisions and the dependency register:
[docs/DECISIONS.md](docs/DECISIONS.md).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `command not found: rojo` | Open a new terminal (`~/.zshenv` loads Rokit) or run `export PATH="$HOME/.rokit/bin:$PATH"` |
| Studio says the Rojo version doesn't match | `make studio-plugin`, then restart Studio |
| Nothing syncs | Is `make dev` running? Plugins → Rojo → Connect (localhost:34872) |
| Type errors on `script.Parent.X` in VS Code | `make sourcemap`, then *Developer: Reload Window* |
| `TestEZ not found` | `make packages` |
| DataStore errors in Studio | Expected offline. Studio uses an in-memory store by default (see the `persistence` skill) |
| Hooks don't run | Check `jq` is installed and run `/hooks` in Claude Code. Scripts must be executable (`chmod +x .claude/hooks/*.sh`) |
