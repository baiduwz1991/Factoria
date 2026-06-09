# ADR 001: C# Terrain Runtime + Atlas Chunk Canvas

## Status

Accepted.

## Context

The previous terrain stream rendered each chunk into a large RGBA image and then
uploaded it as a new `ImageTexture`. With 2x terrain art this made initial
loading slower and created frame spikes while moving, especially when the camera
was zoomed out and many chunks entered view at once.

The map data model is still sound: `MapChunkData.tiles` stores one terrain id
per logical tile, and the save format should not change for a rendering
optimization.

## Decision

Move the terrain hot path to C# and stop generating chunk-sized textures during
play.

- `assets/src/csharp/terrain/TerrainRuntime.cs` builds compact visual data from immutable tile snapshots.
- `assets/src/csharp/terrain/TerrainChunkCanvas.cs` draws resident atlas regions into each chunk.
- `LayeredChunkMapView.gd` keeps scene ownership, preload progress, task
  scheduling, chunk unloads, and save-facing behavior in GDScript.
- Water collision is created only for chunks near the player and is reused while
  chunks remain loaded.

## Consequences

Runtime movement no longer pays for chunk image allocation, per-pixel GDScript
rasterization, or `ImageTexture.create_from_image()` uploads. The cost shifts to
small C# visual-data jobs plus cached canvas draw commands.

The visual boundary model now follows the existing `dual16` atlas sheets rather
than a procedural pixel ownership field. This makes art direction clearer:
terrain artists can inspect and replace base, overlay, shore, and foam sheets
without changing save data or gameplay logic.

The whole project does not need to migrate to C#. C# is reserved for the map
runtime hot path; GDScript remains appropriate for orchestration, UI, and
controller glue.
