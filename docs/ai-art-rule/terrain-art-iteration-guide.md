# Terrain Art Iteration Guide

这份文档用于在新窗口继续迭代地形美术资产。它总结当前已经验证过的流程、提示词、打包规范、备份习惯和质量检查点。

当前目标风格：厚涂写实、俯视角、Factorio-like terrain readability，避免卡通、亮色塑料感、硬边线和明显贴片矩形。

## 当前结论

- 当前认可的 base 地形版本已经解决了美术风格和循环衔接问题。
- 后续迭代不要再生成“atlas sheet/分段长条”作为模型源图，容易带来 1x1、2x2、4x4 的割裂感。
- 推荐让模型生成一张连续铺满的顶视角地表源图，再从同一张源图裁 `1x1 / 2x2 / 4x4`。
- 大区块差异要保留，但应是自然、柔和、非矩形的低频区域变化。4x4 可保留中心变化，边缘压回共同色调。
- `overlay/dual16.png` 应该像参考图那样使用透明渐变材质，不要做成硬 alpha 波浪线。
- `shore` 应该拆成两层：水侧软暗影 `water_shadow_dual16.png`，陆侧岸壁/断面 `water_dual16.png`。目标是俯视角下有一点低矮悬崖高度感。

## 资产规格

地形目录：

```text
assets/texture/terrain/
  base_soil/
    base/1x1.png
    base/2x2/2x2.png
    base/4x4/4x4.png
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
  dirt/
    base/1x1.png
    base/2x2/2x2.png
    base/4x4/4x4.png
    overlay/dual16.png
    shore/water_shadow_dual16.png
    shore/water_dual16.png
```

尺寸规则：

- `base/1x1.png`: `1024x64`，横向 16 个 `64x64` 变体。
- `base/2x2/2x2.png`: `2048x128`，横向 16 个 `128x128` 变体。
- `base/4x4/4x4.png`: `4096x256`，横向 16 个 `256x256` 变体。
- `overlay/dual16.png`: `1024x1024`，16 列 mask x 16 行 cycle，每格 `64x64`。
- `shore/water_shadow_dual16.png`: `1024x1024`。
- `shore/water_dual16.png`: `1024x1024`。

Mask 规则：

- `1=TL`, `2=TR`, `4=BL`, `8=BR`。
- mask `0` 和 mask `15` 必须全透明。
- 行号 `0..15` 对应运行时 cycle：`x % 4 + y % 4 * 4`。
- `.import` 文件不要手动改。

## 推荐工作流

1. 先备份当前版本到 `.codex_tmp/terrain_versions/<name>`。
2. 使用 `imagegen` 生成连续源图，不要生成分段 atlas。
3. 将模型生成图从 `C:/Users/wangzhi/.codex/generated_images/...` 复制到工作区临时目录。
4. 本地只做裁切、色调归一、alpha mask、shore 分层，不再用程序重新画材质。
5. 先输出 preview，看 `1x1 / 2x2 / 4x4` 混铺压力测试。
6. 满意后覆盖正式 PNG。
7. 检查尺寸、alpha、mask 0/15、`git diff --name-only`。
8. 如果 `imagegen` 限流，不连续撞接口，等待 30 分钟再重试。

备份示例：

```text
.codex_tmp/terrain_versions/approved_seamless_2026-06-09
.codex_tmp/terrain_versions/pre_overlay_shore_2026-06-09
```

## Base 地形提示词

核心思路：一张连续地表源图，不要 atlas，不要分块。草、沙、泥分别生成。

### 草地

```text
Create a single continuous source texture for a 2D top-down game terrain atlas: GRASS terrain, iteration with broad-area variation. The image must be one edge-to-edge filled terrain field, not an atlas sheet, not separated rectangles, not rows or columns. Orthographic top-down view only.

Style target: thick-painted realistic game art, gritty oil-brush strokes, dark muted olive grass, ochre highlights, tiny dry flecks, grounded Factorio-like terrain readability, not cartoon.

New requirement: add broad natural regional variation to reduce repetition on large maps while staying seamless between 1x1, 2x2, and 4x4 crops. The whole image should contain several very soft irregular regions at roughly 200-450 px scale: slightly denser grass, slightly drier olive-brown grass, faint mossy dark patches, sparse tiny beige soil flecks, and subtle trampled grass areas. These regions must have feathered organic edges and similar average brightness so they do not look like rectangular stamps when cropped.

Most important constraints: no obvious rectangular blocks, no atlas divisions, no high-contrast dirt islands, no repeated stripe rows, no strong focal blotches, no black background, no grid lines, no text, no UI, no side-view grass, no horizon, no props, no clean outlines, no bright candy green. Fill the entire image with usable top-down grass terrain pixels edge-to-edge.
```

### 沙地

