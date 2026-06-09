# Layered Terrain Map

This map module renders one logical `terrain_id` per tile through a C# terrain
runtime and atlas-backed chunk canvas nodes.

## Data Model

- `MapChunkData.tiles` stores exactly one terrain id per logical tile.
- `TerrainCatalog` owns the current terrain ids:
  - `base_soil`
  - `dirt`
  - `grass`
  - `sand`
  - `water`
  - `deep_water`
- `base_soil` is the default terrain and the landfill target.

## Rendering

The C# terrain code lives under `assets/src/csharp/terrain`. `TerrainRuntime`
consumes chunk tile snapshots and builds fixed visual data: base terrain/cycle
arrays, flattened overlay/shore/foam draw commands, and merged water collision
rectangles. It does not mutate `MapChunkData` or the save format.

`LayeredChunkMapView` talks to C# only through the global
`/root/CSharpRuntimeManager` Autoload, whose scene and script live under
`assets/src/core/csharp-manager`. The manager owns background terrain visual
jobs and creates `TerrainChunkCanvas` nodes on the main thread; map rendering
does not use a separate GDScript `WorkerThreadPool` task runner. The canvas draws
64 px atlas regions into 32 world-unit tiles using:

- `base/1x1.png` for the 16 horizontal cyclic full-tile variants.
- `base/2x2/2x2.png` and `base/4x4/4x4.png` for pure-terrain interior patch
  variants that reduce repetition in large areas.
- `overlay/dual16.png` for mixed land/land and water/deep-water masks.
- `shore/water_shadow_dual16.png` for water-side coast shadow under land edges.
- `shore/water_dual16.png` for the land-side shore rim.
- `water/effect/foam_dual16.png` for mixed water/land foam.

The runtime no longer creates chunk-sized `ImageTexture` instances during play.
C# worker jobs compute only compact pure-data visual results; atlas textures
stay resident and draw commands are cached by the canvas item until the chunk
changes.

Pure terrain interiors are detected in `TerrainRuntime` when all four visual
cell corners share the same terrain. The runtime greedily emits aligned `4x4`
patches first, then aligned `2x2` patches, while keeping `1x1` as the safe
bottom layer. Mixed cells still use the dual16 boundary sheets.

Startup preload uses the player's minimum camera zoom to cover the widest
possible view, plus a margin. Normal streaming prioritizes visible chunks,
prefetches in the movement direction, and cancels lower-priority far jobs when
visible chunks are pending.

Preload and runtime use different frame budgets. Preload keeps higher chunk
start, result drain, and install limits so the loading screen finishes quickly.
Runtime movement uses lower limits to avoid putting chunk generation, result
dictionary conversion, canvas installation, and first draw command creation into
the same frame.

Water collision is installed only for chunks near the player. Far preloaded
chunks keep visual data but do not create physics nodes until they enter the
collision window. Collision window refreshes are queued and processed with a
small per-frame budget instead of rebuilding every nearby chunk's physics nodes
in one movement frame.

## Chunk Edges

Before a job starts, `LayeredChunkMapView` builds an immutable terrain snapshot
for the current chunk plus the right/bottom sample border required by the
dual16 masks. The current chunk body is copied directly from `MapChunkData.tiles`;
only the right and bottom border cells use
`PlanetController.sample_terrain_id_for_render()`, which reads loaded chunks
first, then saved chunks, then falls back to generator single-tile sampling.
This keeps terrain masks continuous across chunk boundaries without generating
neighbor chunks just for rendering.

## Landfill

`PlanetController.landfill_tile(global_tile)` converts `water` or `deep_water` to `base_soil`, marks the chunk dirty, and returns `true`. Non-water terrain is unchanged and returns `false`.
