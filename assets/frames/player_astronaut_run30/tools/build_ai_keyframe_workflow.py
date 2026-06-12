#!/usr/bin/env python3
from __future__ import annotations

import math
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "source"
WORKFLOW_DIR = ROOT / "ai_keyframe_workflow"
RAW_DIR = WORKFLOW_DIR / "raw"
REFERENCE_DIR = WORKFLOW_DIR / "reference"
MANUAL_DIR = WORKFLOW_DIR / "manual_cleanup"
EXPORT_DIR = WORKFLOW_DIR / "export"
KEYFRAME_DIR = EXPORT_DIR / "keyframes_64"
ANIM_DIR = EXPORT_DIR / "animations_64"
SHEET_DIR = EXPORT_DIR / "sheet"
PREVIEW_DIR = EXPORT_DIR / "preview"

REFERENCE_SHEET = SOURCE_DIR / "idle_8dir_ai_2rows_fixed_clean.png"
RAW_RUN_SHEET = RAW_DIR / "run_keyframes_5dir_raw.png"
MANUAL_RUN_SHEET = MANUAL_DIR / "run_keyframes_5dir_cleaned.png"
MANUAL_STARTER_SHEET = MANUAL_DIR / "run_keyframes_5dir_cleaning_source.png"

CELL = 64
RUN_FRAMES = 30
FPS = 30.0
BODY_BOTTOM_Y = 55
SHADOW_Y = 58
TARGET_BODY_HEIGHT = 52

REFERENCE_DIRECTIONS = [
    "down",
    "down_right",
    "right",
    "up_right",
    "up",
    "up_left",
    "left",
    "down_left",
]

AI_ROWS = ["down", "down_right", "right", "up_right", "up"]
DIRECTIONS = [
    "down",
    "down_right",
    "right",
    "up_right",
    "up",
    "up_left",
    "left",
    "down_left",
]
MIRROR_FROM = {
    "down_left": "down_right",
    "left": "right",
    "up_left": "up_right",
}


def ensure_dirs() -> None:
    for path in (
        RAW_DIR,
        REFERENCE_DIR,
        MANUAL_DIR,
        KEYFRAME_DIR,
        ANIM_DIR,
        SHEET_DIR,
        PREVIEW_DIR,
    ):
        path.mkdir(parents=True, exist_ok=True)


def alpha_bbox(image: Image.Image, threshold: int = 8) -> tuple[int, int, int, int] | None:
    alpha = np.array(image.getchannel("A"))
    ys, xs = np.where(alpha > threshold)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def crop_visible(image: Image.Image, pad: int = 4) -> Image.Image:
    bbox = alpha_bbox(image)
    if bbox is None:
        return image.copy()
    x0, y0, x1, y1 = bbox
    return image.crop(
        (
            max(0, x0 - pad),
            max(0, y0 - pad),
            min(image.width, x1 + pad),
            min(image.height, y1 + pad),
        )
    )


def remove_green(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    arr = np.array(rgba)
    rgb = arr[..., :3].astype(np.int16)
    r = rgb[..., 0]
    g = rgb[..., 1]
    b = rgb[..., 2]

    bright_key = (g > 120) & (g > r * 1.22 + 26) & (g > b * 1.22 + 26)
    dark_key = (g > 50) & (r < 72) & (b < 72) & (g > r + 26) & (g > b + 26)
    nearly_pure_key = (g > 80) & (r < 82) & (b < 82) & (g > r + 34) & (g > b + 34)
    green = bright_key | dark_key | nearly_pure_key

    alpha = np.where(green, 0, 255).astype(np.uint8)
    keep = alpha > 0
    green_spill = keep & (g > np.maximum(r, b) + 14)
    arr[..., 1] = np.where(green_spill, np.maximum(r, b) + 8, arr[..., 1]).astype(np.uint8)
    arr[..., 3] = alpha
    return Image.fromarray(arr, mode="RGBA")


def flatten_green_sheet(image: Image.Image) -> Image.Image:
    keyed = remove_green(image)
    flat = Image.new("RGBA", keyed.size, (0, 255, 0, 255))
    flat.alpha_composite(keyed)
    return flat.convert("RGB")


def sharpen(image: Image.Image) -> Image.Image:
    return ImageEnhance.Sharpness(image).enhance(1.18)


def normalize_bodies(frames: list[Image.Image]) -> list[Image.Image]:
    bboxes = [alpha_bbox(frame) for frame in frames]
    sizes = [(box[2] - box[0], box[3] - box[1]) for box in bboxes if box is not None]
    if not sizes:
        raise RuntimeError("No visible frames to normalize")

    heights = [size[1] for size in sizes]
    median_height = float(np.median(heights))
    base_scale = TARGET_BODY_HEIGHT / median_height

    normalized: list[Image.Image] = []
    for frame in frames:
        cropped = crop_visible(frame, pad=2)
        scale = min(
            base_scale,
            (CELL - 3) / max(1, cropped.width),
            (BODY_BOTTOM_Y - 3) / max(1, cropped.height),
        )
        new_size = (
            max(1, int(round(cropped.width * scale))),
            max(1, int(round(cropped.height * scale))),
        )
        resized = cropped.resize(new_size, Image.Resampling.LANCZOS)
        resized = sharpen(resized)
        box = alpha_bbox(resized)
        if box is None:
            normalized.append(Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0)))
            continue

        body_center_x = (box[0] + box[2]) / 2
        body_bottom = box[3]
        paste_x = int(round(CELL / 2 - body_center_x))
        paste_y = int(round(BODY_BOTTOM_Y - body_bottom))

        canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        canvas.alpha_composite(resized, (paste_x, paste_y))
        normalized.append(canvas)

    return normalized


