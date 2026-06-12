# AI Keyframe Workflow Export

Source reference: `source\idle_8dir_ai_2rows_fixed_clean.png`
AI keyframe sheet used: `ai_keyframe_workflow\raw\run_keyframes_5dir_raw.png`

- Key poses: 4 per generated direction
- Generated directions: down, down_right, right, up_right, up
- Mirrored directions: down_left, left, up_left
- Export animation frames: 30 per direction
- Cell size: 64x64
- FPS: 30
- Sprite sheet: `ai_keyframe_workflow\export\sheet\player_astronaut_ai_keyframes_run_64_sheet.png`

Manual cleanup loop:

1. Open `manual_cleanup/run_keyframes_5dir_cleaning_source.png`.
2. Paint corrections on the 5x4 sheet while keeping the same layout.
3. Save your corrected version as `manual_cleanup/run_keyframes_5dir_cleaned.png`.
4. Run `python tools/build_ai_keyframe_workflow.py` again.

The exporter will prefer `run_keyframes_5dir_cleaned.png` when it exists.
