# AI Keyframe Workflow

This folder is a controlled AI-keyframe pipeline for the astronaut run animation.

## Folder Layout

- `raw/`: raw AI outputs copied from image generation.
- `reference/`: split direction references from `source/idle_8dir_ai_2rows_fixed_clean.png`.
- `manual_cleanup/`: paint-over workspace for hand cleanup.
- `export/`: generated 64x64 keyframes, 30-frame run animations, previews, and sprite sheets.
- `prompts/`: prompts used to regenerate or iterate AI keyframes.

## Build

Run from `assets/frames/player_astronaut_run30`:

```bash
python tools/build_ai_keyframe_workflow.py
```

The exporter uses `manual_cleanup/run_keyframes_5dir_cleaned.png` when it exists.
Otherwise it uses `raw/run_keyframes_5dir_raw.png`.

## Manual Cleanup Loop

1. Open `manual_cleanup/run_keyframes_5dir_cleaning_source.png`.
2. Fix only the 5 generated directions: down, down_right, right, up_right, up.
3. Keep the sheet as 5 rows x 4 columns.
4. Save the edited file as `manual_cleanup/run_keyframes_5dir_cleaned.png`.
5. Re-run `python tools/build_ai_keyframe_workflow.py`.

The left-facing directions are mirrored automatically from right-facing directions.
