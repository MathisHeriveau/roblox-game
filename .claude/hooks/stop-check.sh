#!/usr/bin/env bash
# Stop — before Claude ends a turn, run the full quality gate (`make check`) if any relevant file
# changed since the last green run. On failure, Claude is told to keep going and fix it.
# Loop-safe: never blocks twice in a row (stop_hook_active).
set -uo pipefail

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

project="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$project" || exit 0
export PATH="$HOME/.rokit/bin:$PATH"

# Tooling not installed yet (fresh clone): nothing to enforce.
command -v rojo >/dev/null 2>&1 || exit 0
[ -d DevPackages ] || exit 0

# Fingerprint of everything `make check` depends on.
fingerprint="$(
	find src tests tools .claude/hooks -type f \( -name '*.luau' -o -name '*.sh' -o -name '.luaurc' -o -name '*.toml' \) -print0 2>/dev/null \
		| sort -z | xargs -0 shasum 2>/dev/null
	shasum default.project.json test.project.json rokit.toml wally.toml selene.toml testez.yml .stylua.toml .luaurc Makefile 2>/dev/null
)"
hash="$(printf '%s' "$fingerprint" | shasum | cut -d' ' -f1)"
stamp=".cache/last-green-check"
if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$hash" ]; then
	exit 0
fi

if output="$(make check 2>&1)"; then
	mkdir -p .cache && printf '%s' "$hash" >"$stamp"
	exit 0
fi

summary="$(printf '%s' "$output" | grep -vE '^\[(INFO|WARN)\]|didChangeWatchedFiles|✓' | tail -n 60)"
jq -n --arg reason "\`make check\` failed after your changes. Fix the problems below (or explain to the user why they must remain) before finishing:

$summary" '{decision: "block", reason: $reason}'
exit 0
