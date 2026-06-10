# Layered Terrain Textures

The terrain renderer uses the terrain sheets directly at runtime. Each logical
tile remains 32 world units, while the source art is authored at 64 px and drawn
from resident atlas textures by `TerrainChunkCanvas.cs`.

## Layout

```text
assets/texture/terrain/
  base_soil/
    base/1x1.png
    base/2x2/2x2.png
    base/4x4/4x4.png
    shore/water_shadow_dual16.png
    shore/water_dual16.png
  dirt/
    base/1x1.png
    base/2x2/2x2.png
    base/4x4/4x4.png
    overlay/dual16.png
    shore/water_shadow_dual16.png
    shore/water_dual16.png
  grass/
    base/1x1.png
    base/2x2/2x2.png
    base/4x4/4x4.png
    overlay/dual16.png
    shore/water_shadow_dual16.png
    shore/water_dual16.png
  sand/
    base/1x1.png
    base/2x2/2x2.png
    base/4x4/4x4.png
    overlay/dual16.png
    shore/water_shadow_dual16.png
    shore/water_dual16.png
  water/
    base/1x1.png
    base/2x2/2x2.png
    base/4x4/4x4.png
    overlay/dual16.png
    effect/foam_dual16.png
  deep_water/
    base/1x1.png
    base/2x2/2x2.png
    base/4x4/4x4.png
    overlay/dual16.png
  dry_grass/, dry_dirt/, red_desert/, stone_ground/
    base/1x1.png
    base/2x2/2x2.png
    base/4x4/4x4.png
    overlay/dual16.png
    shore/water_shadow_dual16.png
    shore/water_dual16.png
```

Only runtime-loaded terrain atlases belong in this tree. Generated previews,
mask references, and other visual debugging artifacts should stay under
`dev-only/` so Godot does not import unused PNGs into the project.

## Sheet Rules

- `base/1x1.png` is `1024x64`: a single horizontal row of 16 cyclic
  full-tile variants, with each visual tile authored at 64 px.
- `base/2x2/2x2.png` is `2048x128`: a single horizontal row of 16 cyclic
  2x2 patch variants, with each patch authored at 128 px.
- `base/4x4/4x4.png` is `4096x256`: a single horizontal row of 16 cyclic
  4x4 patch variants, with each patch authored at 256 px.
- `overlay/dual16.png` is `1024x1024`: 16 mask columns by 16 cycle rows.
- `shore/water_shadow_dual16.png` is `1024x1024`: 16 mask columns by 16 cycle
  rows, drawn under the land shore rim to darken the water side of the coast.
- `shore/water_dual16.png` is `1024x1024`: 16 mask columns by 16 cycle rows.
- `water/effect/foam_dual16.png` is `1024x1024`: 16 mask columns by 16 cycle rows.
- `TerrainRuntime.cs` samples four logical corners per visual cell and emits
  atlas draw commands instead of rasterizing a new chunk image.
- `overlay/dual16.png` contains edge art only. Mask `0` and mask `15` are skipped; masks `1..14` draw partial terrain shapes.
- Mask bits are `1=TL`, `2=TR`, `4=BL`, `8=BR`.
- Full terrain art is a 16-variant cyclic set, not unrelated random tiles. The
  runtime renderer chooses `base/1x1.png` atlas coordinates from global
  visual-cell coordinates using `x % 4 + y % 4 * 4`; the selected variant is
  stored horizontally at `variant * 64, 0`. Large complete terrain areas stitch
  across logical tile boundaries.
- The horizontal atlas row must also be preview-safe: adjacent slots
  `0->1 ... 14->15` and `15->0` must be edge-compatible, including the
  visually easy-to-notice `3->4`, `7->8`, and `11->12` boundaries. Do not
  mechanically flatten a square source if that exposes seams in the row.
- Large pure-terrain areas may receive additional `2x2` or `4x4` base patches.
  Patch variants use `(x / patch_size) % 4 + (y / patch_size) % 4 * 4`, where
  `x/y` are global visual-cell coordinates and patch origins are aligned to the
  patch size. Patches are only drawn over pure cells, never mixed terrain
  boundaries.
- `1x1`, `2x2`, and `4x4` variants should follow the sand terrain's proven
  rule: rich granular material detail, close average brightness and texture
  density between variants, and no center-detail/edge-blend patch structure.
  Stronger pits, clumps, and stone beds may be present only when they dissolve
  into surrounding material and still read as part of the same continuous field.
- `2x2` and `4x4` patch edges must visually reconnect to the same terrain's
  `1x1` cycle and must also be edge-compatible across their horizontal atlas
  row. Keep unique details organic and low enough that a repeated patch does
  not become a visible puzzle piece when zoomed out.
- Runtime world tiles remain 32 world units. The 64 px source regions are drawn
  into 32 world-unit destinations, preserving close-view detail without changing
  gameplay coordinates or save data.
- Edge art uses the same cycle index. `overlay`, `shore`, and `foam` rows
  `0..15` correspond to `x % 4 + y % 4 * 4`, and are generated from the
  terrain `base/1x1.png` plus a continuous cyclic alpha mask field. This
  keeps boundary cells continuous with neighboring boundary and full-terrain
  cells.
- Dual16 edge art should be regenerated whenever `base/1x1.png` changes
  materially. The alpha field should stay organic at 64 px, keep mask `0` and
  mask `15` transparent, and slightly overlap complementary masks to avoid
  base-color cracks.
- Ordinary `overlay` masks use a shared terrain-independent alpha field with a
  small overlap between complementary masks. This prevents two land terrains,
  such as grass and sand, from leaving thin `base_soil` cracks between their
  edges.
- Water shoreline draw order is `shore shadow`, then `shore rim`, then `foam`.
  All three reuse the same dual16 mask convention and cycle rows.
- `shore/water_shadow_dual16.png` is land-specific under-shore shadow art for
  land corners that touch water. It should sit mostly on the water side and make
  the coast read as land above water.
- `shore/water_dual16.png` is land-specific shore rim art for the land side of
  the same edge.
- `water/effect/foam_dual16.png` is a top-layer water-edge foam/highlight sheet.
- Shore shadow, shore rim, and foam sheets leave mask `0` and mask `15` empty
  because they only describe mixed water-land edges.

The runtime renderer still does not require pair art for every arbitrary
land-land boundary. Terrain priority and dual16 masks decide which terrain sits
under or over another in a mixed visual cell.
