using Godot;
using System.Collections.Generic;
using GodotDictionary = Godot.Collections.Dictionary;
using GodotArray = Godot.Collections.Array;

public partial class TerrainChunkCanvas : Node2D
{
    private const int SourceTileSize = 64;
    private const int CycleSize = 4;
    private const int CommandStride = 5;
    private const int BaseTilePatchSize = 1;
    private const int Patch2Size = 2;
    private const int Patch4Size = 4;
    private const int WaterAnimationFrameCount = 11;
    private const int WaterAnimationRedrawBuckets = 4;
    private const double NearWaterAnimationFramesPerSecond = 4.0;
    private const double MidWaterAnimationFramesPerSecond = 1.0;
    private const float FreezeWaterAnimationBelowScreenPixels = 10.0f;
    private const float SlowWaterAnimationBelowScreenPixels = 16.0f;

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
    private static TerrainVisualSpec VisualSpec = TerrainVisualSpec.CreateDefault();
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
    private int _waterAnimationRedrawBucket;
    private bool _hasAnimatedWater;
    private readonly List<RenderBatch> _renderBatches = new();
    private bool _renderBatchesDirty = true;

    public override void _Ready()
    {
        TextureFilter = TextureFilterEnum.LinearWithMipmaps;
        SetProcess(_hasAnimatedWater);
    }

    public static void ConfigureTerrainVisualSpec(TerrainVisualSpec visualSpec)
    {
        VisualSpec = visualSpec ?? TerrainVisualSpec.CreateDefault();
        TexturesLoaded = false;
        BaseTextures.Clear();
        BasePatch2Textures.Clear();
        BasePatch4Textures.Clear();
        OverlayTextures.Clear();
        ShoreShadowTextures.Clear();
        ShoreTextures.Clear();
        ShoreCombinedTextures.Clear();
        AnimatedBaseTextures.Clear();
        AnimatedBasePatch2Textures.Clear();
        AnimatedBasePatch4Textures.Clear();
        AnimatedOverlayTextures.Clear();
        AnimatedShoreShadowTextures.Clear();
        AnimatedShoreTextures.Clear();
        AnimatedShoreCombinedTextures.Clear();
        WaterFoamTexture = null;
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
        _waterAnimationRedrawBucket = GetChunkAnimationRedrawBucket(_chunkCoord);
        _hasAnimatedWater = HasAnimatedWaterContent();
        _waterAnimationFrame = GetWaterAnimationFrameForDraw();
        _renderBatches.Clear();
        _renderBatchesDirty = true;
        SetProcess(_hasAnimatedWater);
        Name = $"TerrainChunkCanvas_{_chunkCoord.X}_{_chunkCoord.Y}";
        QueueRedraw();
    }

    public override void _Process(double delta)
    {
        if (!_hasAnimatedWater)
            return;

        double framesPerSecond = GetWaterAnimationFramesPerSecondForDraw();
        if (framesPerSecond <= 0.0)
            return;

        int frame = GetWaterAnimationFrame(framesPerSecond);
        if (frame == _waterAnimationFrame)
            return;
        if (!IsWaterAnimationRedrawBucketActive(framesPerSecond))
            return;

        _waterAnimationFrame = frame;
        QueueRedraw();
    }

    public override void _Draw()
    {
        EnsureTexturesLoaded();
        if (_hasAnimatedWater)
            _waterAnimationFrame = GetWaterAnimationFrameForDraw();
        if (_renderBatchesDirty)
            RebuildRenderBatches();
        DrawRenderBatches();
    }

    public void SetRenderActive(bool active)
    {
        Visible = active;
        SetProcess(active && _hasAnimatedWater && GetWaterAnimationFramesPerSecondForDraw() > 0.0);
    }

    private void RebuildRenderBatches()
    {
        _renderBatches.Clear();

        var builders = new List<RenderBatchBuilder>();
        var buildersByKey = new Dictionary<BatchKey, RenderBatchBuilder>();
        BuildBaseTileBatches(buildersByKey, builders);
        BuildBasePatchBatches(buildersByKey, builders);
        BuildCommandBatches(_overlayCommands, TerrainBatchLayer.Overlay, buildersByKey, builders);
        BuildShoreBatches(buildersByKey, builders);
        BuildCommandBatches(_foamCommands, TerrainBatchLayer.Foam, buildersByKey, builders);

        foreach (RenderBatchBuilder builder in builders)
        {
            RenderBatch batch = builder.Build();
            if (batch.Mesh != null)
                _renderBatches.Add(batch);
        }

        _renderBatchesDirty = false;
    }

