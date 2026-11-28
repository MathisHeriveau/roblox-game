# Playtest log — 2026-11-28

Studio play-solo session driven through the Studio MCP (`test.rbxl`, synced with
`make studio-sync`). One line per finding. Status: `FOUND` / `FIXED (commit)` /
`WONTFIX (why)` / `UNVERIFIED (why)`.

## Environment notes

- Studio cannot fetch avatar/animation assets (`HTTP 403`, `MeshContentProvider ... could not
  fetch`): environment, not game code. The character renders as default blocks.
- The MCP `user_keyboard_input` tool does not deliver key events to `UserInputService` /
  `ContextActionService` in this session (mouse clicks work). Keyboard shortcuts (Enter on the
  title, B, F, Escape) were checked by reading code, not by pressing keys.

## Findings

| # | Area | Finding | Status |
|---|---|---|---|
| 1 | Boot | TestRunner: 234 specs pass in Studio (`TestsFailed = 0`). | OK |
| 2 | Bases | Hatched Starlings were invisible: the client pinned every pedestal Starling to the world origin (under the plaza) because the tag replicated before the model's parts. | FIXED (a8e3062) |
| 3 | HUD | Pickup/info toasts are drawn over the comet banner (toasts at a fixed 190 px, the top column grows to ~270 px with the comet banner). Now stacked above the carry pill. | FIXED (b32450c) |
| 4 | Title | The Roblox chat window is drawn over the title screen (top-left), on top of the logo area. | FIXED (b06265e) |
| 5 | Onboarding | First shower: only 4 of 16 shards were in the Meadow (the rest show 🔒); the nearest grabbable one was 108 studs from the spawn. | FOUND |
| 6 | Title | After PLAY the camera kept the orbit's direction: often a close-up of a fence from inside the plot, the plot sign filling the top-left. Now behind the player, facing its base and the meadow. | FIXED (b06265e) |
| 7 | Shop | Escape does not close the shop (Roblox reserves Escape; the handler only saw a processed key). The open modal now closes when the Roblox menu opens, and on gamepad B. | UNVERIFIED (2a7f6ed; the MCP cannot press Escape or open the Roblox menu; X / click-outside verified) |
| 8 | Shop | Purchases work (Crystal Desert 400 → "UNLOCKED", Lava Fields shows 8K, status line in the shop). Locked zones only show a 🔒, not their price. | OK / FOUND (minor) |
| 9 | Input | Mouse wheel does not reach the game through the MCP either (scrolled the shop with CanvasPosition). | ENV |
| 10 | Menus | ⚙️ Settings toggles work: with sounds OFF no Sound is created on a pickup toast; guide OFF hides the golden trail while carrying. Settings are per session only (reset on rejoin). | OK / FOUND (not persisted) |
| 11 | Menus | 📊 Stats, 🎁 Gifts (claim → +150, ✓ on day 1, "NEXT IN 19:59:58", badge cleared), 🐾 Index (silhouettes; Epic filled after delivery with "+2% income forever"), 🏆 Top, 📅 Events countdowns all render and update. Only one panel at a time (a rail click while a panel is open hits the dim and closes it). | OK |
| 12 | Hazards | Lava burned silently (no flash, sound or message) and a fall left the camera on the empty void for 5 s with no explanation. Now: red flash + "ouch", "Lava! Get out" toast, death toast with the reason and lost shards, 3 s respawn. | FIXED (1115104, aa278f3) |
| 13 | World | Terrain textures fail to load in this Studio (HTTP 403 on terrain material assets): lava renders flat red with a green fringe, basalt near-black. Terrain look cannot be judged here. | ENV |
| 14 | Events | Comet warning said "Lava Fields", crash banner said "Crystal Desert". Not a bug: my capture was taken 217 s later, after the *next* comet (file timestamps). Re-checked with server + client event logs: warning, target, impact, core and banner all agree; one scheduler (one NextMeteorAt per shower). | WONTFIX (test artefact) |
| 15 | Bases | The collect-pad billboard ("💰 n / STEP HERE TO COLLECT", 8 × 2.4 studs) fills a third of the screen when you stand in your base and runs under the carry pill; other players' pads show it too. Now 5 × 1.6 studs and only your own is shown. | FIXED (ed833d9) |
| 16 | HUD | The coin counter and level badge sat under the Roblox chat window (top-left), hidden whenever chat shows. The left column (coins, level, lock pill, menu rail) is now one stack below the chat region. | FIXED (ed833d9) |
| 17 | Sky islands | Jump pad island 1: launched from (224, 15, 48), landed at (349, 33, 64) next to the target (352, 33, 64); "BACK TO LAND" return pad present. | OK |
| 18 | Hazards | Void: falling off the island kills below -110 and respawns at the plot; lava: 25 HP/s, death after ~4.7 s. | OK |
