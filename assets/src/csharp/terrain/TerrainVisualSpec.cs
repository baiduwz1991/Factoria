using Godot;
using System.Collections.Generic;
using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

public sealed class TerrainVisualSpec
{
    private readonly Dictionary<int, TerrainVisualDefinition> _byTerrainId;
    private readonly Dictionary<int, TerrainVisualDefinition> _byVisualIndex;
    private readonly int[] _visualIndices;
    private readonly int[] _landVisualIndices;

    public int DefaultRuntimeId { get; }
    public int FoamVisualIndex { get; }
    public string FoamTexturePath { get; }
    public IReadOnlyList<int> VisualIndices => _visualIndices;
    public IReadOnlyList<int> LandVisualIndices => _landVisualIndices;

    private TerrainVisualSpec(
        int defaultRuntimeId,
        string foamTexturePath,
        Dictionary<int, TerrainVisualDefinition> byTerrainId,
        Dictionary<int, TerrainVisualDefinition> byVisualIndex
    )
    {
        DefaultRuntimeId = defaultRuntimeId;
        FoamTexturePath = foamTexturePath ?? string.Empty;
        _byTerrainId = byTerrainId;
        _byVisualIndex = byVisualIndex;
        _visualIndices = BuildVisualIndexArray(byVisualIndex, false);
        _landVisualIndices = BuildVisualIndexArray(byVisualIndex, true);
        FoamVisualIndex = FindFoamVisualIndex(byVisualIndex, defaultRuntimeId);
    }

