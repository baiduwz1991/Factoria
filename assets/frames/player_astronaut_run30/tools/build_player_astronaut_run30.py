#!/usr/bin/env python3
from __future__ import annotations

import math
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "source"
ANIM_DIR = ROOT / "animations_64"
KEYFRAME_DIR = ROOT / "keyframes_64"
SHEET_DIR = ROOT / "sheet"
PREVIEW_DIR = ROOT / "preview"
RESOURCE_PATH = (
    ROOT.parents[1]
    / "src"
    / "game"
    / "scene"
    / "player"
    / "resources"
    / "player_astronaut_run30_frames.tres"
)

CELL = 64
RUN_FRAMES = 30
IDLE_FRAMES = 60
SOURCE_STRIP_FRAMES = 16
FPS = 30.0
BODY_BOTTOM_Y = 55
SHADOW_Y = 58
TARGET_BODY_HEIGHT = 52

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

ANIMATIONS = [f"idle_{direction}" for direction in DIRECTIONS] + [
    f"run_{direction}" for direction in DIRECTIONS
]

RUN_SOURCES = {
    "down": SOURCE_DIR / "run_down_ai.png",
    "down_right": SOURCE_DIR / "run_down_right_ai.png",
    "right": SOURCE_DIR / "run_right_ai.png",
    "up_right": SOURCE_DIR / "run_up_right_ai.png",
    "up": SOURCE_DIR / "run_up_ai.png",
}

MIRROR_FROM = {
    "down_left": "down_right",
    "left": "right",
    "up_left": "up_right",
}

IDLE_INDEX = {
    "down": 0,
    "down_right": 1,
    "right": 6,
    "up_right": 3,
    "up": 4,
    "up_left": 5,
    "left": 2,
    "down_left": 7,
}


def ensure_clean_dirs() -> None:
    for path in (ANIM_DIR, KEYFRAME_DIR, SHEET_DIR, PREVIEW_DIR):
        if path.exists():
            shutil.rmtree(path)
        path.mkdir(parents=True, exist_ok=True)
    RESOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)


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


