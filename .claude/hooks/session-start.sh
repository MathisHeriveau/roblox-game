#!/usr/bin/env bash
# SessionStart — gives Claude an accurate picture of the environment before any work starts.
# Plain stdout on exit 0 is added to Claude's context.
set -uo pipefail
cat >/dev/null # consume hook input

project="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$project" || exit 0
export PATH="$HOME/.rokit/bin:$PATH"

echo "## Environment status (from .claude/hooks/session-start.sh)"

missing=""
for tool in rojo stylua selene wally lune luau-lsp; do
	command -v "$tool" >/dev/null 2>&1 && "$tool" --version >/dev/null 2>&1 || missing="$missing $tool"
done
if [ -n "$missing" ]; then
	echo "- Toolchain: MISSING:$missing — tell the user to run \`make install\` (needs Rokit, see README)."
else
	echo "- Toolchain: OK ($(rojo --version 2>/dev/null), $(lune --version 2>/dev/null), luau-lsp $(luau-lsp --version 2>/dev/null))"
fi

if [ -d DevPackages ]; then
	echo "- Wally packages: installed"
else
	echo "- Wally packages: NOT installed — run \`make packages\` before testing."
fi

command -v jq >/dev/null 2>&1 || echo "- jq: MISSING — project hooks cannot run (brew install jq)."

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	branch="$(git branch --show-current 2>/dev/null)"
	dirty="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
	echo "- Git: branch '${branch:-detached}', $dirty uncommitted change(s)"
	if [ "$branch" = "main" ]; then
		echo "  (On main: create a feature branch before committing changes.)"
	fi
fi

echo "- Quality gate: \`make check\` (also enforced automatically when you stop)."
exit 0
