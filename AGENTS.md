# Factoria Development Notes

These notes are project-level guidance for future Codex development sessions.

## Mod-first content workflow

New content ideas should usually begin as a local experiment mod under `user://mods/my_experiment_mod`.

Recommended flow:

- Prototype with `factoria.mod.json`, JSON data files, and resource images/audio/icons.
- If the idea works as optional content, ship it as an independent official mod.
- If the idea should become default official content, merge it into `assets/data/core`.
- If the experiment exposes a missing engine capability, extend the base game API instead of hard-coding that content into gameplay code.

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

## Documentation rule

When changing the mod API or adding a new mod-supported content domain, update `docs/modding/index.html`, `docs/modding/README.md`, and the relevant JSON schemas/examples in `docs/modding/`.
