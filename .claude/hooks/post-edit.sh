#!/usr/bin/env bash
# PostToolUse(Write|Edit|MultiEdit) — immediate quality feedback on every edited Luau file:
#   1. format with StyLua (silently, in place)
#   2. lint with Selene
#   3. strict type check with luau-lsp (src/ and tests/ only)
#   4. detect unfinished code (FIXME/XXX/not-implemented stubs, missing --!strict)
# Problems are reported to Claude via stderr + exit 2 (the edit itself already happened).
set -uo pipefail

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')"

case "$file" in
	*.luau) ;;
	*) exit 0 ;;
esac
[ -f "$file" ] || exit 0

project="${CLAUDE_PROJECT_DIR:-$(pwd)}"
rel="${file#"$project"/}"
[ "$rel" = "$file" ] && exit 0 # outside the project

case "$rel" in
	DevPackages/* | Packages/* | build/* | .cache/*) exit 0 ;;
esac

cd "$project" || exit 0
export PATH="$HOME/.rokit/bin:$PATH"

problems=""
add() { problems="${problems}$1"$'\n'; }

# 1. Format (never a failure by itself — just normalise).
if command -v stylua >/dev/null 2>&1; then
	if ! out="$(stylua "$rel" 2>&1)"; then
		add "StyLua could not format $rel (syntax error?):"$'\n'"$out"
	fi
fi

# 2. Lint.
if command -v selene >/dev/null 2>&1; then
	# Selene exits non-zero on any error or warning; rely on the exit code, not on text.
	status=0
	case "$rel" in
		tools/*)
			out="$(cd tools && selene --config selene.toml --no-summary --display-style quiet "${rel#tools/}" 2>&1)" || status=$? ;;
		src/* | tests/*)
			out="$(selene --no-summary --display-style quiet "$rel" 2>&1)" || status=$? ;;
		*)
			out="" ;;
	esac
	if [ "$status" -ne 0 ]; then
		add "Selene:"$'\n'"$out"
	fi
fi

# 3. Type check (src/tests are strict Roblox code).
case "$rel" in
	src/* | tests/*)
		if command -v luau-lsp >/dev/null 2>&1 && command -v rojo >/dev/null 2>&1; then
			if ! out="$(./tools/typecheck.sh "$rel" 2>&1)"; then
				out="$(printf '%s' "$out" | grep -vE '^\[(INFO|WARN)\]|Created sourcemap|didChangeWatchedFiles')"
				add "Type errors (luau-lsp, strict):"$'\n'"$out"
			fi
		fi
		;;
esac

# 4. Unfinished / invalid code.
case "$rel" in
	src/*)
		head -n 1 "$rel" | grep -q '^--!strict' || add "$rel must start with --!strict."
		markers="$(grep -nE 'FIXME|XXX|error\(["'"'"']not implemented|NotImplemented' "$rel" || true)"
		[ -n "$markers" ] && add "Unfinished code markers in $rel:"$'\n'"$markers"
		;;
esac

if [ -n "$problems" ]; then
	{
		echo "Post-edit checks found problems in $rel — fix them before moving on:"
		printf '%s' "$problems"
	} >&2
	exit 2
fi
exit 0
