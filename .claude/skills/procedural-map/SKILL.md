---
name: procedural-map
description: Generate maps and environments entirely from code — deterministic seeded layouts (pure data) built into Instances, with performance, streaming and testing rules. Use for terrain, levels, arenas, dungeons, obstacle courses, spawn placement or any procedural content.
---

# Procedural map generation

The project generates every environment in code. Reference implementation:
`src/server/Systems/Map/MapLayout.luau` (pure) → `MapBuilder.luau` (Instances) →
`Services/MapService.luau` (boot).

## The two-stage rule

1. **Layout (pure, deterministic).** `generate(config) -> Layout` returns plain tables
   (positions, sizes, ids, kinds). Uses only `Prng` (seeded) — never `math.random`,
   `Random.new()` without a seed, `os.time()` or `tick()`. Same seed → identical output on every
   runtime; this is what makes it unit-testable and reproducible across servers.
2. **Build (thin).** `build(layout, parent) -> refs` converts data to Instances. No decisions here
   beyond styling. Build the whole tree, then set `Parent` once at the end.

## Workflow for a new generator

1. Add a frozen config block in `GameConfig.luau` (seed, sizes, counts, tuning). Add a
   `validateConfig` that rejects impossible configs (e.g. more items than free cells).
2. Write `Systems/<Area>/<Name>Layout.luau`:
   - grid/graph generation from `Prng.new(config.Seed)`
   - smoothing/noise passes (see `generateHeights` box blur), whole-stud quantisation
   - placement with constraints (keep-out zones around spawn, no overlaps): use partial
     Fisher–Yates over candidate cells for unique picks
   - return ids that are stable for a given seed (`kind_x_z`) so other systems can refer to them
3. Write `<Name>Builder.luau` following MapBuilder conventions:
   - `Anchored = true` for static geometry; `CanTouch = false` and `CanQuery = false` where not
     needed (big physics savings); `CanCollide = false` for pickups
   - tag interactive parts with attributes (`part:SetAttribute("CollectibleId", id)`) or
     CollectionService tags rather than name parsing
   - group into Folders (`Tiles`, `Bounds`, `Collectibles`) for cheap lookup
4. Boot from a service's `init()` (synchronous) when the map must exist before characters spawn.
5. Tests (see `tests/unit/MapLayout.spec.luau`, `tests/integration/MapBuilder.spec.luau`):
   determinism (same seed equal, different seed differs), bounds, keep-out zones, counts,
   uniqueness, invalid config rejected, built tree shape/flags.

## Performance budget (mobile-first)

- Prefer fewer, larger parts; merge rows/columns of identical tiles when counts grow (>2–3k parts).
- Avoid unions/meshes generated at runtime unless cached.
- `StreamingEnabled` is on by default for new places: clients may not have distant parts. Client
  code must never assume a map part exists — use `WaitForChild` with timeouts or server events.
- For very large worlds: generate in chunks around players (Prng seeded per chunk:
  `Prng.new(seed + chunkX * 73856093 + chunkZ * 19349663)`), and yield between chunks in
  `start()`, never in `init()`.
- Terrain voxels (`Workspace.Terrain:FillBlock/FillRegion`) are an option for organic ground;
  keep the layout pure and do terrain writes in the builder.

## Debugging

- Log seed + counts + build time (MapService does this).
- Reproduce a bad map by seed in a spec before fixing it.
- In Studio, inspect `Workspace.Map` attributes (`Seed`) and use the Explorer filter.
