# Comet Raiders — game design

Concept art: `assets/concept/` (icon, thumbnail, style sheet with every colour).

## Pitch

Meteor showers rain star shards on a floating island. Grab them, carry them home on your head,
and watch them hatch into Starlings that earn coins forever. Steal other players' Starlings
from their open bases, and lock your own shield before someone steals yours.

## Core loop (30 seconds)

1. **Meteor shower** (every 40 s, countdown in the HUD): shards land all over the island, with
   light beams so you can spot them from far away.
2. **Grab**: walk near a shard (the Magnet upgrade widens the radius). You can only grab shards
   in zones you have unlocked. A 🔒 badge marks the others.
3. **Carry**: the shards stack above your head and slow you down (-6 % each). A golden beam
   shows the way home. Others can **bump** you (F / X / touch button) to make you drop one.
4. **Deliver**: step into your base. Each shard hatches into a **Starling** on a pedestal (or
   replaces your weakest one, or is sold if it's weaker).
5. **Collect**: Starlings fill your base vault with coins every second. Step on the green pad to
   bank them. They also earn while you're offline (25 %, up to 2 h).
6. **Spend**: Speed, Backpack, Magnet and Pedestal upgrades, then zone unlocks, then **Rebirth**
   (reset for a permanent income boost of +50 % per rebirth).

## Meta loop (minutes to hours)

- **Comets** (every 3.5 min) are announced 25 s ahead, with a red target and a banner. A comet
  core (Legendary or better) can be grabbed by anyone, even in a locked zone. Everybody rushes.
- **Raids**: when a base is open, hold *Steal* on a Starling and run it to your own base. The
  thief is slowed (x0.62), so a bump from anyone sends the Starling home. Owners lock their base
  at its console (60 s shield). New arrivals get 90 s of free protection, and players with fewer
  than 2 Starlings can't be raided.
- **Rarities**: Common, Rare, Epic, Legendary, Mythic, Cosmic, plus 4 % **Shiny** (x3 income,
  sparkles).
- **Levels**: XP from deliveries (double for shinies).
- **🐾 Starling Index**: 12 entries (6 rarities x shiny). Each first delivery pays a discovery
  bonus and adds +2 % income forever (up to +24 %), kept through rebirths. Undiscovered entries
  show as silhouettes: the collection chase.
- **🎁 Daily gifts**: a 7-day streak (claim every 20 h, reset after 48 h), day 7 pays triple.
  Rewards scale with income so they matter at every stage.
- **Menus** (round icon buttons of the style sheet): ⚙️ Settings, 📊 Stats, 🎁 Gifts, 🐾 Index,
  🏆 Top raiders of the server, 📅 Events with live countdowns. A title screen with the logo and
  a PLAY button opens every session.

## World

| Zone | Unlock | Terrain | Best shards |
|---|---|---|---|
| Comet Plaza (hub) | — | flat plaza, 8 bases, star monument | — |
| 🌿 Starting Meadow | free | gentle green hills, trees | Epic |
| 🏜️ Crystal Desert | 400 | sand dunes, crystal clusters, stone arches | Legendary |
| 🌋 Lava Fields | 8,000 | basalt, lava pools (25 dmg/s), 2 volcanoes | Mythic |
| ☁️ Floating Sky Islands | 150,000 | 7 islands over the void, reached by jump pads | Cosmic |

Zone borders are organic (angular warp). The island floats: fall off and you lose what you carry.

## Why it should be sticky (design levers)

- Short, readable loop with constant small wins (pickup toasts, hatching, coins ticking up).
- Scheduled events with countdowns give a reason to stay ("comet in 0:40").
- Risk and reward through distance: richer zones are farther away and higher, and carrying
  slows you down.
- Social tension: bumps, raids, revenge, defence. Locks need you to come back, so you return
  to your base regularly.
- Collection and rarity chase (6 rarities x shiny), offline earnings and rebirth multipliers.

## Not yet built (next milestones)

Quests, global leaderboards
(OrderedDataStore), Robux products (requires idempotent ProcessReceipt first), sound design
with custom assets, mobile UX pass in Device Emulator.