def premultiplied_blend(a: Image.Image, b: Image.Image, amount: float) -> Image.Image:
    if amount <= 0.001:
        return a.copy()
    if amount >= 0.999:
        return b.copy()

    arr_a = np.array(a).astype(np.float32) / 255.0
    arr_b = np.array(b).astype(np.float32) / 255.0
    alpha_a = arr_a[..., 3:4]
    alpha_b = arr_b[..., 3:4]
    rgb_a = arr_a[..., :3] * alpha_a
    rgb_b = arr_b[..., :3] * alpha_b

    alpha = alpha_a * (1.0 - amount) + alpha_b * amount
    rgb = rgb_a * (1.0 - amount) + rgb_b * amount
    safe = np.maximum(alpha, 1e-6)
    rgb = np.where(alpha > 0, rgb / safe, 0)

    out = np.concatenate([rgb, alpha], axis=2)
    return Image.fromarray(np.clip(out * 255.0, 0, 255).astype(np.uint8), mode="RGBA")


def retime_bodies(frames: list[Image.Image], count: int = RUN_FRAMES) -> list[Image.Image]:
    output: list[Image.Image] = []
    source_count = len(frames)
    for index in range(count):
        source_pos = index * source_count / count
        left = int(math.floor(source_pos)) % source_count
        right = (left + 1) % source_count
        amount = source_pos - math.floor(source_pos)
        output.append(premultiplied_blend(frames[left], frames[right], amount))
    return output


def shadow_layer(body: Image.Image, frame_index: int, frame_count: int) -> Image.Image:
    layer = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    box = alpha_bbox(body, threshold=20)
    if box is None:
        return layer

    x0, _y0, x1, _y1 = box
    width = x1 - x0
    cx = (x0 + x1) / 2
    phase = frame_index / frame_count * math.tau
    pulse = 0.5 + 0.5 * math.cos(phase * 2.0)
    shadow_w = max(24.0, min(43.0, width * (0.72 + 0.12 * pulse)))
    shadow_h = 7.5 + 1.5 * pulse
    alpha = int(78 + 18 * pulse)

    mask = Image.new("L", (CELL, CELL), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse(
        (
            int(round(cx - shadow_w / 2)),
            int(round(SHADOW_Y - shadow_h / 2)),
            int(round(cx + shadow_w / 2)),
            int(round(SHADOW_Y + shadow_h / 2)),
        ),
        fill=alpha,
    )
    mask = mask.filter(ImageFilter.GaussianBlur(1.25))
    layer.putalpha(mask)
    return layer


def composite_with_shadow(body: Image.Image, frame_index: int, frame_count: int) -> Image.Image:
    frame = shadow_layer(body, frame_index, frame_count)
    frame.alpha_composite(body)
    return frame


def split_reference_sheet() -> None:
    image = Image.open(REFERENCE_SHEET).convert("RGB")
    cols, rows = 4, 2
    cell_w = image.width // cols
    cell_h = image.height // rows
    for index, direction in enumerate(REFERENCE_DIRECTIONS):
        col = index % cols
        row = index // cols
        crop = image.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
        rgba = crop_visible(remove_green(crop), pad=8)
        rgba.save(REFERENCE_DIR / f"{direction}_ref.png")


def source_sheet_path() -> Path:
    if MANUAL_RUN_SHEET.exists():
        return MANUAL_RUN_SHEET
    return RAW_RUN_SHEET


def make_manual_starter() -> None:
    if MANUAL_STARTER_SHEET.exists():
        return
    flat = flatten_green_sheet(Image.open(RAW_RUN_SHEET).convert("RGB"))
    flat.save(MANUAL_STARTER_SHEET)


def extract_ai_run_keyframes(path: Path) -> dict[str, list[Image.Image]]:
    image = Image.open(path).convert("RGB")
    cols = 4
    rows = 5
    cell_w = image.width // cols
    cell_h = image.height // rows

    keyframes: dict[str, list[Image.Image]] = {}
    for row, direction in enumerate(AI_ROWS):
        frames: list[Image.Image] = []
        for col in range(cols):
            crop = image.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
            frames.append(crop_visible(remove_green(crop), pad=5))
        keyframes[direction] = normalize_bodies(frames)

    for direction, source_direction in MIRROR_FROM.items():
        keyframes[direction] = [
            frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            for frame in keyframes[source_direction]
        ]

    return keyframes


def save_frame_groups(root: Path, groups: dict[str, list[Image.Image]], with_shadow: bool) -> None:
    if root.exists():
        shutil.rmtree(root)
    root.mkdir(parents=True, exist_ok=True)
    for direction, frames in groups.items():
        out_dir = root / f"run_{direction}"
        out_dir.mkdir(parents=True, exist_ok=True)
        for index, body in enumerate(frames):
            frame = composite_with_shadow(body, index, len(frames)) if with_shadow else body
            frame.save(out_dir / f"run_{direction}_{index:02d}.png")


def make_sheet(animation_frames: dict[str, list[Image.Image]]) -> Path:
    SHEET_DIR.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (RUN_FRAMES * CELL, len(DIRECTIONS) * CELL), (0, 0, 0, 0))
    for row, direction in enumerate(DIRECTIONS):
        for col, frame in enumerate(animation_frames[direction]):
            sheet.alpha_composite(frame, (col * CELL, row * CELL))
    path = SHEET_DIR / "player_astronaut_ai_keyframes_run_64_sheet.png"
    sheet.save(path)
    return path