    public static TerrainVisualSpec CreateDefault()
    {
        var byTerrainId = new Dictionary<int, TerrainVisualDefinition>();
        var byVisualIndex = new Dictionary<int, TerrainVisualDefinition>();
        AddDefinition(byTerrainId, byVisualIndex, new TerrainVisualDefinition(
            1,
            1,
            "core.base_soil",
            0,
            false,
            TerrainVisualTextureSpec.Create(
                "res://assets/texture/terrain/base_soil/base/1x1.png",
                "res://assets/texture/terrain/base_soil/base/2x2/2x2.png",
                "res://assets/texture/terrain/base_soil/base/4x4/4x4.png",
                string.Empty,
                "res://assets/texture/terrain/base_soil/shore/water_shadow_dual16.png",
                "res://assets/texture/terrain/base_soil/shore/water_dual16.png"
            )
        ));
        AddDefinition(byTerrainId, byVisualIndex, new TerrainVisualDefinition(
            2,
            2,
            "core.dirt",
            10,
            false,
            TerrainVisualTextureSpec.Create(
                "res://assets/texture/terrain/dirt/base/1x1.png",
                "res://assets/texture/terrain/dirt/base/2x2/2x2.png",
                "res://assets/texture/terrain/dirt/base/4x4/4x4.png",
                "res://assets/texture/terrain/dirt/overlay/dual16.png",
                "res://assets/texture/terrain/dirt/shore/water_shadow_dual16.png",
                "res://assets/texture/terrain/dirt/shore/water_dual16.png"
            )
        ));
        AddDefinition(byTerrainId, byVisualIndex, new TerrainVisualDefinition(
            3,
            3,
            "core.grass",
            20,
            false,
            TerrainVisualTextureSpec.Create(
                "res://assets/texture/terrain/grass/base/1x1.png",
                "res://assets/texture/terrain/grass/base/2x2/2x2.png",
                "res://assets/texture/terrain/grass/base/4x4/4x4.png",
                "res://assets/texture/terrain/grass/overlay/dual16.png",
                "res://assets/texture/terrain/grass/shore/water_shadow_dual16.png",
                "res://assets/texture/terrain/grass/shore/water_dual16.png"
            )
        ));
        AddDefinition(byTerrainId, byVisualIndex, new TerrainVisualDefinition(
            4,
            4,
            "core.sand",
            30,
            false,
            TerrainVisualTextureSpec.Create(
                "res://assets/texture/terrain/sand/base/1x1.png",
                "res://assets/texture/terrain/sand/base/2x2/2x2.png",
                "res://assets/texture/terrain/sand/base/4x4/4x4.png",
                "res://assets/texture/terrain/sand/overlay/dual16.png",
                "res://assets/texture/terrain/sand/shore/water_shadow_dual16.png",
                "res://assets/texture/terrain/sand/shore/water_dual16.png"
            )
        ));
        AddDefinition(byTerrainId, byVisualIndex, new TerrainVisualDefinition(
            7,
            7,
            "core.dry_grass",
            18,
            false,
            TerrainVisualTextureSpec.Create(
                "res://assets/texture/terrain/dry_grass/base/1x1.png",
                "res://assets/texture/terrain/dry_grass/base/2x2/2x2.png",
                "res://assets/texture/terrain/dry_grass/base/4x4/4x4.png",
                "res://assets/texture/terrain/dry_grass/overlay/dual16.png",
                "res://assets/texture/terrain/dry_grass/shore/water_shadow_dual16.png",
                "res://assets/texture/terrain/dry_grass/shore/water_dual16.png"
            )
        ));
        AddDefinition(byTerrainId, byVisualIndex, new TerrainVisualDefinition(
            8,
            8,
            "core.dry_dirt",
            12,
            false,
            TerrainVisualTextureSpec.Create(
                "res://assets/texture/terrain/dry_dirt/base/1x1.png",
                "res://assets/texture/terrain/dry_dirt/base/2x2/2x2.png",
                "res://assets/texture/terrain/dry_dirt/base/4x4/4x4.png",
                "res://assets/texture/terrain/dry_dirt/overlay/dual16.png",
                "res://assets/texture/terrain/dry_dirt/shore/water_shadow_dual16.png",
                "res://assets/texture/terrain/dry_dirt/shore/water_dual16.png"
            )
        ));
        AddDefinition(byTerrainId, byVisualIndex, new TerrainVisualDefinition(
            9,
            9,
            "core.red_desert",
            32,
            false,
            TerrainVisualTextureSpec.Create(
                "res://assets/texture/terrain/red_desert/base/1x1.png",
                "res://assets/texture/terrain/red_desert/base/2x2/2x2.png",
                "res://assets/texture/terrain/red_desert/base/4x4/4x4.png",
                "res://assets/texture/terrain/red_desert/overlay/dual16.png",
                "res://assets/texture/terrain/red_desert/shore/water_shadow_dual16.png",
                "res://assets/texture/terrain/red_desert/shore/water_dual16.png"
            )
        ));
        AddDefinition(byTerrainId, byVisualIndex, new TerrainVisualDefinition(
            10,
            10,
            "core.stone_ground",
            35,
            false,
            TerrainVisualTextureSpec.Create(
                "res://assets/texture/terrain/stone_ground/base/1x1.png",
                "res://assets/texture/terrain/stone_ground/base/2x2/2x2.png",
                "res://assets/texture/terrain/stone_ground/base/4x4/4x4.png",
                "res://assets/texture/terrain/stone_ground/overlay/dual16.png",
                "res://assets/texture/terrain/stone_ground/shore/water_shadow_dual16.png",
                "res://assets/texture/terrain/stone_ground/shore/water_dual16.png"
            )
        ));
        AddDefinition(byTerrainId, byVisualIndex, new TerrainVisualDefinition(
            5,
            5,
            "core.water",
            40,
            true,
            TerrainVisualTextureSpec.Create(
                "res://assets/texture/terrain/water/base/1x1.png",
                "res://assets/texture/terrain/water/base/2x2/2x2.png",
                "res://assets/texture/terrain/water/base/4x4/4x4.png",
                "res://assets/texture/terrain/water/overlay/dual16.png",
                string.Empty,
                string.Empty
            )
        ));
        AddDefinition(byTerrainId, byVisualIndex, new TerrainVisualDefinition(
            6,
            6,
            "core.deep_water",
            50,
            true,
            TerrainVisualTextureSpec.Create(
                "res://assets/texture/terrain/deep_water/base/1x1.png",
                "res://assets/texture/terrain/deep_water/base/2x2/2x2.png",
                "res://assets/texture/terrain/deep_water/base/4x4/4x4.png",
                "res://assets/texture/terrain/deep_water/overlay/dual16.png",
                string.Empty,
                string.Empty
            )
        ));

        return new TerrainVisualSpec(
            1,
            "res://assets/texture/terrain/water/effect/foam_dual16.png",
            byTerrainId,
            byVisualIndex
        );
    }

    public static TerrainVisualSpec FromDictionary(GodotDictionary data)
    {
        if (data == null || data.Count == 0)
            return CreateDefault();

        int defaultRuntimeId = ReadInt(data, "default_runtime_id", 1);
        string foamTexturePath = ReadString(data, "foam_texture_path", string.Empty);
        var byTerrainId = new Dictionary<int, TerrainVisualDefinition>();
        var byVisualIndex = new Dictionary<int, TerrainVisualDefinition>();

        if (data.TryGetValue("terrains", out Variant terrainEntriesVariant))
        {
            GodotArray terrainEntries = terrainEntriesVariant.AsGodotArray();
            foreach (Variant rawEntry in terrainEntries)
            {
                GodotDictionary entry = rawEntry.AsGodotDictionary();
                if (entry == null || entry.Count == 0)
                    continue;

                int runtimeId = ReadInt(entry, "runtime_id", 0);
                if (runtimeId <= 0)
                    continue;

                int visualIndex = ReadInt(entry, "visual_index", runtimeId);
                string stableId = ReadString(entry, "stable_id", string.Empty);
                bool isWater = ReadBool(entry, "is_water", false);
                int priority = ReadInt(entry, "priority", 0);
                var textures = TerrainVisualTextureSpec.FromDictionary(ReadDictionary(entry, "textures"));
                AddDefinition(byTerrainId, byVisualIndex, new TerrainVisualDefinition(
                    runtimeId,
                    visualIndex,
                    stableId,
                    priority,
                    isWater,
                    textures
                ));
            }
        }

        if (byTerrainId.Count == 0)
            return CreateDefault();

        return new TerrainVisualSpec(defaultRuntimeId, foamTexturePath, byTerrainId, byVisualIndex);
    }