```text
Create a single continuous source texture for a 2D top-down game terrain atlas: SAND terrain, iteration with broad-area variation. The image must be one edge-to-edge filled terrain field, not an atlas sheet, not separated rectangles, not rows or columns. Orthographic top-down view only.

Style target: thick-painted realistic game art, gritty oil-brush texture, muted warm grey-ochre sand, tan and beige grains, compact dry ground, small embedded pebbles, grounded Factorio-like terrain readability, not cartoon.

New requirement: add broad natural regional variation to reduce repetition on large maps while staying seamless between 1x1, 2x2, and 4x4 crops. The whole image should contain several very soft irregular regions at roughly 200-450 px scale: compact smoother sand, slightly pebbly sand, faint darker wind-scuffed zones, lightly crusted dry patches, and subtle granular color shifts. These regions must have feathered organic edges and similar average brightness so they do not look like rectangular stamps when cropped.

Most important constraints: no obvious rectangular blocks, no atlas divisions, no dune stripe rows, no high-contrast tracks, no strong focal blotches, no black background, no grid lines, no text, no UI, no horizon, no props, no clean outlines, no bright yellow beach sand. Fill the entire image with usable top-down sand terrain pixels edge-to-edge.
```

### 泥地

```text
Create a single continuous source texture for a 2D top-down game terrain atlas: DIRT / MUD terrain, iteration with broad-area variation. The image must be one edge-to-edge filled terrain field, not an atlas sheet, not separated rectangles, not rows or columns. Orthographic top-down view only.

Style target: thick-painted realistic game art, gritty oil-brush texture, dark umber and raw sienna soil, compact damp earth, fine clumped mud texture, tiny embedded stones, subtle dry straw fragments, grounded Factorio-like terrain readability, not cartoon.

New requirement: add broad natural regional variation to reduce repetition on large maps while staying seamless between 1x1, 2x2, and 4x4 crops. The whole image should contain several very soft irregular regions at roughly 200-450 px scale: slightly damp darker soil, slightly drier brown soil, fine crumbly mud, sparse pebble-rich patches, faint compacted areas, and subtle straw flecks. These regions must have feathered organic edges and similar average brightness so they do not look like rectangular stamps when cropped.

Most important constraints: no obvious rectangular blocks, no atlas divisions, no high-contrast ruts, no repeated track rows, no strong black cracks, no glossy puddles, no large isolated blotches, no black background, no grid lines, no text, no UI, no horizon, no props, no clean outlines, no bright orange dirt. Fill the entire image with usable top-down dirt terrain pixels edge-to-edge.
```

## Base 打包规范

从同一张连续源图生成三种 base：

- `1x1`: 16 个 `64x64` 变体，作为稳定底纹。
- `2x2`: 16 个 `128x128` 变体，承载同密度的中尺度材质变化。
- `4x4`: 16 个 `256x256` 变体，承载大贴图材质变化。
- 所有普通陆地都应按沙地的成功规律制作：三种尺度都可以使用，但每个变体的平均亮度、颗粒密度和低频强度要接近。不要为了衔接做“边缘抹平、中间加料”的补丁结构。

关键处理：

- 不要从左到右顺序扫描源图后直接塞进 atlas，容易把源图低频变化变成规则块。
- 小贴图和大贴图都要做色调归一，16 个变体平均亮度和对比必须接近。
- 沙坑、草坑、草堆、石床等特征可以保留，但必须和周围材质同源、同密度，并用有机边界融入，不要出现矩形安全边框。
- 预览必须做运行时同款混铺压力测试：先铺满 `1x1`，再盖完整的 `2x2` 和 `4x4` patch，看是否露出矩形边或固定周期。

## Overlay 规范

问题记录：早期 `overlay/dual16.png` 的 alpha 边界像硬波浪线，地图上会读成线条。

当前方向：

- 使用宽透明渐变，类似参考图里材质从实到虚。
- alpha 不要是窄边界，不要只在 `f=0.5` 附近画一条线。
- 渐变尾端必须真的归零。不要留下 `1..9` 这种几乎看不见的 alpha；这些低 alpha 会在 `64x64` cell 外框上叠出微弱方块感。
- 未占用角落必须纯透明。例如 mask 没有 `TR` 位时，右上角小区域 alpha max 应为 `0`。
- mask `0` 和 `15` 必须全透明。
- 其他 mask 使用同一套 terrain-independent alpha field，避免不同陆地边界露底色裂缝。
- RGB 内容来自对应地形 `base/1x1.png` 的 cycle 纹理，边缘可轻微去饱和/混平均色，让渐变更软。

Overlay 目标观感：

```text
The overlay should read as a soft transparent material fade, not as a contour line.
The terrain texture should gradually dissolve into the underlying terrain over a broad feathered band.
Avoid wave-line silhouettes, hard alpha edges, narrow outlines, and repeated scallop patterns.
```

