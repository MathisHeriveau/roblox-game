---
name: luau-module
description: Write a strictly typed, idiomatic Luau ModuleScript for this codebase — module/class patterns, exported types, naming, error handling and performance. Use whenever creating or substantially changing any .luau module.
---

# Implementing a Luau module

## File skeleton

```luau
--!strict
--[[
	ModuleName — one-line purpose.

	Usage example and important constraints (yielding? server-only? pure?).
]]

-- 1. Services (game:GetService) — alphabetical
-- 2. Requires — alphabetical (StyLua sorts consecutive requires)
-- 3. Exported types
-- 4. Constants (LOUD_SNAKE_CASE)
-- 5. Module table, private functions, public functions
-- 6. return (frozen for stateless libraries: `return table.freeze(Module)`)
```

`--!strict` is mandatory in `src/` (`make validate` fails otherwise).

## Naming (Roblox Lua Style Guide)

| Thing | Style | Example |
|---|---|---|
| Module / class / type | PascalCase | `RateLimiter`, `PlayerData` |
| Functions, methods, locals, fields | camelCase | `tryConsume`, `lastPickupAt` |
| Constants | LOUD_SNAKE_CASE | `MAX_SAFE_INTEGER` |
| Private fields | `_camelCase` | `self._buckets` |
| Files | match the returned module | `RateLimiter.luau` |
| Services / Controllers | `<Name>Service` / `<Name>Controller` | `MapService` |
| Specs | `<Module>.spec.luau` in `tests/` | `RateLimiter.spec.luau` |

Engine APIs keep their PascalCase (`Instance.new`, `Part.Anchored`).

## Patterns

**Stateless library** — table of functions, frozen: see `Shared/Utils/Guard.luau`.

**Class** — metatable + typed `self` (see [templates/Class.luau](templates/Class.luau)):

```luau
local Thing = {}
Thing.__index = Thing
export type Thing = typeof(setmetatable({} :: { _value: number }, Thing))
function Thing.new(value: number): Thing return setmetatable({ _value = value }, Thing) end
function Thing.get(self: Thing): number return self._value end
```

**Dependency injection** — pass collaborators (clock, store, Prng, sleep) via an options table
so tests can substitute them (`SessionStore.new({ store, now, sleep, ... })`).

**Type-only modules** — export types and `return table.freeze({})` (a ModuleScript must return
exactly one value).

## Typing rules

- Annotate every public function signature; let locals infer.
- Model untrusted input as `unknown`, then narrow with `type()/typeof()` checks or Guard.
- Avoid `any`. When unavoidable (pcall arity quirks, untyped third-party code), cast at the
  narrowest point and leave a comment.
- Tables are invariant: a `{ Frame }` is not a `{ Instance }`. Accept `{ any }` + runtime assert,
  or use generics.
- Optional fields in config tables: annotate the literal (`{ ... } :: RateLimiter.Options`).

## Error handling

- Programmer errors (bad arguments, impossible states): `assert`/`error` with a message naming the
  module: `error("RateLimiter: capacity must be > 0")`.
- Expected failures (network, DataStore, invalid client input): return `(false, reason)`;
  never throw across a remote boundary.
- Wrap engine calls that can fail (DataStore, HTTP, MarketplaceService) in `pcall` with retries
  where appropriate.

## Performance

- No work per frame unless required; prefer events. Cache `game:GetService` results at the top.
- Use `table.create(n)` when size is known; avoid creating closures in hot loops.
- Never yield inside UpdateAsync transforms, `init()`, metamethods or `table.sort` comparators.
- Use `task.*` (never deprecated `wait`, `spawn`, `delay`, `tick` — Selene denies them).

## Verify

Save the file: the post-edit hook formats, lints and type-checks it. Then `make check`.
