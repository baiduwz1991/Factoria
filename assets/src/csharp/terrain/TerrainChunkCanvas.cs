using Godot;
using System.Collections.Generic;
using GodotDictionary = Godot.Collections.Dictionary;

public partial class TerrainChunkCanvas : Node2D
{
    private const int SourceTileSize = 64;
    private const int CycleSize = 4;
    private const int CommandStride = 5;
    private const int Patch2Size = 2;
    private const int Patch4Size = 4;
    private const int WaterAnimationFrameCount = 11;
    private const double NearWaterAnimationFramesPerSecond = 4.0;
    private const double MidWaterAnimationFramesPerSecond = 1.0;
    private const float FreezeWaterAnimationBelowScreenPixels = 4.0f;
    private const float SlowWaterAnimationBelowScreenPixels = 10.0f;

    private const int VisualBaseSoil = 0;
    private const int VisualDirt = 1;
    private const int VisualGrass = 2;
    private const int VisualSand = 3;
    private const int VisualWater = 4;
    private const int VisualDeepWater = 5;

    private static readonly Dictionary<int, Texture2D> BaseTextures = new();
    private static readonly Dictionary<int, Texture2D> BasePatch2Textures = new();
    private static readonly Dictionary<int, Texture2D> BasePatch4Textures = new();
    private static readonly Dictionary<int, Texture2D> OverlayTextures = new();
    private static readonly Dictionary<int, Texture2D> ShoreShadowTextures = new();
    private static readonly Dictionary<int, Texture2D> ShoreTextures = new();
    private static readonly Dictionary<int, Texture2D> ShoreCombinedTextures = new();
    private static readonly Dictionary<int, Texture2D[]> AnimatedBaseTextures = new();
    private static readonly Dictionary<int, Texture2D[]> AnimatedBasePatch2Textures = new();
    private static readonly Dictionary<int, Texture2D[]> AnimatedBasePatch4Textures = new();
    private static readonly Dictionary<int, Texture2D[]> AnimatedOverlayTextures = new();
    private static readonly Dictionary<int, Texture2D[]> AnimatedShoreShadowTextures = new();
    private static readonly Dictionary<int, Texture2D[]> AnimatedShoreTextures = new();
    private static readonly Dictionary<int, Texture2D[]> AnimatedShoreCombinedTextures = new();
    private static Texture2D WaterFoamTexture;
    private static bool TexturesLoaded;
    private static ulong CachedWaterAnimationStep = ulong.MaxValue;
    private static int CachedWaterAnimationFrame;
    private static double CachedWaterAnimationFramesPerSecond = -1.0;

    private Vector2I _chunkCoord = Vector2I.Zero;
    private int _chunkSize = 1;
    private int _tileSize = 32;
    private int[] _baseVisuals = System.Array.Empty<int>();
    private int[] _baseCycles = System.Array.Empty<int>();
    private int[] _basePatchCommands = System.Array.Empty<int>();
    private bool[] _basePatchCovered = System.Array.Empty<bool>();
    private int[] _overlayCommands = System.Array.Empty<int>();
    private int[] _shoreCommands = System.Array.Empty<int>();
    private int[] _foamCommands = System.Array.Empty<int>();
    private int _waterAnimationFrame = -1;
    private bool _hasAnimatedWater;

    public override void _Ready()
    {
        TextureFilter = TextureFilterEnum.LinearWithMipmaps;
        SetProcess(_hasAnimatedWater);
    }

    public void Configure(GodotDictionary visualData)
    {
        _chunkCoord = visualData.TryGetValue("chunk_coord", out Variant chunkCoordValue)
            ? chunkCoordValue.AsVector2I()
            : Vector2I.Zero;
        _chunkSize = System.Math.Max(ReadInt(visualData, "chunk_size", 1), 1);
        _tileSize = System.Math.Max(ReadInt(visualData, "tile_size", 32), 1);
        _baseVisuals = ReadInt32Array(visualData, "base_visuals");
        _baseCycles = ReadInt32Array(visualData, "base_cycles");
        _basePatchCommands = ReadInt32Array(visualData, "base_patch_commands");
        _basePatchCovered = BuildBasePatchCoverage(_chunkSize, _basePatchCommands);
        _overlayCommands = ReadInt32Array(visualData, "overlay_commands");
        _shoreCommands = ReadInt32Array(visualData, "shore_commands");
        _foamCommands = ReadInt32Array(visualData, "foam_commands");
        _hasAnimatedWater = HasAnimatedWaterContent();
        _waterAnimationFrame = GetWaterAnimationFrameForDraw();
        SetProcess(_hasAnimatedWater);
        Name = $"TerrainChunkCanvas_{_chunkCoord.X}_{_chunkCoord.Y}";
        QueueRedraw();
    }