## Shore 规范

用户期望：海岸线有一点高度感，俯视角下像低矮悬崖或被水侵蚀的岸壁。

结构：

- `shore/water_shadow_dual16.png`: 水侧软暗影，画在 shore rim 下面。
- `shore/water_dual16.png`: 陆侧岸壁/断面/顶缘。
- 水岸绘制顺序是 `shore shadow -> shore rim -> foam`。

美术方向：

- 水侧要有宽而软的暗影，暗示陆地高于水面。
- 陆侧可以有土/岩断面，但要非常克制。过厚会像一圈不自然的墙。
- 当前更稳的方向是：轻微湿边/侵蚀边 + 很淡的水深暗化，而不是高对比悬崖描边。
- 断面可使用模型生成的 cliff material source，再按 `base_soil/grass/sand/dirt` 调色。
- 不要强黑线、不要发光边、不要卡通海岸描边。

Cliff/source 提示词：

```text
Create a single continuous source texture for a 2D top-down game shoreline cliff material. It will be used as the painted material inside small transparent coastal rim masks, not as a full landscape.

Style: thick-painted realistic game art, gritty oil-brush texture, Factorio-like terrain readability. Eroded earthen bank and low coastal cliff face material seen from near top-down: compact soil, crumbly vertical dirt face, small stones, tan ochre and dark umber streaks, subtle rocky chips, dry roots and grit. It should suggest a slight height drop at a shoreline when used as a narrow edge band.

Important: the image must be one continuous edge-to-edge texture field, no atlas layout, no separate rectangles, no rows, no labels, no UI, no transparent background. Do not paint a horizon or actual ocean scene. No cliffs in perspective, no big props, no strong cast shadows. Make it usable as a source material for many small cropped shoreline edge sprites. Keep contrast moderate and painterly, not cartoon.
```

Shore 目标观感：

```text
Water side: subtle, soft water-depth darkening fading into water.
Land side: very light damp/eroded rim, not a thick wall.
The coastline may feel slightly raised, but it must stay natural in top-down gameplay scale.
It must not read as a thin outline, wave stroke, dark contour, or opaque cliff wall.
```

## 质量检查清单

每次落正式资源前检查：

```powershell
Add-Type -AssemblyName System.Drawing
$root = 'E:\factoria\factoria_v0.0.1'
$files = @(
  'assets\texture\terrain\grass\base\1x1.png',
  'assets\texture\terrain\grass\base\2x2\2x2.png',
  'assets\texture\terrain\grass\base\4x4\4x4.png',
  'assets\texture\terrain\grass\overlay\dual16.png'
)
foreach ($f in $files) {
  $img = [System.Drawing.Image]::FromFile((Join-Path $root $f))
  Write-Output "$f => $($img.Width)x$($img.Height) $($img.PixelFormat)"
  $img.Dispose()
}
```

Python alpha 检查思路：

```text
- base 1x1/2x2/4x4: alpha min/max 应为 255/255。
- overlay/shore: alpha min 应为 0，max 可低于 255。
- dual16 的 mask 0 和 mask 15 必须 max alpha = 0。
- overlay/shore 的低 alpha 尾巴要清掉：`0 < alpha < 10` 的像素数量应为 0。
- 对每个 mask，未占用角落的 `8x8` 小区域 alpha max 应为 0。
```

Git 检查：

```powershell
git diff --name-only
git status --short
```

期望：

- 不改 `.import`。
- 正式资源只改需要迭代的 PNG。
- 预览、源图、临时图放 `.codex_tmp/` 或 `dev-only/`，不要放进 runtime terrain tree。

## 当前常用临时目录

```text
.codex_tmp/terrain_model_unified/
.codex_tmp/terrain_model_region_variation/
.codex_tmp/terrain_model_overlay_shore/
.codex_tmp/terrain_versions/
```

注意：`.codex_tmp` 只是工作区临时记录，不一定长期保存。重要版本要明确复制到 `.codex_tmp/terrain_versions/<name>`。

## 新窗口接力提示

可以把下面这段直接发给新窗口：

```text
请阅读 E:\factoria\factoria_v0.0.1\doc\terrain-art-iteration-guide.md，然后继续迭代 terrain 美术资产。

当前方向：
- base 地形用连续源图裁切，不要 atlas sheet。
- 1x1/2x2 保持无缝和同风格。
- 4x4 保留自然大区块差异，但边缘要回到共同色调，避免矩形贴片感。
- overlay 用宽透明渐变，不要波浪线硬边。
- shore 用水侧软暗影 + 陆侧土/岩断面，做俯视角低矮悬崖感。
- 先备份，再生成/打包/预览/验证。
- imagegen 限流时每 30 分钟重试一次。
```
