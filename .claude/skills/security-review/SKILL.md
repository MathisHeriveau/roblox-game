---
name: security-review
description: Audit Roblox code for exploits — remote validation, server authority, rate limiting, reward/currency integrity, persistence races, permission boundaries, information leaks and secrets. Use before merging anything that touches remotes, rewards, data, admin features or client input.
---

# Roblox security review

Threat model: the exploiter controls their client completely — fires any remote with any
arguments at any rate, reads all client/ReplicatedStorage code, teleports and flies their
character, edits local physics and UI. They cannot touch ServerScriptService/ServerStorage.

## 1. Map the attack surface

```bash
# Every channel and its handler
grep -n "kind =" src/shared/Net/Remotes.luau
grep -rn "ServerNet.onEvent\|ServerNet.onInvoke" src/server
# Anything bypassing ServerNet (validate also enforces this)
grep -rn "OnServerEvent\|OnServerInvoke\|OnClientInvoke" src
# Touched/ProximityPrompt/ClickDetector entry points (server-side triggers)
grep -rn "Touched\|Triggered\|MouseClick" src/server
# Persistence and rewards
grep -rn "PlayerDataService.update\|coins\|DataStoreService" src/server
```

## 2. Checklist per entry point

**Validation**
- [ ] Declared in Remotes.luau with correct direction; registered via ServerNet with
      `Guard.tuple` covering every argument (exact arity) and a rate limit.
- [ ] Numbers: finite, integer where needed, min/max bounds. Strings: maxLength, pattern, UTF-8.
- [ ] Instance arguments: class checked, `IsDescendantOf` the expected container, player is
      allowed to act on it (ownership, distance).
- [ ] Tables from clients: avoid; if unavoidable, validate shape and size, ignore metatables.

**Authority**
- [ ] No client-supplied currency, price, damage, reward, item stats, position-as-truth or
      permission flag reaches game logic. Values are re-derived from config + server state.
- [ ] Server detects gameplay events itself (Touched/raycasts on the server) or re-validates
      the client's claim (distance from server-side character, line of sight, cooldown).
- [ ] Admin/debug features check a server-side allow-list (UserId/group rank), never a client
      flag; debug remotes are absent from production builds.

**Economy & persistence**
- [ ] Rewards only when `PlayerDataService.isLoaded(player)`.
- [ ] State flips before awarding (no double-collect in the same frame); idempotent handlers.
- [ ] All mutations via `PlayerDataService.update` (validated); no direct DataStore access.
- [ ] No yields between check and act (time-of-check/time-of-use races), or re-check after yield.
- [ ] Session lock respected; no save after release; schema validation on load and save.

**Denial of service**
- [ ] Rate limits on every inbound remote; bounded per-player tables (cleared on leave).
- [ ] No unbounded loops/allocations driven by client input (string length, counts).
- [ ] No server→client RemoteFunctions; no `WaitForChild` on client-controlled names.

**Information exposure**
- [ ] Nothing secret in `src/shared` or `src/client` (all replicated). Server policy in
      `src/server/ServerConfig.luau`.
- [ ] Clients receive projections, not raw records; errors are not echoed to clients.
- [ ] No secrets (API keys, cookies, webhooks) anywhere in the repo; HttpService secrets via
      `HttpService:GetSecret` configured in Creator Hub, never committed.

**Text & UGC**
- [ ] Player-provided text shown to other players is filtered with `TextService:FilterStringAsync`
      (server-side) and is never rendered with `RichText`.

## 3. Report

Use the format from the `security-auditor` agent: severity, file:line, exploit, fix. List
explicitly which areas were checked and clean.