    private void DrawRenderBatches()
    {
        foreach (RenderBatch batch in _renderBatches)
        {
            Texture2D texture = GetBatchTexture(batch.Key);
            if (texture == null)
                continue;
            DrawMesh(batch.Mesh, texture);
        }
    }

    public GodotDictionary GetTerrainDebugSnapshot()
    {
        int renderQuadCount = 0;
        foreach (RenderBatch batch in _renderBatches)
            renderQuadCount += batch.QuadCount;

        return new GodotDictionary
        {
            ["render_batches"] = _renderBatches.Count,
            ["render_quads"] = renderQuadCount,
            ["render_batches_dirty"] = _renderBatchesDirty,
            ["base_tile_quads"] = CountBaseTileQuads(),
            ["base_patch_quads"] = _basePatchCommands.Length / CommandStride,
            ["overlay_quads"] = _overlayCommands.Length / CommandStride,
            ["shore_quads"] = _shoreCommands.Length / CommandStride,
            ["foam_quads"] = _foamCommands.Length / CommandStride,
            ["has_animated_water"] = _hasAnimatedWater,
            ["water_animation_active"] = IsProcessing(),
            ["water_animation_bucket"] = _waterAnimationRedrawBucket
        };
    }

    private void BuildBaseTileBatches(
        Dictionary<BatchKey, RenderBatchBuilder> buildersByKey,
        List<RenderBatchBuilder> builders
    )
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

                int visual = _baseVisuals[index];
                var key = new BatchKey(TerrainBatchLayer.Base, visual, BaseTilePatchSize);
                Texture2D texture = GetBatchTexture(key);
                if (texture == null)
                    continue;

