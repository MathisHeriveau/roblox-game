#!/usr/bin/env bash
# Strict Luau type checking with luau-lsp (same engine as the VS Code extension).
# Roblox API definitions are pinned to the luau-lsp version declared in rokit.toml.
set -euo pipefail
cd "$(dirname "$0")/.."

LUAU_LSP_VERSION="$(sed -n 's/^luau-lsp = "JohnnyMorganz\/luau-lsp@\(.*\)"$/\1/p' rokit.toml)"
if [ -z "$LUAU_LSP_VERSION" ]; then
	echo "typecheck: could not read luau-lsp version from rokit.toml" >&2
	exit 1
fi

# "None" = the security level of ordinary game scripts (no plugin-only APIs).
DEFS_DIR=".cache/luau-lsp/${LUAU_LSP_VERSION}"
DEFS_FILE="${DEFS_DIR}/globalTypes.None.d.luau"
if [ ! -s "$DEFS_FILE" ]; then
	mkdir -p "$DEFS_DIR"
	echo "typecheck: downloading Roblox type definitions for luau-lsp ${LUAU_LSP_VERSION}..."
	curl -fsSL --retry 3 \
		"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/${LUAU_LSP_VERSION}/scripts/globalTypes.None.d.luau" \
		-o "${DEFS_FILE}.tmp"
	mv "${DEFS_FILE}.tmp" "$DEFS_FILE"
fi

# The test project is a superset of the game project, so one sourcemap resolves src/ and tests/.
rojo sourcemap test.project.json --output sourcemap.json

TARGETS=("$@")
if [ ${#TARGETS[@]} -eq 0 ]; then
	TARGETS=(src tests)
fi

luau-lsp analyze \
	--platform=roblox \
	--sourcemap=sourcemap.json \
	--definitions=@roblox="$DEFS_FILE" \
	--base-luaurc=.luaurc \
	--formatter=default \
	--ignore="**/DevPackages/**" \
	--ignore="**/Packages/**" \
	"${TARGETS[@]}"
