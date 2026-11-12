---
description: Implement a game feature end-to-end with the specialist agents — design, parallel implementation, tests, security + code review, green `make check`.
argument-hint: <feature description>
disable-model-invocation: true
---

# Feature pipeline

Feature request: **$ARGUMENTS**

You are acting as the orchestrator (see `.claude/agents/orchestrator.md` and CLAUDE.md §Agent
collaboration). Execute these phases in order; do not skip verification.

## Phase 1 — Understand
- Restate the feature as 3–8 testable acceptance criteria.
- List affected layers and existing modules to reuse (read them).
- If a product decision is genuinely ambiguous, ask the user ONE concise question with a
  recommended default; otherwise proceed and note assumptions.

## Phase 2 — Design
- Multi-layer feature, new remote, persisted data or new pattern → delegate to
  `roblox-architect` and wait for the design (module map, network contract, data changes, test
  plan, task breakdown with file ownership).
- Small, single-layer change → write a 5-line plan yourself.

## Phase 3 — Implement
- Create a branch if on `main`: `git checkout -b feature/<short-name>`.
- Delegate tasks to `backend-engineer`, `gameplay-engineer`, `ui-engineer` with explicit file
  ownership, interfaces and acceptance criteria. Run independent tasks in parallel (one message,
  several Agent calls); never let two agents edit the same file.
- Delegate specs to `qa-engineer` (can run in parallel with implementation when interfaces are
  fixed by the design).

## Phase 4 — Integrate
- Read every diff (`git diff`). Resolve interface mismatches.
- Run `make check` until green. Never weaken a test, lint rule or type to get there.

## Phase 5 — Review
- Run `security-auditor` and `code-reviewer` in parallel on the diff.
- Fix all Must-fix / Critical / High findings (delegate or do), re-run `make check`.

## Phase 6 — Report to the user
- Summary of behaviour added, files changed, new remotes (with validators/limits), data schema
  changes (version, migration).
- Verification: `make check` result with test counts.
- Manual Studio steps to verify engine-dependent behaviour (`make studio` or `make dev` + Rojo
  Connect, Play / 2-player test).
- Suggested commit message (Conventional Commits). Do not push or publish.
