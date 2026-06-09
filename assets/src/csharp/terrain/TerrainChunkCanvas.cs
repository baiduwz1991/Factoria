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
    private static Texture2D WaterFoamTexture;
    private static bool TexturesLoaded;

    private Vector2I _chunkCoord = Vector2I.Zero;
    private int _chunkSize = 1;
    private int _tileSize = 32;
    private int[] _baseVisuals = System.Array.Empty<int>();
    private int[] _baseCycles = System.Array.Empty<int>();
    private int[] _basePatchCommands = System.Array.Empty<int>();
    private int[] _overlayCommands = System.Array.Empty<int>();
    private int[] _shoreCommands = System.Array.Empty<int>();
    private int[] _foamCommands = System.Array.Empty<int>();

    public override void _Ready()
    {
        TextureFilter = TextureFilterEnum.LinearWithMipmaps;
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
        _overlayCommands = ReadInt32Array(visualData, "overlay_commands");
        _shoreCommands = ReadInt32Array(visualData, "shore_commands");
        _foamCommands = ReadInt32Array(visualData, "foam_commands");
        Name = $"TerrainChunkCanvas_{_chunkCoord.X}_{_chunkCoord.Y}";
        QueueRedraw();
    }

    public override void _Draw()
    {
        EnsureTexturesLoaded();
        DrawBaseTiles();
        DrawBasePatchCommands();
        DrawCommands(_overlayCommands, GetOverlayTexture);
        DrawCommands(_shoreCommands, GetShoreShadowTexture);
        DrawCommands(_shoreCommands, GetShoreTexture);
        DrawCommands(_foamCommands, _ => WaterFoamTexture);
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
                Texture2D texture = GetBaseTexture(_baseVisuals[index]);
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

            Texture2D texture = GetBasePatchTexture(visual, patchSize);
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

    private static Texture2D GetBaseTexture(int visual)
    {
        return BaseTextures.TryGetValue(visual, out Texture2D texture) ? texture : null;
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

    private static Texture2D GetOverlayTexture(int visual)
    {
        return OverlayTextures.TryGetValue(visual, out Texture2D texture) ? texture : null;
    }

    private static Texture2D GetShoreShadowTexture(int visual)
    {
        return ShoreShadowTextures.TryGetValue(visual, out Texture2D texture) ? texture : null;
    }

    private static Texture2D GetShoreTexture(int visual)
    {
        return ShoreTextures.TryGetValue(visual, out Texture2D texture) ? texture : null;
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
    }

    private static void LoadOverlayTextures()
    {
        OverlayTextures[VisualDirt] = LoadTexture("res://assets/texture/terrain/dirt/overlay/dual16.png");
        OverlayTextures[VisualGrass] = LoadTexture("res://assets/texture/terrain/grass/overlay/dual16.png");
        OverlayTextures[VisualSand] = LoadTexture("res://assets/texture/terrain/sand/overlay/dual16.png");
        OverlayTextures[VisualWater] = LoadTexture("res://assets/texture/terrain/water/overlay/dual16.png");
        OverlayTextures[VisualDeepWater] = LoadTexture("res://assets/texture/terrain/deep_water/overlay/dual16.png");
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