    public override void _Process(double delta)
    {
        if (!_hasAnimatedWater)
            return;

        int frame = GetWaterAnimationFrameForDraw();
        if (frame == _waterAnimationFrame)
            return;

        _waterAnimationFrame = frame;
        QueueRedraw();
    }

    public override void _Draw()
    {
        EnsureTexturesLoaded();
        if (_hasAnimatedWater)
            _waterAnimationFrame = GetWaterAnimationFrameForDraw();
        DrawBaseTiles();
        DrawBasePatchCommands();
        DrawCommands(_overlayCommands, GetOverlayTextureForDraw);
        DrawCommands(_shoreCommands, GetShoreCombinedTextureForDraw);
    }

    private void DrawBaseTiles()
    {
        int tileCount = _chunkSize * _chunkSize;
        if (_baseVisuals.Length < tileCount || _baseCycles.Length < tileCount)
            return;

        for (int localY = 0; localY < _chunkSize; localY++)
        {
            for (int localX = 0; localX < _chunkSize; localX++)
            {
                int index = localY * _chunkSize + localX;
                if (index < _basePatchCovered.Length && _basePatchCovered[index])
                    continue;

                Texture2D texture = GetBaseTextureForDraw(_baseVisuals[index]);
                if (texture == null)
                    continue;

                DrawBaseTextureRegion(texture, localX, localY, _baseCycles[index]);
            }
        }
    }

    private void DrawCommands(int[] commands, System.Func<int, Texture2D> textureGetter)
    {
        for (int index = 0; index + CommandStride - 1 < commands.Length; index += CommandStride)
        {
            int localX = commands[index];
            int localY = commands[index + 1];
            int visual = commands[index + 2];
            int mask = commands[index + 3];
            int cycle = commands[index + 4];
            if (mask <= 0 || mask >= 15)
                continue;

            Texture2D texture = textureGetter(visual);
            if (texture == null)
                continue;

            DrawTextureRegion(texture, localX, localY, mask, cycle);
        }
    }

    private void DrawBaseTextureRegion(Texture2D texture, int localX, int localY, int cycle)
    {
        int safeCycle = PosMod(cycle, CycleSize * CycleSize);
        Rect2 destination = new Rect2(
            localX * _tileSize,
            localY * _tileSize,
            _tileSize,
            _tileSize
        );
        Rect2 source = new Rect2(
            safeCycle * SourceTileSize,
            0,
            SourceTileSize,
            SourceTileSize
        );
        DrawTextureRectRegion(texture, destination, source);
    }

    private void DrawBasePatchCommands()
    {
        for (int index = 0; index + CommandStride - 1 < _basePatchCommands.Length; index += CommandStride)
        {
            int localX = _basePatchCommands[index];
            int localY = _basePatchCommands[index + 1];
            int visual = _basePatchCommands[index + 2];
            int patchSize = _basePatchCommands[index + 3];
            int variant = _basePatchCommands[index + 4];

            Texture2D texture = GetBasePatchTextureForDraw(visual, patchSize);
            if (texture == null)
                continue;

            DrawBasePatchTextureRegion(texture, localX, localY, patchSize, variant);
        }
    }

    private void DrawBasePatchTextureRegion(Texture2D texture, int localX, int localY, int patchSize, int variant)
    {
        int sourceSize = SourceTileSize * patchSize;
        Rect2 destination = new Rect2(
            localX * _tileSize,
            localY * _tileSize,
            _tileSize * patchSize,
            _tileSize * patchSize
        );
        Rect2 source = new Rect2(
            PosMod(variant, CycleSize * CycleSize) * sourceSize,
            0,
            sourceSize,
            sourceSize
        );
        DrawTextureRectRegion(texture, destination, source);
    }

