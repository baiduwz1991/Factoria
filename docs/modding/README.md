# Factoria Modding API

Open `index.html` in a browser to read the local HTML documentation.

Contents:

- `index.html` - human-readable modding API guide.
- `schemas/` - JSON Schema contracts for mod files.
- `examples/simple_terrain_mod/` - copyable local mod example.

Current API version: `0.1`.

Version `0.1` supports loose-folder data/resource mods for terrain, terrain visuals, autoplace rules, and planet presets. Script mods are intentionally not supported.

## Mod-first workflow

New content ideas should usually begin as `user://mods/my_experiment_mod`, then iterate through `factoria.mod.json`, JSON content files, and resource images/audio/icons.

When the idea is proven, either:

- ship it as an independent official mod, or
- merge it into `assets/data/core` as default official content.

If an experiment exposes a missing engine capability, extend the base game API instead of hard-coding that content into gameplay code.

Good mod-first domains:

- Terrain and planet presets
- Resource distribution
- Items, recipes, building parameters, and tech tree data
- Decorations
- Audio, textures, and icons
- Future quest and story data

Do not force mod-first for:

- Chunk streaming algorithms
- Core save format logic
- The C# terrain rendering algorithm itself
- Controller lifecycle
- `UIManager` and `SceneManager`
- Performance-critical simulation kernels
- Network synchronization rules, if multiplayer is added later
