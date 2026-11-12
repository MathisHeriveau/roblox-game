---
name: persistence
description: Add or change persisted player data safely — schema versioning, append-only migrations, validation, session-locked load/save, retries, and DataStore setup in Studio. Use whenever a feature stores anything across sessions (currency, inventory, settings, progression).
---

# Persistence

Stack (all in `src/server/Systems/Persistence/`, driven by `Services/PlayerDataService.luau`):

| Module | Role |
|---|---|
| `PlayerDataSchema` | type, defaults, `validate`, `VERSION`, append-only `MIGRATIONS` |
| `SessionStore` | session-locked `load`/`save` protocol (engine-agnostic, injected store/clock) |
| `RobloxDataStore` | real DataStoreService adapter (UpdateAsync, retries, budget, GDPR userIds) |
| `InMemoryStore` | test/Studio adapter with deep copies and failure injection |
| `PlayerDataService` | join/leave/autosave/BindToClose, `get`, `update`, `loaded`/`changed` signals |

## Adding a field (worked procedure)

1. **Type**: add the field to `PlayerData` in `PlayerDataSchema.luau`.
2. **Defaults**: add it to `defaults()`.
3. **Version**: increment `PlayerDataSchema.VERSION` (e.g. 2 → 3).
4. **Migration**: add `MIGRATIONS[2] = function(data) data.newField = <default>; return data end`.
   Migrations are pure, never yield, never removed once shipped, and only upgrade `n → n+1`.
5. **Validation**: extend `validate` (types, ranges, `isCount` for integers, string caps, array
   length caps, enum allow-lists).
6. **Fixtures**: add a record of the previous version to `tests/fixtures/PlayerRecords.luau`.
7. **Specs**: in `tests/unit/PlayerDataSchema.spec.luau` — previous version migrates and keeps
   values; invalid values rejected. If the load/save protocol is affected, extend
   `tests/integration/SessionStore.spec.luau`.
8. **Expose to clients** only via a projection (`PlayerStateService.toState`) if they need it.
9. **Mutate** only through `PlayerDataService.update(player, function(data) ... end)` — it
   validates the result and fires `changed`. The mutator must not yield.

## Invariants (never break these)

- Never load data written by a newer schema (rolling updates): `migrate` refuses → player kicked
  with a friendly message, data untouched.
- Never overwrite a record you could not read/migrate/validate.
- Never save without owning the session lock; never save after release.
- Never grant rewards before data is loaded (`PlayerDataService.isLoaded`).
- Keep records small (DataStore value limit is 4 MB; aim for KBs). Avoid unbounded arrays.
- Changing `ServerConfig.Persistence.DataStoreName` = wiping everyone's progress. Requires an ADR.

## Studio / production setup (DataStores do not work offline)

1. Publish the place (File → Publish to Roblox) — manual, user action.
2. Game Settings → Security → enable **Enable Studio Access to API Services**.
3. Set `ServerConfig.Persistence.UseInMemoryStoreInStudio = false` to hit real DataStores from
   Studio (prefer a separate test experience — Studio writes to the experience's real data).
4. Default (`true`) keeps Studio sessions on `InMemoryStore`: nothing persists between play tests.

## Testing session behaviour

Use `InMemoryStore` + several `SessionStore` instances with different `jobId`s and a controllable
clock (see the integration spec) to simulate: lock contention, crashed server (expired lock),
outages (`failNext`), corrupt and future-version records, and stale-server writes.