    private void DrawTextureRegion(Texture2D texture, int localX, int localY, int mask, int cycle)
    {
        Rect2 destination = new Rect2(
            localX * _tileSize,
            localY * _tileSize,
            _tileSize,
            _tileSize
        );
        Rect2 source = new Rect2(
            mask * SourceTileSize,
            PosMod(cycle, CycleSize * CycleSize) * SourceTileSize,
            SourceTileSize,
            SourceTileSize
        );
        DrawTextureRectRegion(texture, destination, source);
    }

    private static bool[] BuildBasePatchCoverage(int chunkSize, int[] commands)
    {
        int tileCount = chunkSize * chunkSize;
        bool[] covered = new bool[tileCount];
        for (int index = 0; index + CommandStride - 1 < commands.Length; index += CommandStride)
        {
            int localX = commands[index];
            int localY = commands[index + 1];
            int patchSize = commands[index + 3];
            if (patchSize != Patch2Size && patchSize != Patch4Size)
                continue;

            for (int offsetY = 0; offsetY < patchSize; offsetY++)
            {
                int coveredY = localY + offsetY;
                if (coveredY < 0 || coveredY >= chunkSize)
                    continue;

                for (int offsetX = 0; offsetX < patchSize; offsetX++)
                {
                    int coveredX = localX + offsetX;
                    if (coveredX < 0 || coveredX >= chunkSize)
                        continue;

                    covered[coveredY * chunkSize + coveredX] = true;
                }
            }
        }
        return covered;
    }

    private bool HasAnimatedWaterContent()
    {
        if (_shoreCommands.Length > 0)
            return true;

        foreach (int visual in _baseVisuals)
        {
            if (IsAnimatedWaterVisual(visual))
                return true;
        }

        if (HasAnimatedWaterCommand(_basePatchCommands) || HasAnimatedWaterCommand(_overlayCommands))
            return true;

        return false;
    }

    private static bool HasAnimatedWaterCommand(int[] commands)
    {
        for (int index = 0; index + CommandStride - 1 < commands.Length; index += CommandStride)
        {
            if (IsAnimatedWaterVisual(commands[index + 2]))
                return true;
        }
        return false;
    }

    private static bool IsAnimatedWaterVisual(int visual)
    {
        return visual == VisualWater || visual == VisualDeepWater;
    }

    private static Texture2D GetBaseTexture(int visual)
    {
        return BaseTextures.TryGetValue(visual, out Texture2D texture) ? texture : null;
    }

    private Texture2D GetBaseTextureForDraw(int visual)
    {
        return GetAnimatedTexture(AnimatedBaseTextures, visual, _waterAnimationFrame) ?? GetBaseTexture(visual);
    }

    private static Texture2D GetBasePatchTexture(int visual, int patchSize)
    {
        Dictionary<int, Texture2D> textures = patchSize switch
        {
            Patch2Size => BasePatch2Textures,
            Patch4Size => BasePatch4Textures,
            _ => null
        };
        return textures != null && textures.TryGetValue(visual, out Texture2D texture) ? texture : null;
    }

    private Texture2D GetBasePatchTextureForDraw(int visual, int patchSize)
    {
        Dictionary<int, Texture2D[]> animatedTextures = patchSize switch
        {
            Patch2Size => AnimatedBasePatch2Textures,
            Patch4Size => AnimatedBasePatch4Textures,
            _ => null
        };
        return GetAnimatedTexture(animatedTextures, visual, _waterAnimationFrame) ?? GetBasePatchTexture(visual, patchSize);
    }

    private static Texture2D GetOverlayTexture(int visual)
    {
        return OverlayTextures.TryGetValue(visual, out Texture2D texture) ? texture : null;
    }

    private Texture2D GetOverlayTextureForDraw(int visual)
    {
        return GetAnimatedTexture(AnimatedOverlayTextures, visual, _waterAnimationFrame) ?? GetOverlayTexture(visual);
    }

    private static Texture2D GetShoreShadowTexture(int visual)
    {
        return ShoreShadowTextures.TryGetValue(visual, out Texture2D texture) ? texture : null;
    }

    private Texture2D GetShoreShadowTextureForDraw(int visual)
    {
        return GetAnimatedTexture(AnimatedShoreShadowTextures, visual, _waterAnimationFrame) ?? GetShoreShadowTexture(visual);
    }

    private static Texture2D GetShoreTexture(int visual)
    {
        return ShoreTextures.TryGetValue(visual, out Texture2D texture) ? texture : null;
    }