def remove_green_background(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    arr = np.array(image)
    rgb = arr[..., :3].astype(np.int16)
    r = rgb[..., 0]
    g = rgb[..., 1]
    b = rgb[..., 2]

    bright_key = (g > 120) & (g > r * 1.18 + 18) & (g > b * 1.18 + 18)
    dark_key = (g > 32) & ((g - r) > 14) & ((g - b) > 13) & (r < 135) & (b < 135)
    nearly_pure_key = (g > 75) & (r < 90) & (b < 90) & (g > r + 28) & (g > b + 28)
    green = bright_key | dark_key | nearly_pure_key

    alpha = np.where(green, 0, 255).astype(np.uint8)
    keep = alpha > 0

    green_spill = keep & (g > np.maximum(r, b) + 14)
    arr[..., 1] = np.where(green_spill, np.maximum(r, b) + 8, arr[..., 1]).astype(np.uint8)
    arr[..., 3] = alpha
    return Image.fromarray(arr, mode="RGBA")


def projection_segments(
    mask: np.ndarray,
    *,
    min_sum: int,
    merge_gap: int,
    min_width: int,
) -> list[tuple[int, int]]:
    sums = mask.sum(axis=0)
    indices = np.where(sums > min_sum)[0]
    if len(indices) == 0:
        return []

    groups: list[list[int]] = []
    start = prev = int(indices[0])
    for value in indices[1:]:
        value = int(value)
        if value <= prev + merge_gap + 1:
            prev = value
            continue
        groups.append([start, prev])
        start = prev = value
    groups.append([start, prev])

    return [(a, b + 1) for a, b in groups if b - a + 1 >= min_width]


def extract_strip_frames(path: Path, count: int) -> list[Image.Image]:
    keyed = remove_green_background(path)
    alpha = np.array(keyed.getchannel("A")) > 0
    segments = projection_segments(alpha, min_sum=8, merge_gap=12, min_width=16)

    frames: list[Image.Image] = []
    # Image generation may return a good run strip with 14-16 full poses rather
    # than the requested exact count. Use the detected full-character poses and
    # retime them later so we never slice a sprite in half.
    if 8 <= len(segments) <= 24:
        for x0, x1 in segments:
            crop = keyed.crop((max(0, x0 - 8), 0, min(keyed.width, x1 + 8), keyed.height))
            frames.append(crop_visible(crop, pad=5))
        return frames

    cell_w = keyed.width / count
    for index in range(count):
        x0 = int(round(index * cell_w))
        x1 = int(round((index + 1) * cell_w))
        crop = keyed.crop((x0, 0, x1, keyed.height))
        frames.append(crop_visible(crop, pad=5))
    return frames


def sharpen(image: Image.Image) -> Image.Image:
    return ImageEnhance.Sharpness(image).enhance(1.18)


def normalize_bodies(frames: list[Image.Image]) -> list[Image.Image]:
    bboxes = [alpha_bbox(frame) for frame in frames]
    sizes = [(box[2] - box[0], box[3] - box[1]) for box in bboxes if box is not None]
    if not sizes:
        raise RuntimeError("No visible frames to normalize")

    widths = [size[0] for size in sizes]
    heights = [size[1] for size in sizes]
    median_height = float(np.median(heights))
    max_width = float(max(widths))
    max_height = float(max(heights))
    scale = min(
        TARGET_BODY_HEIGHT / median_height,
        (CELL - 5) / max_width,
        (BODY_BOTTOM_Y - 3) / max_height,
    )

    normalized: list[Image.Image] = []
    for frame in frames:
        cropped = crop_visible(frame, pad=2)
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


def mirror_bodies(frames: list[Image.Image]) -> list[Image.Image]:
    return [frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for frame in frames]


def shadow_layer(body: Image.Image, frame_index: int, action: str, frame_count: int) -> Image.Image:
    layer = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    box = alpha_bbox(body, threshold=20)
    if box is None:
        return layer

    x0, _y0, x1, _y1 = box
    width = x1 - x0
    cx = (x0 + x1) / 2
    phase = frame_index / frame_count * math.tau
    run = 1.0 if action == "run" else 0.0
    pulse = 0.5 + 0.5 * math.cos(phase * 2.0)
    shadow_w = max(24.0, min(43.0, width * (0.72 + 0.12 * run * pulse)))
    shadow_h = 7.5 + 1.5 * run * pulse
    alpha = int(78 + 18 * run * pulse)

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


def composite_with_shadow(
    body: Image.Image,
    frame_index: int,
    action: str,
    frame_count: int,
) -> Image.Image:
    frame = shadow_layer(body, frame_index, action, frame_count)
    frame.alpha_composite(body)
    return frame


def make_idle_bodies(base: Image.Image) -> list[Image.Image]:
    box = alpha_bbox(base, threshold=12)
    if box is None:
        return [base.copy() for _ in range(IDLE_FRAMES)]

    x0, y0, x1, y1 = box
    crop = base.crop((x0, y0, x1, y1))
    center_x = (x0 + x1) / 2
    bottom_y = y1
    frames: list[Image.Image] = []
    aa = 4
    crop_hi = crop.resize((crop.width * aa, crop.height * aa), Image.Resampling.LANCZOS)

    for index in range(IDLE_FRAMES):
        phase = index / IDLE_FRAMES * math.tau
        breath = 0.5 + 0.5 * math.sin(phase - math.pi / 2)
        scale_y = 1.0 + 0.026 * breath
        scale_x = 1.0 - 0.008 * breath
        size = (
            max(1, int(round(crop_hi.width * scale_x))),
            max(1, int(round(crop_hi.height * scale_y))),
        )
        resized_hi = crop_hi.resize(size, Image.Resampling.LANCZOS)
        canvas_hi = Image.new("RGBA", (CELL * aa, CELL * aa), (0, 0, 0, 0))
        paste_x = int(round(center_x * aa - size[0] / 2))
        paste_y = int(round(bottom_y * aa - size[1]))
        canvas_hi.alpha_composite(resized_hi, (paste_x, paste_y))
        canvas = canvas_hi.resize((CELL, CELL), Image.Resampling.LANCZOS)
        frames.append(sharpen(canvas))

    return frames


def save_frames(animation_frames: dict[str, list[Image.Image]]) -> None:
    for animation, frames in animation_frames.items():
        out_dir = ANIM_DIR / animation
        out_dir.mkdir(parents=True, exist_ok=True)
        for index, frame in enumerate(frames):
            frame.save(out_dir / f"{animation}_{index:02d}.png")


def save_keyframes(keyframes: dict[str, list[Image.Image]]) -> None:
    for animation, frames in keyframes.items():
        out_dir = KEYFRAME_DIR / animation
        out_dir.mkdir(parents=True, exist_ok=True)
        for index, frame in enumerate(frames):
            composite_with_shadow(frame, index, "run", len(frames)).save(
                out_dir / f"{animation}_{index:02d}.png"
            )


def make_sheet(animation_frames: dict[str, list[Image.Image]]) -> Path:
    SHEET_DIR.mkdir(parents=True, exist_ok=True)
    max_frames = max(len(frames) for frames in animation_frames.values())
    sheet = Image.new("RGBA", (max_frames * CELL, len(ANIMATIONS) * CELL), (0, 0, 0, 0))
    for row, animation in enumerate(ANIMATIONS):
        for col, frame in enumerate(animation_frames[animation]):
            sheet.alpha_composite(frame, (col * CELL, row * CELL))
    path = SHEET_DIR / "player_astronaut_run30_64_sheet.png"
    sheet.save(path)
    return path


def write_spriteframes_resource(sheet_path: Path, animation_frames: dict[str, list[Image.Image]]) -> None:
    rel_sheet = sheet_path.relative_to(ROOT.parents[1])
    res_sheet = "res://assets/" + str(rel_sheet).replace("\\", "/")
    lines: list[str] = []
    atlas_count = sum(len(frames) for frames in animation_frames.values())
    lines.append(f'[gd_resource type="SpriteFrames" load_steps={atlas_count + 2} format=3]')
    lines.append("")
    lines.append(f'[ext_resource type="Texture2D" path="{res_sheet}" id="1_sheet"]')
    lines.append("")

    atlas_ids: dict[str, list[str]] = {}
    for row, animation in enumerate(ANIMATIONS):
        ids: list[str] = []
        for col in range(len(animation_frames[animation])):
            atlas_id = f"AtlasTexture_{animation}_{col:02d}"
            ids.append(atlas_id)
            lines.append(f'[sub_resource type="AtlasTexture" id="{atlas_id}"]')
            lines.append('atlas = ExtResource("1_sheet")')
            lines.append(f"region = Rect2({col * CELL}, {row * CELL}, {CELL}, {CELL})")
            lines.append("")
        atlas_ids[animation] = ids

    lines.append("[resource]")
    lines.append("animations = [")
    for anim_index, animation in enumerate(ANIMATIONS):
        lines.append("{")
        lines.append('"frames": [')
        for frame_index, atlas_id in enumerate(atlas_ids[animation]):
            lines.append("{")
            lines.append('"duration": 1.0,')
            lines.append(f'"texture": SubResource("{atlas_id}")')
            suffix = "," if frame_index < len(atlas_ids[animation]) - 1 else ""
            lines.append("}" + suffix)
        lines.append("],")
        lines.append('"loop": true,')
        lines.append(f'"name": &"{animation}",')
        lines.append(f'"speed": {FPS:.1f}')
        lines.append("}" + ("," if anim_index < len(ANIMATIONS) - 1 else ""))
    lines.append("]")
    RESOURCE_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


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
    label_h = 0
    width = sample_count * CELL + (sample_count - 1) * tile_gap
    height = len(ANIMATIONS) * CELL + (len(ANIMATIONS) - 1) * tile_gap + label_h
    preview = Image.new("RGBA", (width, height), (66, 66, 66, 255))

    for row, animation in enumerate(ANIMATIONS):
        y = row * (CELL + tile_gap)
        frame_count = len(animation_frames[animation])
        sample_indices = [
            min(frame_count - 1, round(i * frame_count / sample_count))
            for i in range(sample_count)
        ]
        for col, frame_index in enumerate(sample_indices):
            x = col * (CELL + tile_gap)
            preview.alpha_composite(animation_frames[animation][frame_index], (x, y))
    preview.save(PREVIEW_DIR / "player_astronaut_run30_preview.png")

    make_gif(animation_frames["run_right"], PREVIEW_DIR / "player_astronaut_run30_run_right.gif")
    make_gif(animation_frames["run_down"], PREVIEW_DIR / "player_astronaut_run30_run_down.gif")
    make_gif(animation_frames["run_up_right"], PREVIEW_DIR / "player_astronaut_run30_run_up_right.gif")
    make_gif(animation_frames["idle_down_right"], PREVIEW_DIR / "player_astronaut_run30_idle_down_right.gif")

    strip = Image.new("RGBA", (len(animation_frames["run_right"]) * CELL, CELL), (66, 66, 66, 255))
    for index, frame in enumerate(animation_frames["run_right"]):
        strip.alpha_composite(frame, (index * CELL, 0))
    strip.save(PREVIEW_DIR / "player_astronaut_run30_run_right_strip.png")


def write_readme() -> None:
    text = f"""# Player Astronaut Run30

AI-assisted astronaut player sprites generated from the user's thick-paint reference direction.

- Cell size: {CELL}x{CELL}
- Final animation speed: {FPS:.0f} fps
- Run frames per direction: {RUN_FRAMES}
- Idle frames per direction: {IDLE_FRAMES}
- Animations: {len(ANIMATIONS)} (idle/run x 8 directions)
- Godot resource: `{RESOURCE_PATH.relative_to(ROOT.parents[2])}`
- Sprite sheet: `sheet/player_astronaut_run30_64_sheet.png`

Source AI strips are copied into `source/`. The build script removes the green background,
normalizes the character to a shared foot baseline, redraws a transparent contact shadow, and
exports a SpriteFrames `.tres` for AnimatedSprite2D.
"""
    (ROOT / "README.md").write_text(text, encoding="utf-8")


def build() -> None:
    ensure_clean_dirs()

    run_keyframes: dict[str, list[Image.Image]] = {}
    for direction, source_path in RUN_SOURCES.items():
        extracted = extract_strip_frames(source_path, SOURCE_STRIP_FRAMES)
        run_keyframes[direction] = normalize_bodies(extracted)

    for direction, source_direction in MIRROR_FROM.items():
        run_keyframes[direction] = mirror_bodies(run_keyframes[source_direction])

    save_keyframes({f"run_{direction}": frames for direction, frames in run_keyframes.items()})

    animation_bodies: dict[str, list[Image.Image]] = {}
    for direction in DIRECTIONS:
        animation_bodies[f"run_{direction}"] = retime_bodies(run_keyframes[direction], RUN_FRAMES)

    idle_cells = extract_strip_frames(SOURCE_DIR / "idle_8dir_ai.png", len(DIRECTIONS))
    idle_bases = normalize_bodies(idle_cells)

    for direction in DIRECTIONS:
        base = idle_bases[IDLE_INDEX[direction]]
        animation_bodies[f"idle_{direction}"] = make_idle_bodies(base)

    animation_frames: dict[str, list[Image.Image]] = {}
    for animation, bodies in animation_bodies.items():
        action = "run" if animation.startswith("run_") else "idle"
        animation_frames[animation] = [
            composite_with_shadow(body, index, action, len(bodies))
            for index, body in enumerate(bodies)
        ]

    save_frames(animation_frames)
    sheet_path = make_sheet(animation_frames)
    write_spriteframes_resource(sheet_path, animation_frames)
    make_preview(animation_frames)
    write_readme()

    print(f"Wrote {sheet_path}")
    print(f"Wrote {RESOURCE_PATH}")
    print(f"Wrote {len(ANIMATIONS)} animations at {FPS:.0f} fps")


if __name__ == "__main__":
    build()
