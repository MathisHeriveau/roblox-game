---
description: Review the current changes with the security-auditor and code-reviewer agents in parallel, then consolidate prioritized findings.
argument-hint: "[optional: files or git ref range, default = uncommitted changes]"
---

Requested scope: "$ARGUMENTS". If that is empty, the scope is all uncommitted changes
(`git diff HEAD`) plus new untracked files.

1. Run `git status` and `git diff HEAD --stat` to establish the scope; include untracked files.
2. In ONE message, launch both agents in parallel on that scope:
   - `security-auditor` — exploit-focused review (remotes, authority, economy, persistence, DoS,
     information exposure).
   - `code-reviewer` — correctness, architecture rules, typing, resources/performance, tests.
3. Run `make check` yourself while they work.
4. Consolidate into one report, de-duplicated and ordered:
   **Critical / Must fix** → **High / Should fix** → **Consider**, each with file:line and fix.
5. Ask the user whether to apply the fixes (do not modify code in this command).
