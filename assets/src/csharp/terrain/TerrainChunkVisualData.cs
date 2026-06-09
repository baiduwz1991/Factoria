using Godot;
using GodotDictionary = Godot.Collections.Dictionary;

public sealed class TerrainChunkVisualData
{
    public Vector2I ChunkCoord { get; }
    public int ChunkSize { get; }
    public int TileSize { get; }
    public int[] BaseVisuals { get; }
    public int[] BaseCycles { get; }
    public int[] BasePatchCommands { get; }
    public int[] OverlayCommands { get; }
    public int[] ShoreCommands { get; }
    public int[] FoamCommands { get; }
    public int[] WaterRects { get; }

    public TerrainChunkVisualData(
        Vector2I chunkCoord,
        int chunkSize,
        int tileSize,
        int[] baseVisuals,
        int[] baseCycles,
        int[] basePatchCommands,
        int[] overlayCommands,
        int[] shoreCommands,
        int[] foamCommands,
        int[] waterRects
    )
    {
        ChunkCoord = chunkCoord;
        ChunkSize = chunkSize;
        TileSize = tileSize;
        BaseVisuals = baseVisuals;
        BaseCycles = baseCycles;
        BasePatchCommands = basePatchCommands;
        OverlayCommands = overlayCommands;
        ShoreCommands = shoreCommands;
        FoamCommands = foamCommands;
        WaterRects = waterRects;
    }

    public GodotDictionary ToDictionary()
    {
        return new GodotDictionary
        {
            ["chunk_coord"] = ChunkCoord,
            ["chunk_size"] = ChunkSize,
            ["tile_size"] = TileSize,
            ["base_visuals"] = BaseVisuals,
            ["base_cycles"] = BaseCycles,
            ["base_patch_commands"] = BasePatchCommands,
            ["overlay_commands"] = OverlayCommands,
            ["shore_commands"] = ShoreCommands,
            ["foam_commands"] = FoamCommands,
            ["water_rects"] = WaterRects
        };
    }
}