    private Texture2D GetShoreTextureForDraw(int visual)
    {
        return GetAnimatedTexture(AnimatedShoreTextures, visual, _waterAnimationFrame) ?? GetShoreTexture(visual);
    }

    private static Texture2D GetShoreCombinedTexture(int visual)
    {
        return ShoreCombinedTextures.TryGetValue(visual, out Texture2D texture) ? texture : null;
    }

    private Texture2D GetShoreCombinedTextureForDraw(int visual)
    {
        return GetAnimatedTexture(AnimatedShoreCombinedTextures, visual, _waterAnimationFrame)
            ?? GetShoreCombinedTexture(visual)
            ?? GetShoreTextureForDraw(visual);
    }

    private static Texture2D GetAnimatedTexture(Dictionary<int, Texture2D[]> textures, int visual, int frame)
    {
        if (textures == null || !textures.TryGetValue(visual, out Texture2D[] frames) || frames == null || frames.Length == 0)
            return null;

        Texture2D texture = frames[PosMod(frame, frames.Length)];
        return texture ?? frames[0];
    }

    private static void EnsureTexturesLoaded()
    {
        if (TexturesLoaded)
            return;
        TexturesLoaded = true;

        LoadBaseTextures();
        LoadBasePatchTextures();
        LoadOverlayTextures();
        LoadShoreTextures();
        LoadWaterEffects();
    }

    private static void LoadBaseTextures()
    {
        BaseTextures[VisualBaseSoil] = LoadTexture("res://assets/texture/terrain/base_soil/base/1x1.png");
        BaseTextures[VisualDirt] = LoadTexture("res://assets/texture/terrain/dirt/base/1x1.png");
        BaseTextures[VisualGrass] = LoadTexture("res://assets/texture/terrain/grass/base/1x1.png");
        BaseTextures[VisualSand] = LoadTexture("res://assets/texture/terrain/sand/base/1x1.png");
        BaseTextures[VisualWater] = LoadTexture("res://assets/texture/terrain/water/base/1x1.png");
        BaseTextures[VisualDeepWater] = LoadTexture("res://assets/texture/terrain/deep_water/base/1x1.png");

        AnimatedBaseTextures[VisualWater] = LoadTextureFrames("res://assets/texture/terrain/water/base/anim_11/1x1/water_base_1x1_{0:D2}.png");
        AnimatedBaseTextures[VisualDeepWater] = LoadTextureFrames("res://assets/texture/terrain/deep_water/base/anim_11/1x1/deep_water_base_1x1_{0:D2}.png");
    }

    private static void LoadBasePatchTextures()
    {
        BasePatch2Textures[VisualBaseSoil] = LoadTexture("res://assets/texture/terrain/base_soil/base/2x2/2x2.png");
        BasePatch2Textures[VisualDirt] = LoadTexture("res://assets/texture/terrain/dirt/base/2x2/2x2.png");
        BasePatch2Textures[VisualGrass] = LoadTexture("res://assets/texture/terrain/grass/base/2x2/2x2.png");
        BasePatch2Textures[VisualSand] = LoadTexture("res://assets/texture/terrain/sand/base/2x2/2x2.png");
        BasePatch2Textures[VisualWater] = LoadTexture("res://assets/texture/terrain/water/base/2x2/2x2.png");
        BasePatch2Textures[VisualDeepWater] = LoadTexture("res://assets/texture/terrain/deep_water/base/2x2/2x2.png");

        BasePatch4Textures[VisualBaseSoil] = LoadTexture("res://assets/texture/terrain/base_soil/base/4x4/4x4.png");
        BasePatch4Textures[VisualDirt] = LoadTexture("res://assets/texture/terrain/dirt/base/4x4/4x4.png");
        BasePatch4Textures[VisualGrass] = LoadTexture("res://assets/texture/terrain/grass/base/4x4/4x4.png");
        BasePatch4Textures[VisualSand] = LoadTexture("res://assets/texture/terrain/sand/base/4x4/4x4.png");
        BasePatch4Textures[VisualWater] = LoadTexture("res://assets/texture/terrain/water/base/4x4/4x4.png");
        BasePatch4Textures[VisualDeepWater] = LoadTexture("res://assets/texture/terrain/deep_water/base/4x4/4x4.png");

        AnimatedBasePatch2Textures[VisualWater] = LoadTextureFrames("res://assets/texture/terrain/water/base/anim_11/2x2/water_base_2x2_{0:D2}.png");
        AnimatedBasePatch4Textures[VisualWater] = LoadTextureFrames("res://assets/texture/terrain/water/base/anim_11/4x4/water_base_4x4_{0:D2}.png");
        AnimatedBasePatch2Textures[VisualDeepWater] = LoadTextureFrames("res://assets/texture/terrain/deep_water/base/anim_11/2x2/deep_water_base_2x2_{0:D2}.png");
        AnimatedBasePatch4Textures[VisualDeepWater] = LoadTextureFrames("res://assets/texture/terrain/deep_water/base/anim_11/4x4/deep_water_base_4x4_{0:D2}.png");
    }

