---
name: multiplayer-feature
description: Implement client/server networked features safely — declare remotes, register validated + rate-limited server handlers via ServerNet, consume via ClientNet, choose replication strategy (remotes vs attributes vs instances). Use for any RemoteEvent/RemoteFunction, replicated state or multiplayer interaction.
---

# Implementing a multiplayer feature

## 0. Choose the replication mechanism

| Need | Use |
|---|---|
| Client asks the server to do something | ClientToServer `Event` (intent) |
| Client needs a value now (initial sync) | ClientToServer `Function` (bounded, rate-limited) |
| Server pushes per-player state | ServerToClient `Event` to that player |
| High-frequency cosmetic updates (VFX, positions) | `UnreliableEvent` (may drop/reorder) |
| Simple shared value on an object everyone sees | `Instance:SetAttribute` (replicates automatically) |
| World objects | Instances created by the server in Workspace/ReplicatedStorage |

Never: server→client `RemoteFunction` (`OnClientInvoke` — a client can hang the server; `make
validate` rejects it).

## 1. Declare the channel

`src/shared/Net/Remotes.luau`:

```luau
-- Client -> server. Args: (itemId: string). Returns nothing; result arrives via PlayerStateChanged.
RequestEquip = table.freeze({ kind = "Event", direction = "ClientToServer" } :: Definition),
```

Document arguments, bounds and responses in the comment. ServerNet creates the Instances at boot.

## 2. Register the server handler (ServerNet only)

In the owning service's `init()`:

```luau
ServerNet.onEvent("RequestEquip", {
	validate = Guard.tuple(Guard.string({ maxLength = 32, pattern = "^[%w_]+$" })),
	rateLimit = ServerConfig.Network.RequestEquipRateLimit, -- { capacity, refillPerSecond }
}, function(player: Player, itemId: string)
	-- Arguments are validated (types/arity/bounds). Now validate *game state*:
	-- does the player own itemId? is the action allowed right now? Re-derive everything.
end)
```

The pipeline is: direction check → per-player token bucket → `Guard.tuple` (exact arity, so extra
or missing args are rejected) → handler (errors caught, logged, never leaked to the client).

Validation checklist for handlers:
- Re-derive prices/rewards/damage from config and server data — never from arguments.
- Check ownership, cooldowns, distance (server-side character position), alive state.
- Treat Instance arguments as hostile: check `IsDescendantOf`, class, and that the player may act
  on it.
- Make handlers idempotent where spam is possible.

## 3. Push state to clients

`ServerNet.fireClient("PlayerStateChanged", player, projection)` — send a projection, never raw
persisted data. Throttle/batch high-frequency updates (coalesce per Heartbeat at most).

## 4. Client side

```luau
cleaner:add(ClientNet.onEvent("PlayerStateChanged", render))  -- type-check payloads in render
local ok, state = ClientNet.invoke("GetPlayerState")           -- never throws
ClientNet.fireServer("RequestEquip", itemId)                   -- intent only
```

Initial sync pattern: connect the listener first, then invoke the getter (see HudController), so
no update is missed.

## 5. Tests

- Unit-test any pure decision logic used by the handler (ownership, pricing, cooldown rules).
- Unit-test the validator with abuse payloads: NaN, ±inf, huge strings, invalid UTF-8, wrong
  types, extra args, trailing nils (see `tests/unit/Guard.spec.luau`).
- Studio multi-client test: Test tab → Clients and Servers → 2 players; verify replication and
  that a second client cannot affect the first.

## 6. Security review

Run the `security-review` skill (or the `security-auditor` agent) on the diff before merging.
