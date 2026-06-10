# Player Astronaut Run30

AI-assisted astronaut player sprites generated from the user's thick-paint reference direction.

- Cell size: 64x64
- Final animation speed: 30 fps
- Run frames per direction: 30
- Idle frames per direction: 60
- Animations: 16 (idle/run x 8 directions)
- Godot resource: `assets/src/game/scene/player/resources/player_astronaut_run30_frames.tres`
- Sprite sheet: `sheet/player_astronaut_run30_64_sheet.png`

Source AI strips are copied into `source/`. The build script removes the green background,
normalizes the character to a shared foot baseline, redraws a transparent contact shadow, and
exports a SpriteFrames `.tres` for AnimatedSprite2D.