    private static void LoadOverlayTextures()
    {
        OverlayTextures[VisualDirt] = LoadTexture("res://assets/texture/terrain/dirt/overlay/dual16.png");
        OverlayTextures[VisualGrass] = LoadTexture("res://assets/texture/terrain/grass/overlay/dual16.png");
        OverlayTextures[VisualSand] = LoadTexture("res://assets/texture/terrain/sand/overlay/dual16.png");
        OverlayTextures[VisualWater] = LoadTexture("res://assets/texture/terrain/water/overlay/dual16.png");
        OverlayTextures[VisualDeepWater] = LoadTexture("res://assets/texture/terrain/deep_water/overlay/dual16.png");

        AnimatedOverlayTextures[VisualWater] = LoadTextureFrames("res://assets/texture/terrain/water/overlay/anim_11/water_overlay_dual16_{0:D2}.png");
        AnimatedOverlayTextures[VisualDeepWater] = LoadTextureFrames("res://assets/texture/terrain/deep_water/overlay/anim_11/deep_water_overlay_dual16_{0:D2}.png");
    }

    private static void LoadShoreTextures()
    {
        ShoreShadowTextures[VisualBaseSoil] = LoadTexture("res://assets/texture/terrain/base_soil/shore/water_shadow_dual16.png");
        ShoreShadowTextures[VisualDirt] = LoadTexture("res://assets/texture/terrain/dirt/shore/water_shadow_dual16.png");
        ShoreShadowTextures[VisualGrass] = LoadTexture("res://assets/texture/terrain/grass/shore/water_shadow_dual16.png");
        ShoreShadowTextures[VisualSand] = LoadTexture("res://assets/texture/terrain/sand/shore/water_shadow_dual16.png");

        ShoreTextures[VisualBaseSoil] = LoadTexture("res://assets/texture/terrain/base_soil/shore/water_dual16.png");
        ShoreTextures[VisualDirt] = LoadTexture("res://assets/texture/terrain/dirt/shore/water_dual16.png");
        ShoreTextures[VisualGrass] = LoadTexture("res://assets/texture/terrain/grass/shore/water_dual16.png");
        ShoreTextures[VisualSand] = LoadTexture("res://assets/texture/terrain/sand/shore/water_dual16.png");

        ShoreCombinedTextures[VisualBaseSoil] = LoadTexture("res://assets/texture/terrain/base_soil/shore/water_shore_dual16.png");
        ShoreCombinedTextures[VisualDirt] = LoadTexture("res://assets/texture/terrain/dirt/shore/water_shore_dual16.png");
        ShoreCombinedTextures[VisualGrass] = LoadTexture("res://assets/texture/terrain/grass/shore/water_shore_dual16.png");
        ShoreCombinedTextures[VisualSand] = LoadTexture("res://assets/texture/terrain/sand/shore/water_shore_dual16.png");

        AnimatedShoreShadowTextures[VisualBaseSoil] = LoadTextureFrames("res://assets/texture/terrain/base_soil/shore/anim_11/water_shadow_dual16_{0:D2}.png");
        AnimatedShoreShadowTextures[VisualDirt] = LoadTextureFrames("res://assets/texture/terrain/dirt/shore/anim_11/water_shadow_dual16_{0:D2}.png");
        AnimatedShoreShadowTextures[VisualGrass] = LoadTextureFrames("res://assets/texture/terrain/grass/shore/anim_11/water_shadow_dual16_{0:D2}.png");
        AnimatedShoreShadowTextures[VisualSand] = LoadTextureFrames("res://assets/texture/terrain/sand/shore/anim_11/water_shadow_dual16_{0:D2}.png");

        AnimatedShoreTextures[VisualBaseSoil] = LoadTextureFrames("res://assets/texture/terrain/base_soil/shore/anim_11/water_dual16_{0:D2}.png");
        AnimatedShoreTextures[VisualDirt] = LoadTextureFrames("res://assets/texture/terrain/dirt/shore/anim_11/water_dual16_{0:D2}.png");
        AnimatedShoreTextures[VisualGrass] = LoadTextureFrames("res://assets/texture/terrain/grass/shore/anim_11/water_dual16_{0:D2}.png");
        AnimatedShoreTextures[VisualSand] = LoadTextureFrames("res://assets/texture/terrain/sand/shore/anim_11/water_dual16_{0:D2}.png");

        AnimatedShoreCombinedTextures[VisualBaseSoil] = LoadTextureFrames("res://assets/texture/terrain/base_soil/shore/anim_11/water_shore_dual16_{0:D2}.png");
        AnimatedShoreCombinedTextures[VisualDirt] = LoadTextureFrames("res://assets/texture/terrain/dirt/shore/anim_11/water_shore_dual16_{0:D2}.png");
        AnimatedShoreCombinedTextures[VisualGrass] = LoadTextureFrames("res://assets/texture/terrain/grass/shore/anim_11/water_shore_dual16_{0:D2}.png");
        AnimatedShoreCombinedTextures[VisualSand] = LoadTextureFrames("res://assets/texture/terrain/sand/shore/anim_11/water_shore_dual16_{0:D2}.png");
    }

