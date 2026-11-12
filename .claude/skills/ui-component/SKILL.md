---
name: ui-component
description: Build programmatic, responsive Roblox UI components and wire them through a client controller — Create helper, layout/constraints for phone to 4K, accessibility, state rendering, cleanup and headless tests. Use for HUDs, menus, dialogs, buttons, lists or any GuiObject work.
---

# Creating a UI component

UI is generated 100 % in code. Reference: `src/client/UI/Components/CoinCounter.luau` +
`src/client/Controllers/HudController.luau`.

## 1. Component contract

File: `src/client/UI/Components/<Name>.luau`.

```luau
export type Thing = {
	root: GuiObject,                       -- caller parents it
	setState: (...) -> (),                 -- pure rendering from plain values
	destroy: (() -> ())?,                  -- only if the component owns connections
}
function Thing.new(props): Thing
```

- Pure Instance construction with `Create(className, props, children)` — no services, no remotes,
  no PlayerGui access. That keeps it testable headlessly.
- Formatting helpers (numbers, time) are exported pure functions with specs.
- Rendering must never throw on hostile/odd input (NaN, negative, huge numbers, long strings).

## 2. Responsive layout recipe

- Sizes in Scale (`UDim2.fromScale`) + `UISizeConstraint` (min/max px) for legibility.
- Text: `TextScaled = true` + `UITextSizeConstraint { MaxTextSize = ... }`; `TextWrapped` for
  paragraphs; `RichText` only for trusted strings (never player-provided text).
- Position with `AnchorPoint` + scale, small pixel offsets for margins.
- Lists: `UIListLayout`/`UIGridLayout` + `UIPadding`; scrolling: `ScrollingFrame` with
  `AutomaticCanvasSize`.
- ScreenGui: `ResetOnSpawn = false` (persistent HUD), `ScreenInsets = CoreUISafeInsets`,
  `ZIndexBehavior = Sibling`.
- Touch targets ≥ 44×44 px; don't rely on hover; support gamepad selection
  (`Selectable`, `NextSelection*`) for menus.

## 3. Wire it in a controller

- `init()`: build component + ScreenGui (no yields).
- `start()`: parent to `Players.LocalPlayer:WaitForChild("PlayerGui")`, subscribe to state with
  `ClientNet.onEvent`, then request initial state with `ClientNet.invoke`.
- All connections and the ScreenGui go into the controller's `Cleaner`.
- User actions send intents via `ClientNet.fireServer` and wait for server state to update the UI
  (optimistic UI only for cosmetic feedback, always reconciled by server state).

## 4. Animation & performance

- `TweenService` for transitions; no per-frame property updates without need.
- Reuse instances (update text/visibility) instead of destroying/recreating on each update.
- Avoid huge numbers of GuiObjects in lists: virtualise or paginate past ~100 rows.

## 5. Tests

`tests/unit/<Name>.spec.luau` (see CoinCounter.spec): structure exists (constraints present),
`setState` renders expected text, formatting edge cases. Requires the module from
`StarterPlayer.StarterPlayerScripts.Client.UI.Components.<Name>`.

## 6. Manual verification

Studio → Test → Device Emulator: phone (portrait + landscape), tablet, 1080p and 4K; check safe
areas (notches), overlap with Roblox core UI (top bar, chat, leaderboard), readability.