    public int GetVisualIndexForTerrain(int terrainId)
    {
        return _byTerrainId.TryGetValue(terrainId, out TerrainVisualDefinition definition)
            ? definition.VisualIndex
            : GetDefaultVisualIndex();
    }

    public bool IsWaterTerrain(int terrainId)
    {
        return _byTerrainId.TryGetValue(terrainId, out TerrainVisualDefinition definition) && definition.IsWater;
    }

    public bool IsWaterVisual(int visualIndex)
    {
        return _byVisualIndex.TryGetValue(visualIndex, out TerrainVisualDefinition definition) && definition.IsWater;
    }

    public int GetVisualPriority(int visualIndex)
    {
        return _byVisualIndex.TryGetValue(visualIndex, out TerrainVisualDefinition definition)
            ? definition.Priority
            : 0;
    }

    public TerrainVisualTextureSpec GetTextureSpec(int visualIndex)
    {
        return _byVisualIndex.TryGetValue(visualIndex, out TerrainVisualDefinition definition)
            ? definition.Textures
            : TerrainVisualTextureSpec.Empty;
    }

    private int GetDefaultVisualIndex()
    {
        return _byTerrainId.TryGetValue(DefaultRuntimeId, out TerrainVisualDefinition definition)
            ? definition.VisualIndex
            : DefaultRuntimeId;
    }

    private static void AddDefinition(
        Dictionary<int, TerrainVisualDefinition> byTerrainId,
        Dictionary<int, TerrainVisualDefinition> byVisualIndex,
        TerrainVisualDefinition definition
    )
    {
        byTerrainId[definition.RuntimeId] = definition;
        byVisualIndex[definition.VisualIndex] = definition;
    }

    private static int[] BuildVisualIndexArray(
        Dictionary<int, TerrainVisualDefinition> byVisualIndex,
        bool landOnly
    )
    {
        var result = new List<int>();
        foreach (TerrainVisualDefinition definition in byVisualIndex.Values)
        {
            if (landOnly && definition.IsWater)
                continue;
            result.Add(definition.VisualIndex);
        }
        result.Sort((left, right) =>
        {
            int priorityCompare = byVisualIndex[left].Priority.CompareTo(byVisualIndex[right].Priority);
            return priorityCompare != 0 ? priorityCompare : left.CompareTo(right);
        });
        return result.ToArray();
    }

    private static int FindFoamVisualIndex(
        Dictionary<int, TerrainVisualDefinition> byVisualIndex,
        int defaultRuntimeId
    )
    {
        foreach (TerrainVisualDefinition definition in byVisualIndex.Values)
        {
            if (definition.IsWater)
                return definition.VisualIndex;
        }
        return defaultRuntimeId;
    }

    private static GodotDictionary ReadDictionary(GodotDictionary data, string key)
    {
        return data.TryGetValue(key, out Variant value) ? value.AsGodotDictionary() : new GodotDictionary();
    }

    private static string ReadString(GodotDictionary data, string key, string fallback)
    {
        return data.TryGetValue(key, out Variant value) ? value.AsString() : fallback;
    }

    private static int ReadInt(GodotDictionary data, string key, int fallback)
    {
        return data.TryGetValue(key, out Variant value) ? value.AsInt32() : fallback;
    }

    private static bool ReadBool(GodotDictionary data, string key, bool fallback)
    {
        return data.TryGetValue(key, out Variant value) ? value.AsBool() : fallback;
    }
}

public sealed class TerrainVisualDefinition
{
    public int RuntimeId { get; }
    public int VisualIndex { get; }
    public string StableId { get; }
    public int Priority { get; }
    public bool IsWater { get; }
    public TerrainVisualTextureSpec Textures { get; }

    public TerrainVisualDefinition(
        int runtimeId,
        int visualIndex,
        string stableId,
        int priority,
        bool isWater,
        TerrainVisualTextureSpec textures
    )
    {
        RuntimeId = runtimeId;
        VisualIndex = visualIndex;
        StableId = stableId ?? string.Empty;
        Priority = priority;
        IsWater = isWater;
        Textures = textures ?? TerrainVisualTextureSpec.Empty;
    }
}

