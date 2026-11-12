---
description: Run the full quality gate (format, lint, strict types, architecture validation, tests) and fix any failure at its root cause.
---

Run `make check`.

If it passes, report the test summary line and stop.

If it fails:
1. Identify the failing gate (format-check / lint / typecheck / validate / test) and read the
   full error output.
2. `make format` fixes formatting. For everything else, find the root cause in the code.
   Use the `debug-roblox` skill if the cause is unclear.
3. Never silence a failure: no disabling lint rules, `--!nocheck`, `any` casts that hide real type
   errors, skipping/deleting tests, or loosening validation. If you believe a rule is wrong,
   explain why to the user instead of changing it.
4. Re-run `make check` until green, then summarise what was wrong and how it was fixed.
