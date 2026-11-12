#!/usr/bin/env bash
# PreToolUse(Bash) — blocks destructive, irreversible or outward-facing shell commands.
# Exit 2 blocks the call; stderr is shown to Claude as the reason.
# Compatible with macOS /bin/bash 3.2. Requires jq.
set -uo pipefail

input="$(cat)"
command -v jq >/dev/null 2>&1 || { echo "guard-bash: jq is required (brew install jq)" >&2; exit 2; }
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"
[ -z "$cmd" ] && exit 0

# Collapse whitespace so patterns are simpler.
norm="$(printf '%s' "$cmd" | tr '\n\t' '  ' | tr -s ' ')"

block() {
	echo "BLOCKED by .claude/hooks/guard-bash.sh: $1" >&2
	echo "If this is truly intended, ask the user to run it themselves." >&2
	exit 2
}

matches() { printf '%s' "$norm" | grep -Eq -- "$1"; }

# --- Recursive deletion of broad or critical paths ------------------------------------------
# rm with a recursive flag (-r, -R, -rf, -fr, --recursive) targeting /, ~, $HOME, ., .., *, or a
# top-level project directory. `rm -rf build` (make clean) stays allowed.
RM_RECURSIVE='(^|[;&|( ])(sudo )?rm( -[^ ]+)* (-[^ ]*[rR][^ ]*|--recursive)( -[^ ]+)*'
CRITICAL_TARGET=' ("|'"'"')?(/|/\*|~|~/|~/\*|\$HOME|\$\{HOME\}|\.|\./|\.\.|\.\./|\*|\./\*|(\./)?(src|tests|tools|docs|\.git|\.claude|\.github)|/Users[^ ]*|/home[^ ]*)/?("|'"'"')?( |;|&|\||$)'
if matches "${RM_RECURSIVE}.*${CRITICAL_TARGET}"; then
	block "recursive deletion of a critical path"
fi
if matches '(^|[;&|( ])find .* -delete' && matches 'find (/|~|\$HOME|\.)( |$)'; then
	block "find -delete over a broad tree"
fi

# --- Git history / working tree destruction ---------------------------------------------------
matches 'git push.*( --force| -f( |$)| --force-with-lease| \+[^ ]+)' && block "force push rewrites shared history"
matches 'git reset .*--hard' && block "git reset --hard discards work"
matches 'git clean( -[^ ]*)* -[^ ]*f' && block "git clean -f deletes untracked files"
matches 'git checkout( --)? \.( |$)' && block "git checkout . discards all local changes"
matches 'git restore( --[^ ]+)* \.( |$)' && block "git restore . discards all local changes"
matches 'git (branch|tag) .*-D ' && block "force-deleting branches/tags"
matches '(commit|push|merge|rebase).* --no-verify' && block "--no-verify bypasses project checks"
matches 'git filter-(branch|repo)' && block "history rewriting"

# --- Publishing / outward-facing actions (must stay manual, see CLAUDE.md) ------------------
matches '(^|[;&|( ])rojo upload' && block "publishing to Roblox is a manual, user-authorized action"
matches '(rbxcloud|mantle (deploy|outputs)|tarmac sync)' && block "publishing/uploading to Roblox is manual"
matches 'apis\.roblox\.com' && block "direct Roblox Open Cloud API calls require explicit user authorization"
matches '(^|[;&|( ])wally publish' && block "publishing packages is manual"
matches 'gh (release (create|upload|delete)|repo (create|delete|edit)|secret )' && block "GitHub releases/repo settings/secrets are user decisions"

# --- Remote code execution & privilege escalation ------------------------------------------
matches '(curl|wget)[^|]*\| *(sudo )?(ba|z)?sh' && block "piping downloaded scripts into a shell"
matches '(^|[;&|( ])sudo ' && block "sudo is not allowed for agents"
matches 'chmod (-R )?777' && block "world-writable permissions"

# --- Secrets ----------------------------------------------------------------------------------
matches 'ROBLOSECURITY' && block "never read or handle Roblox session cookies"
matches 'security (find|dump)-(generic|internet)-password' && block "reading the macOS keychain"
matches '(cat|less|more|head|tail|cp|scp|curl).*(\.env( |$|\.)|id_rsa|id_ed25519|\.pem( |$))' && block "reading or moving secret files"

exit 0