public sealed class TerrainVisualTextureSpec
{
    public static TerrainVisualTextureSpec Empty { get; } = Create(
        string.Empty,
        string.Empty,
        string.Empty,
        string.Empty,
        string.Empty,
        string.Empty
    );

    public string Base1X1 { get; }
    public string Base2X2 { get; }
    public string Base4X4 { get; }
    public string Overlay { get; }
    public string ShoreShadow { get; }
    public string Shore { get; }
    public string ShoreCombined { get; }
    public string AnimatedBase1X1 { get; }
    public string AnimatedBase2X2 { get; }
    public string AnimatedBase4X4 { get; }
    public string AnimatedOverlay { get; }
    public string AnimatedShoreShadow { get; }
    public string AnimatedShore { get; }
    public string AnimatedShoreCombined { get; }
    public bool HasAnimatedBase1X1 => HasPath(AnimatedBase1X1);
    public bool HasAnimatedBase2X2 => HasPath(AnimatedBase2X2);
    public bool HasAnimatedBase4X4 => HasPath(AnimatedBase4X4);
    public bool HasAnimatedOverlay => HasPath(AnimatedOverlay);
    public bool HasAnimatedShore => HasPath(AnimatedShoreShadow)
        || HasPath(AnimatedShore)
        || HasPath(AnimatedShoreCombined);

    private TerrainVisualTextureSpec(
        string base1X1,
        string base2X2,
        string base4X4,
        string overlay,
        string shoreShadow,
        string shore,
        string shoreCombined,
        string animatedBase1X1,
        string animatedBase2X2,
        string animatedBase4X4,
        string animatedOverlay,
        string animatedShoreShadow,
        string animatedShore,
        string animatedShoreCombined
    )
    {
        Base1X1 = base1X1 ?? string.Empty;
        Base2X2 = base2X2 ?? string.Empty;
        Base4X4 = base4X4 ?? string.Empty;
        Overlay = overlay ?? string.Empty;
        ShoreShadow = shoreShadow ?? string.Empty;
        Shore = shore ?? string.Empty;
        ShoreCombined = shoreCombined ?? string.Empty;
        AnimatedBase1X1 = animatedBase1X1 ?? string.Empty;
        AnimatedBase2X2 = animatedBase2X2 ?? string.Empty;
        AnimatedBase4X4 = animatedBase4X4 ?? string.Empty;
        AnimatedOverlay = animatedOverlay ?? string.Empty;
        AnimatedShoreShadow = animatedShoreShadow ?? string.Empty;
        AnimatedShore = animatedShore ?? string.Empty;
        AnimatedShoreCombined = animatedShoreCombined ?? string.Empty;
    }

    public static TerrainVisualTextureSpec FromDictionary(GodotDictionary data)
    {
        if (data == null || data.Count == 0)
            return Empty;
        return Create(
            ReadString(data, "base_1x1"),
            ReadString(data, "base_2x2"),
            ReadString(data, "base_4x4"),
            ReadString(data, "overlay"),
            ReadString(data, "shore_shadow"),
            ReadString(data, "shore"),
            ReadString(data, "shore_combined"),
            ReadString(data, "animated_base_1x1"),
            ReadString(data, "animated_base_2x2"),
            ReadString(data, "animated_base_4x4"),
            ReadString(data, "animated_overlay"),
            ReadString(data, "animated_shore_shadow"),
            ReadString(data, "animated_shore"),
            ReadString(data, "animated_shore_combined")
        );
    }

    public static TerrainVisualTextureSpec Create(
        string base1X1,
        string base2X2,
        string base4X4,
        string overlay,
        string shoreShadow,
        string shore
    )
    {
        return Create(base1X1, base2X2, base4X4, overlay, shoreShadow, shore, string.Empty);
    }

    public static TerrainVisualTextureSpec Create(
        string base1X1,
        string base2X2,
        string base4X4,
        string overlay,
        string shoreShadow,
        string shore,
        string shoreCombined,
        string animatedBase1X1 = "",
        string animatedBase2X2 = "",
        string animatedBase4X4 = "",
        string animatedOverlay = "",
        string animatedShoreShadow = "",
        string animatedShore = "",
        string animatedShoreCombined = ""
    )
    {
        return new TerrainVisualTextureSpec(
            base1X1,
            base2X2,
            base4X4,
            overlay,
            shoreShadow,
            shore,
            shoreCombined,
            animatedBase1X1,
            animatedBase2X2,
            animatedBase4X4,
            animatedOverlay,
            animatedShoreShadow,
            animatedShore,
            animatedShoreCombined
        );
    }

    private static string ReadString(GodotDictionary data, string key)
    {
        return data.TryGetValue(key, out Variant value) ? value.AsString() : string.Empty;
    }

    private static bool HasPath(string path)
    {
        return !string.IsNullOrEmpty(path);
    }
}