def preview_frame(frame: Image.Image, bg: tuple[int, int, int] = (66, 66, 66)) -> Image.Image:
    image = Image.new("RGBA", frame.size, (*bg, 255))
    image.alpha_composite(frame)
    return image


def make_gif(frames: list[Image.Image], path: Path) -> None:
    rendered = [preview_frame(frame).convert("P", palette=Image.Palette.ADAPTIVE) for frame in frames]
    rendered[0].save(
        path,
        save_all=True,
        append_images=rendered[1:],
        duration=round(1000 / FPS),
        loop=0,
        disposal=2,
    )


def make_preview(animation_frames: dict[str, list[Image.Image]]) -> None:
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    sample_count = 6
    tile_gap = 8
    width = sample_count * CELL + (sample_count - 1) * tile_gap
    height = len(DIRECTIONS) * CELL + (len(DIRECTIONS) - 1) * tile_gap
    preview = Image.new("RGBA", (width, height), (66, 66, 66, 255))

    for row, direction in enumerate(DIRECTIONS):
        y = row * (CELL + tile_gap)
        sample_indices = [
            min(RUN_FRAMES - 1, round(i * RUN_FRAMES / sample_count))
            for i in range(sample_count)
        ]
        for col, frame_index in enumerate(sample_indices):
            x = col * (CELL + tile_gap)
            preview.alpha_composite(animation_frames[direction][frame_index], (x, y))
    preview.save(PREVIEW_DIR / "run_ai_keyframes_preview.png")

    for direction in DIRECTIONS:
        make_gif(animation_frames[direction], PREVIEW_DIR / f"run_{direction}.gif")


def write_manifest(sheet_path: Path, source_path: Path) -> None:
    text = f"""# AI Keyframe Workflow Export

Source reference: `{REFERENCE_SHEET.relative_to(ROOT)}`
AI keyframe sheet used: `{source_path.relative_to(ROOT)}`

- Key poses: 4 per generated direction
- Generated directions: down, down_right, right, up_right, up
- Mirrored directions: down_left, left, up_left
- Export animation frames: {RUN_FRAMES} per direction
- Cell size: {CELL}x{CELL}
- FPS: {FPS:.0f}
- Sprite sheet: `{sheet_path.relative_to(ROOT)}`

Manual cleanup loop:

1. Open `manual_cleanup/run_keyframes_5dir_cleaning_source.png`.
2. Paint corrections on the 5x4 sheet while keeping the same layout.
3. Save your corrected version as `manual_cleanup/run_keyframes_5dir_cleaned.png`.
4. Run `python tools/build_ai_keyframe_workflow.py` again.

The exporter will prefer `run_keyframes_5dir_cleaned.png` when it exists.
"""
    (EXPORT_DIR / "README.md").write_text(text, encoding="utf-8")


def build() -> None:
    if not REFERENCE_SHEET.exists():
        raise FileNotFoundError(f"Missing reference sheet: {REFERENCE_SHEET}")
    if not RAW_RUN_SHEET.exists():
        raise FileNotFoundError(f"Missing raw AI keyframe sheet: {RAW_RUN_SHEET}")

    ensure_dirs()
    split_reference_sheet()
    make_manual_starter()

    source_path = source_sheet_path()
    keyframes = extract_ai_run_keyframes(source_path)
    save_frame_groups(KEYFRAME_DIR, keyframes, with_shadow=True)

    animation_frames: dict[str, list[Image.Image]] = {}
    for direction in DIRECTIONS:
        bodies = retime_bodies(keyframes[direction], RUN_FRAMES)
        animation_frames[direction] = [
            composite_with_shadow(body, index, RUN_FRAMES)
            for index, body in enumerate(bodies)
        ]

    save_frame_groups(ANIM_DIR, animation_frames, with_shadow=False)
    sheet_path = make_sheet(animation_frames)
    make_preview(animation_frames)
    write_manifest(sheet_path, source_path)

    print(f"Wrote {sheet_path}")
    print(f"Wrote {PREVIEW_DIR / 'run_ai_keyframes_preview.png'}")
    print(f"Wrote {len(DIRECTIONS)} run animations from {source_path.name}")


if __name__ == "__main__":
    build()