    private static void LoadWaterEffects()
    {
        WaterFoamTexture = LoadTexture("res://assets/texture/terrain/water/effect/foam_dual16.png");
    }

    private static Texture2D LoadTexture(string path)
    {
        Texture2D texture = GD.Load<Texture2D>(path);
        if (texture == null)
            GD.PushWarning($"Terrain texture missing: {path}");
        return texture;
    }

    private static Texture2D[] LoadTextureFrames(string pathFormat)
    {
        Texture2D[] frames = new Texture2D[WaterAnimationFrameCount];
        for (int frame = 0; frame < WaterAnimationFrameCount; frame++)
            frames[frame] = LoadTexture(string.Format(pathFormat, frame));
        return frames;
    }

    private static int ReadInt(GodotDictionary data, string key, int fallback)
    {
        return data.TryGetValue(key, out Variant value) ? value.AsInt32() : fallback;
    }

    private static int[] ReadInt32Array(GodotDictionary data, string key)
    {
        return data.TryGetValue(key, out Variant value) ? value.AsInt32Array() : System.Array.Empty<int>();
    }

    private static int PosMod(int value, int modulo)
    {
        int result = value % modulo;
        return result < 0 ? result + modulo : result;
    }

    private int GetWaterAnimationFrameForDraw()
    {
        double framesPerSecond = GetWaterAnimationFramesPerSecondForDraw();
        if (framesPerSecond <= 0.0)
            return 0;
        return GetWaterAnimationFrame(framesPerSecond);
    }

    private double GetWaterAnimationFramesPerSecondForDraw()
    {
        float screenTileSize = GetApproximateScreenTileSize();
        if (screenTileSize < FreezeWaterAnimationBelowScreenPixels)
            return 0.0;
        if (screenTileSize < SlowWaterAnimationBelowScreenPixels)
            return MidWaterAnimationFramesPerSecond;
        return NearWaterAnimationFramesPerSecond;
    }

    private float GetApproximateScreenTileSize()
    {
        Transform2D transform = GetGlobalTransformWithCanvas();
        float scaleX = transform.X.Length();
        float scaleY = transform.Y.Length();
        return _tileSize * (scaleX + scaleY) * 0.5f;
    }

    private static int GetWaterAnimationFrame(double framesPerSecond)
    {
        ulong step = (ulong)System.Math.Floor(Time.GetTicksMsec() * framesPerSecond / 1000.0);
        if (step == CachedWaterAnimationStep && System.Math.Abs(framesPerSecond - CachedWaterAnimationFramesPerSecond) < 0.001)
            return CachedWaterAnimationFrame;

        CachedWaterAnimationStep = step;
        CachedWaterAnimationFramesPerSecond = framesPerSecond;
        CachedWaterAnimationFrame = (int)(step % WaterAnimationFrameCount);
        return CachedWaterAnimationFrame;
    }
}