                GetOrCreateBatchBuilder(key, texture, buildersByKey, builders)
                    .AddQuad(
                        GetTileDestination(localX, localY),
                        GetBaseSource(_baseCycles[index])
                    );
            }
        }
    }

    private void BuildBasePatchBatches(
        Dictionary<BatchKey, RenderBatchBuilder> buildersByKey,
        List<RenderBatchBuilder> builders
    )
    {
        for (int index = 0; index + CommandStride - 1 < _basePatchCommands.Length; index += CommandStride)
        {
            int localX = _basePatchCommands[index];
            int localY = _basePatchCommands[index + 1];
            int visual = _basePatchCommands[index + 2];
            int patchSize = _basePatchCommands[index + 3];
            int variant = _basePatchCommands[index + 4];

            var key = new BatchKey(TerrainBatchLayer.BasePatch, visual, patchSize);
            Texture2D texture = GetBatchTexture(key);
            if (texture == null)
                continue;

            GetOrCreateBatchBuilder(key, texture, buildersByKey, builders)
                .AddQuad(
                    GetPatchDestination(localX, localY, patchSize),
                    GetPatchSource(patchSize, variant)
                );
        }
    }

    private void BuildCommandBatches(
        int[] commands,
        TerrainBatchLayer layer,
        Dictionary<BatchKey, RenderBatchBuilder> buildersByKey,
        List<RenderBatchBuilder> builders
    )
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

            var key = new BatchKey(layer, visual, BaseTilePatchSize);
            Texture2D texture = GetBatchTexture(key);
            if (texture == null)
                continue;

            GetOrCreateBatchBuilder(key, texture, buildersByKey, builders)
                .AddQuad(
                    GetTileDestination(localX, localY),
                    GetMaskedSource(mask, cycle)
                );
        }
    }

    private void BuildShoreBatches(
        Dictionary<BatchKey, RenderBatchBuilder> buildersByKey,
        List<RenderBatchBuilder> builders
    )
    {
        for (int index = 0; index + CommandStride - 1 < _shoreCommands.Length; index += CommandStride)
        {
            int localX = _shoreCommands[index];
            int localY = _shoreCommands[index + 1];
            int visual = _shoreCommands[index + 2];
            int mask = _shoreCommands[index + 3];
            int cycle = _shoreCommands[index + 4];
            if (mask <= 0 || mask >= 15)
                continue;

            var combinedKey = new BatchKey(TerrainBatchLayer.ShoreCombined, visual, BaseTilePatchSize);
            Texture2D combinedTexture = GetBatchTexture(combinedKey);
            if (combinedTexture != null)
            {
                GetOrCreateBatchBuilder(combinedKey, combinedTexture, buildersByKey, builders)
                    .AddQuad(
                        GetTileDestination(localX, localY),
                        GetMaskedSource(mask, cycle)
                    );
                continue;
            }

            AddShoreBatchQuad(
                TerrainBatchLayer.ShoreShadow,
                visual,
                localX,
                localY,
                mask,
                cycle,
                buildersByKey,
                builders
            );
            AddShoreBatchQuad(
                TerrainBatchLayer.Shore,
                visual,
                localX,
                localY,
                mask,
                cycle,
                buildersByKey,
                builders
            );
        }
    }

    private void AddShoreBatchQuad(
        TerrainBatchLayer layer,
        int visual,
        int localX,
        int localY,
        int mask,
        int cycle,
        Dictionary<BatchKey, RenderBatchBuilder> buildersByKey,
        List<RenderBatchBuilder> builders
    )
    {
        var key = new BatchKey(layer, visual, BaseTilePatchSize);
        Texture2D texture = GetBatchTexture(key);
        if (texture == null)
            return;

        GetOrCreateBatchBuilder(key, texture, buildersByKey, builders)
            .AddQuad(
                GetTileDestination(localX, localY),
                GetMaskedSource(mask, cycle)
            );
    }

    private RenderBatchBuilder GetOrCreateBatchBuilder(
        BatchKey key,
        Texture2D texture,
        Dictionary<BatchKey, RenderBatchBuilder> buildersByKey,
        List<RenderBatchBuilder> builders
    )
    {
        if (buildersByKey.TryGetValue(key, out RenderBatchBuilder builder))
            return builder;

        builder = new RenderBatchBuilder(key, texture.GetWidth(), texture.GetHeight());
        buildersByKey[key] = builder;
        builders.Add(builder);
        return builder;
    }

    private Texture2D GetBatchTexture(BatchKey key)
    {
        return key.Layer switch
        {
            TerrainBatchLayer.Base => GetBaseTextureForDraw(key.Visual),
            TerrainBatchLayer.BasePatch => GetBasePatchTextureForDraw(key.Visual, key.PatchSize),
            TerrainBatchLayer.Overlay => GetOverlayTextureForDraw(key.Visual),
            TerrainBatchLayer.ShoreShadow => GetShoreShadowTextureForDraw(key.Visual),
            TerrainBatchLayer.Shore => GetShoreTextureForDraw(key.Visual),
            TerrainBatchLayer.ShoreCombined => GetShoreCombinedTextureForDraw(key.Visual),
            TerrainBatchLayer.Foam => WaterFoamTexture,
            _ => null
        };
    }

    private int CountBaseTileQuads()
    {
        int tileCount = _chunkSize * _chunkSize;
        if (_baseVisuals.Length < tileCount || _baseCycles.Length < tileCount)
            return 0;

        int visibleBaseTileCount = 0;
        for (int index = 0; index < tileCount; index++)
        {
            if (index < _basePatchCovered.Length && _basePatchCovered[index])
                continue;
            visibleBaseTileCount++;
        }
        return visibleBaseTileCount;
    }

    private Rect2 GetTileDestination(int localX, int localY)
    {
        return new Rect2(localX * _tileSize, localY * _tileSize, _tileSize, _tileSize);
    }

    private Rect2 GetPatchDestination(int localX, int localY, int patchSize)
    {
        return new Rect2(
            localX * _tileSize,
            localY * _tileSize,
            _tileSize * patchSize,
            _tileSize * patchSize
        );
    }

    private static Rect2 GetBaseSource(int cycle)
    {
        int safeCycle = PosMod(cycle, CycleSize * CycleSize);
        return new Rect2(safeCycle * SourceTileSize, 0, SourceTileSize, SourceTileSize);
    }

    private static Rect2 GetPatchSource(int patchSize, int variant)
    {
        int sourceSize = SourceTileSize * patchSize;
        return new Rect2(
            PosMod(variant, CycleSize * CycleSize) * sourceSize,
            0,
            sourceSize,
            sourceSize
        );
    }

    private static Rect2 GetMaskedSource(int mask, int cycle)
    {
        return new Rect2(
            mask * SourceTileSize,
            PosMod(cycle, CycleSize * CycleSize) * SourceTileSize,
            SourceTileSize,
            SourceTileSize
        );
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
        if (HasAnimatedShoreCommand(_shoreCommands))
            return true;

        foreach (int visual in _baseVisuals)
        {
            if (HasAnimatedWaterBaseVisual(visual))
                return true;
        }

        return HasAnimatedWaterBasePatchCommand(_basePatchCommands) || HasAnimatedWaterOverlayCommand(_overlayCommands);
    }

    private static bool HasAnimatedWaterBaseVisual(int visual)
    {
        return VisualSpec.IsWaterVisual(visual) && VisualSpec.GetTextureSpec(visual).HasAnimatedBase1X1;
    }

    private static bool HasAnimatedWaterBasePatchCommand(int[] commands)
    {
        for (int index = 0; index + CommandStride - 1 < commands.Length; index += CommandStride)
        {
            int visual = commands[index + 2];
            if (!VisualSpec.IsWaterVisual(visual))
                continue;

            int patchSize = commands[index + 3];
            TerrainVisualTextureSpec textures = VisualSpec.GetTextureSpec(visual);
            if ((patchSize == Patch2Size && textures.HasAnimatedBase2X2)
                || (patchSize == Patch4Size && textures.HasAnimatedBase4X4)
                || (patchSize != Patch2Size && patchSize != Patch4Size && textures.HasAnimatedBase1X1))
                return true;
        }
        return false;
    }

    private static bool HasAnimatedWaterOverlayCommand(int[] commands)
    {
        for (int index = 0; index + CommandStride - 1 < commands.Length; index += CommandStride)
        {
            int visual = commands[index + 2];
            if (VisualSpec.IsWaterVisual(visual) && VisualSpec.GetTextureSpec(visual).HasAnimatedOverlay)
                return true;
        }
        return false;
    }

    private static bool HasAnimatedShoreCommand(int[] commands)
    {
        for (int index = 0; index + CommandStride - 1 < commands.Length; index += CommandStride)
        {
            int visual = commands[index + 2];
            if (VisualSpec.GetTextureSpec(visual).HasAnimatedShore)
                return true;
        }
        return false;
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
        return GetAnimatedTexture(animatedTextures, visual, _waterAnimationFrame)
            ?? GetBasePatchTexture(visual, patchSize);
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
        return GetAnimatedTexture(AnimatedShoreShadowTextures, visual, _waterAnimationFrame)
            ?? GetShoreShadowTexture(visual);
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
            ?? GetShoreCombinedTexture(visual);
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

        foreach (int visual in VisualSpec.VisualIndices)
        {
            TerrainVisualTextureSpec textures = VisualSpec.GetTextureSpec(visual);
            BaseTextures[visual] = LoadTexture(textures.Base1X1, true);
            BasePatch2Textures[visual] = LoadTexture(textures.Base2X2, false);
            BasePatch4Textures[visual] = LoadTexture(textures.Base4X4, false);
            OverlayTextures[visual] = LoadTexture(textures.Overlay, false);
            ShoreShadowTextures[visual] = LoadTexture(textures.ShoreShadow, false);
            ShoreTextures[visual] = LoadTexture(textures.Shore, false);
            ShoreCombinedTextures[visual] = LoadTexture(textures.ShoreCombined, false);
            LoadAnimatedTexturesForVisual(visual, textures);
        }

        WaterFoamTexture = LoadTexture(VisualSpec.FoamTexturePath, false);
    }

    private static void LoadAnimatedTexturesForVisual(int visual, TerrainVisualTextureSpec textures)
    {
        AnimatedBaseTextures[visual] = LoadTextureFrames(textures.AnimatedBase1X1);
        AnimatedBasePatch2Textures[visual] = LoadTextureFrames(textures.AnimatedBase2X2);
        AnimatedBasePatch4Textures[visual] = LoadTextureFrames(textures.AnimatedBase4X4);
        AnimatedOverlayTextures[visual] = LoadTextureFrames(textures.AnimatedOverlay);
        AnimatedShoreShadowTextures[visual] = LoadTextureFrames(textures.AnimatedShoreShadow);
        AnimatedShoreTextures[visual] = LoadTextureFrames(textures.AnimatedShore);
        AnimatedShoreCombinedTextures[visual] = LoadTextureFrames(textures.AnimatedShoreCombined);
    }

    private static Texture2D LoadTexture(string path, bool required)
    {
        if (string.IsNullOrEmpty(path))
            return null;

        if (CanLoadAsGodotResource(path))
        {
            Texture2D texture = GD.Load<Texture2D>(path);
            if (texture != null)
                return texture;
        }

        Image image = Image.LoadFromFile(GetImageFilePath(path));
        if (image != null && !image.IsEmpty())
            return ImageTexture.CreateFromImage(image);

        if (required)
            GD.PushError($"Required terrain texture missing: {path}");
        else
            GD.PushWarning($"Terrain texture missing: {path}");
        return null;
    }

    private static bool CanLoadAsGodotResource(string path)
    {
        return path.StartsWith("res://");
    }

    private static string GetImageFilePath(string path)
    {
        return path.StartsWith("res://") || path.StartsWith("user://")
            ? ProjectSettings.GlobalizePath(path)
            : path;
    }

    private static Texture2D[] LoadTextureFrames(string pathFormat)
    {
        if (string.IsNullOrEmpty(pathFormat))
            return System.Array.Empty<Texture2D>();

        Texture2D[] frames = new Texture2D[WaterAnimationFrameCount];
        for (int frame = 0; frame < WaterAnimationFrameCount; frame++)
        {
            frames[frame] = LoadTexture(string.Format(pathFormat, frame), false);
        }
        return frames;
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
        float screenTileSize = GetScreenTileSize();
        if (screenTileSize < FreezeWaterAnimationBelowScreenPixels)
            return 0.0;
        if (screenTileSize < SlowWaterAnimationBelowScreenPixels)
            return MidWaterAnimationFramesPerSecond;
        return NearWaterAnimationFramesPerSecond;
    }

    private float GetScreenTileSize()
    {
        Viewport viewport = GetViewport();
        Camera2D camera = viewport?.GetCamera2D();
        float zoom = camera != null ? camera.Zoom.X : 1.0f;
        return _tileSize * zoom;
    }

    private static int GetWaterAnimationFrame(double framesPerSecond)
    {
        ulong step = (ulong)(Time.GetTicksMsec() / System.Math.Max(1.0, 1000.0 / framesPerSecond));
        if (step == CachedWaterAnimationStep && System.Math.Abs(framesPerSecond - CachedWaterAnimationFramesPerSecond) < 0.001)
            return CachedWaterAnimationFrame;

        CachedWaterAnimationStep = step;
        CachedWaterAnimationFramesPerSecond = framesPerSecond;
        CachedWaterAnimationFrame = (int)(step % WaterAnimationFrameCount);
        return CachedWaterAnimationFrame;
    }

    private bool IsWaterAnimationRedrawBucketActive(double framesPerSecond)
    {
        int bucketCount = GetWaterAnimationRedrawBucketCount(framesPerSecond);
        if (bucketCount <= 1)
            return true;

        int intervalMs = GetWaterAnimationIntervalMilliseconds(framesPerSecond);
        int bucketMs = System.Math.Max(1, intervalMs / bucketCount);
        int activeBucket = (int)((Time.GetTicksMsec() % (ulong)intervalMs) / (ulong)bucketMs);
        if (activeBucket >= bucketCount)
            activeBucket = bucketCount - 1;

        return _waterAnimationRedrawBucket % bucketCount == activeBucket;
    }

    private static int GetWaterAnimationRedrawBucketCount(double framesPerSecond)
    {
        int intervalMs = GetWaterAnimationIntervalMilliseconds(framesPerSecond);
        int frameBudgetBuckets = System.Math.Max(1, intervalMs / 16);
        return System.Math.Max(1, System.Math.Min(WaterAnimationRedrawBuckets, frameBudgetBuckets));
    }

    private static int GetWaterAnimationIntervalMilliseconds(double framesPerSecond)
    {
        return (int)System.Math.Max(1.0, 1000.0 / framesPerSecond);
    }

    private static int GetChunkAnimationRedrawBucket(Vector2I chunkCoord)
    {
        unchecked
        {
            int hash = (chunkCoord.X * 73856093) ^ (chunkCoord.Y * 19349663);
            return PosMod(hash, WaterAnimationRedrawBuckets);
        }
    }

    private enum TerrainBatchLayer
    {
        Base,
        BasePatch,
        Overlay,
        ShoreShadow,
        Shore,
        ShoreCombined,
        Foam
    }

    private readonly struct BatchKey : System.IEquatable<BatchKey>
    {
        public readonly TerrainBatchLayer Layer;
        public readonly int Visual;
        public readonly int PatchSize;

        public BatchKey(TerrainBatchLayer layer, int visual, int patchSize)
        {
            Layer = layer;
            Visual = visual;
            PatchSize = patchSize;
        }

        public bool Equals(BatchKey other)
        {
            return Layer == other.Layer
                && Visual == other.Visual
                && PatchSize == other.PatchSize;
        }

        public override bool Equals(object obj)
        {
            return obj is BatchKey other && Equals(other);
        }

        public override int GetHashCode()
        {
            unchecked
            {
                int hash = 17;
                hash = hash * 31 + (int)Layer;
                hash = hash * 31 + Visual;
                hash = hash * 31 + PatchSize;
                return hash;
            }
        }
    }

    private sealed class RenderBatch
    {
        public BatchKey Key { get; }
        public Mesh Mesh { get; }
        public int QuadCount { get; }

        public RenderBatch(BatchKey key, Mesh mesh, int quadCount)
        {
            Key = key;
            Mesh = mesh;
            QuadCount = quadCount;
        }
    }

    private sealed class RenderBatchBuilder
    {
        private readonly List<Vector3> _vertices = new();
        private readonly List<Vector2> _uvs = new();
        private readonly List<int> _indices = new();
        private readonly float _inverseTextureWidth;
        private readonly float _inverseTextureHeight;
        private int _quadCount;

        public BatchKey Key { get; }

        public RenderBatchBuilder(BatchKey key, int textureWidth, int textureHeight)
        {
            Key = key;
            _inverseTextureWidth = 1.0f / System.Math.Max(textureWidth, 1);
            _inverseTextureHeight = 1.0f / System.Math.Max(textureHeight, 1);
        }

        public void AddQuad(Rect2 destination, Rect2 source)
        {
            int vertexStart = _vertices.Count;
            float left = destination.Position.X;
            float top = destination.Position.Y;
            float right = destination.Position.X + destination.Size.X;
            float bottom = destination.Position.Y + destination.Size.Y;
            float uvLeft = source.Position.X * _inverseTextureWidth;
            float uvTop = source.Position.Y * _inverseTextureHeight;
            float uvRight = (source.Position.X + source.Size.X) * _inverseTextureWidth;
            float uvBottom = (source.Position.Y + source.Size.Y) * _inverseTextureHeight;

            _vertices.Add(new Vector3(left, top, 0.0f));
            _vertices.Add(new Vector3(right, top, 0.0f));
            _vertices.Add(new Vector3(right, bottom, 0.0f));
            _vertices.Add(new Vector3(left, bottom, 0.0f));

            _uvs.Add(new Vector2(uvLeft, uvTop));
            _uvs.Add(new Vector2(uvRight, uvTop));
            _uvs.Add(new Vector2(uvRight, uvBottom));
            _uvs.Add(new Vector2(uvLeft, uvBottom));

            _indices.Add(vertexStart);
            _indices.Add(vertexStart + 1);
            _indices.Add(vertexStart + 2);
            _indices.Add(vertexStart);
            _indices.Add(vertexStart + 2);
            _indices.Add(vertexStart + 3);
            _quadCount++;
        }

        public RenderBatch Build()
        {
            if (_vertices.Count <= 0)
                return new RenderBatch(Key, null, 0);

            var arrays = new GodotArray();
            arrays.Resize((int)Mesh.ArrayType.Max);
            arrays[(int)Mesh.ArrayType.Vertex] = _vertices.ToArray();
            arrays[(int)Mesh.ArrayType.TexUV] = _uvs.ToArray();
            arrays[(int)Mesh.ArrayType.Index] = _indices.ToArray();

            var mesh = new ArrayMesh();
            mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays);
            return new RenderBatch(Key, mesh, _quadCount);
        }
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
}
