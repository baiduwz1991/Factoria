using Godot;
using System.Collections.Generic;
using System.Threading;

public sealed class TerrainRuntime
{
    private const int CycleSize = 4;
    private const int CommandStride = 5;
    private const int NotPureVisual = -1;
    private const int WaterRectStride = 4;

    private readonly TerrainVisualSpec _visualSpec;

    public TerrainRuntime(TerrainVisualSpec visualSpec = null)
    {
        _visualSpec = visualSpec ?? TerrainVisualSpec.CreateDefault();
    }

    public TerrainChunkVisualData BuildChunkVisualData(
        Vector2I chunkCoord,
        int chunkSize,
        int tileSize,
        int[] terrainSnapshot,
        int[] chunkTiles,
        CancellationToken cancellationToken = default
    )
    {
        int safeChunkSize = System.Math.Max(chunkSize, 1);
        int safeTileSize = System.Math.Max(tileSize, 1);
        int tileCount = safeChunkSize * safeChunkSize;
        int snapshotWidth = safeChunkSize + 1;

        int[] baseVisuals = new int[tileCount];
        int[] baseCycles = new int[tileCount];
        int[] pureVisuals = new int[tileCount];
        System.Array.Fill(pureVisuals, NotPureVisual);

        var overlayCommands = new List<DrawCommand>();
        var shoreCommands = new List<DrawCommand>();
        var foamCommands = new List<DrawCommand>();

        for (int localY = 0; localY < safeChunkSize; localY++)
        {
            cancellationToken.ThrowIfCancellationRequested();
            for (int localX = 0; localX < safeChunkSize; localX++)
            {
                int topLeft = VisualFromTerrain(SampleSnapshot(terrainSnapshot, snapshotWidth, localX, localY));
                int topRight = VisualFromTerrain(SampleSnapshot(terrainSnapshot, snapshotWidth, localX + 1, localY));
                int bottomLeft = VisualFromTerrain(SampleSnapshot(terrainSnapshot, snapshotWidth, localX, localY + 1));
                int bottomRight = VisualFromTerrain(SampleSnapshot(terrainSnapshot, snapshotWidth, localX + 1, localY + 1));

                int[] corners = { topLeft, topRight, bottomLeft, bottomRight };
                int cycle = GetCycleIndex(chunkCoord, safeChunkSize, localX, localY);
                int baseVisual = GetLowestPriorityVisual(corners);
                int index = localY * safeChunkSize + localX;
                baseVisuals[index] = baseVisual;
                baseCycles[index] = cycle;
                if (IsPureVisualCell(corners))
                    pureVisuals[index] = topLeft;

                bool hasWater = false;
                bool hasLand = false;
                for (int cornerIndex = 0; cornerIndex < corners.Length; cornerIndex++)
                {
                    if (IsWaterVisual(corners[cornerIndex]))
                        hasWater = true;
                    else
                        hasLand = true;
                }

                AddOverlayCommands(overlayCommands, localX, localY, cycle, baseVisual, corners);
                if (hasWater && hasLand)
                    AddWaterEdgeCommands(shoreCommands, foamCommands, localX, localY, cycle, corners);
            }
        }

        overlayCommands.Sort(CompareDrawCommands);
        shoreCommands.Sort(CompareDrawCommands);

        return new TerrainChunkVisualData(
            chunkCoord,
            safeChunkSize,
            safeTileSize,
            baseVisuals,
            baseCycles,
            BuildBasePatchCommands(chunkCoord, safeChunkSize, pureVisuals, cancellationToken),
            FlattenDrawCommands(overlayCommands),
            FlattenDrawCommands(shoreCommands),
            FlattenDrawCommands(foamCommands),
            BuildWaterRects(chunkTiles, safeChunkSize, cancellationToken)
        );
    }

    private int SampleSnapshot(int[] snapshot, int snapshotWidth, int x, int y)
    {
        int index = y * snapshotWidth + x;
        if (index < 0 || index >= snapshot.Length)
            return _visualSpec.DefaultRuntimeId;
        return snapshot[index];
    }

    private int VisualFromTerrain(int terrainId)
    {
        return _visualSpec.GetVisualIndexForTerrain(terrainId);
    }

    private static int GetCycleIndex(Vector2I chunkCoord, int chunkSize, int localX, int localY)
    {
        int globalX = chunkCoord.X * chunkSize + localX;
        int globalY = chunkCoord.Y * chunkSize + localY;
        int cycleX = PosMod(globalX, CycleSize);
        int cycleY = PosMod(globalY, CycleSize);
        return cycleY * CycleSize + cycleX;
    }

    private int GetLowestPriorityVisual(int[] corners)
    {
        int bestVisual = corners[0];
        int bestPriority = VisualPriority(bestVisual);
        for (int index = 1; index < corners.Length; index++)
        {
            int priority = VisualPriority(corners[index]);
            if (priority < bestPriority)
            {
                bestPriority = priority;
                bestVisual = corners[index];
            }
        }
        return bestVisual;
    }

    private static bool IsPureVisualCell(int[] corners)
    {
        int visual = corners[0];
        for (int index = 1; index < corners.Length; index++)
        {
            if (corners[index] != visual)
                return false;
        }
        return true;
    }

    private int[] BuildBasePatchCommands(
        Vector2I chunkCoord,
        int chunkSize,
        int[] pureVisuals,
        CancellationToken cancellationToken
    )
    {
        var commands = new List<PatchCommand>();
        bool[] covered = new bool[chunkSize * chunkSize];
        AddBasePatchCommands(commands, covered, chunkCoord, chunkSize, pureVisuals, 4, cancellationToken);
        AddBasePatchCommands(commands, covered, chunkCoord, chunkSize, pureVisuals, 2, cancellationToken);
        return FlattenPatchCommands(commands);
    }

    private void AddBasePatchCommands(
        List<PatchCommand> commands,
        bool[] covered,
        Vector2I chunkCoord,
        int chunkSize,
        int[] pureVisuals,
        int patchSize,
        CancellationToken cancellationToken
    )
    {
        for (int localY = 0; localY <= chunkSize - patchSize; localY++)
        {
            cancellationToken.ThrowIfCancellationRequested();
            for (int localX = 0; localX <= chunkSize - patchSize; localX++)
            {
                int globalX = chunkCoord.X * chunkSize + localX;
                int globalY = chunkCoord.Y * chunkSize + localY;
                if (PosMod(globalX, patchSize) != 0 || PosMod(globalY, patchSize) != 0)
                    continue;

                int visual = GetPatchVisual(localX, localY, chunkSize, patchSize, pureVisuals, covered);
                if (visual == NotPureVisual)
                    continue;

                int variant = GetPatchVariantIndex(globalX, globalY, patchSize);

                commands.Add(new PatchCommand(
                    localX,
                    localY,
                    visual,
                    patchSize,
                    variant
                ));
                MarkCovered(localX, localY, chunkSize, patchSize, covered);
            }
        }
    }

    private static int GetPatchVisual(
        int localX,
        int localY,
        int chunkSize,
        int patchSize,
        int[] pureVisuals,
        bool[] covered
    )
    {
        int firstIndex = localY * chunkSize + localX;
        if (firstIndex < 0 || firstIndex >= pureVisuals.Length || covered[firstIndex])
            return NotPureVisual;

        int visual = pureVisuals[firstIndex];
        if (visual == NotPureVisual)
            return NotPureVisual;

        for (int offsetY = 0; offsetY < patchSize; offsetY++)
        {
            for (int offsetX = 0; offsetX < patchSize; offsetX++)
            {
                int index = (localY + offsetY) * chunkSize + localX + offsetX;
                if (index < 0 || index >= pureVisuals.Length || covered[index] || pureVisuals[index] != visual)
                    return NotPureVisual;
            }
        }
        return visual;
    }

    private static void MarkCovered(int localX, int localY, int chunkSize, int patchSize, bool[] covered)
    {
        for (int offsetY = 0; offsetY < patchSize; offsetY++)
        {
            for (int offsetX = 0; offsetX < patchSize; offsetX++)
            {
                int index = (localY + offsetY) * chunkSize + localX + offsetX;
                if (index >= 0 && index < covered.Length)
                    covered[index] = true;
            }
        }
    }

    private static int GetPatchVariantIndex(int globalX, int globalY, int patchSize)
    {
        int cycleX = PosMod(globalX / patchSize, CycleSize);
        int cycleY = PosMod(globalY / patchSize, CycleSize);
        return cycleY * CycleSize + cycleX;
    }

    private static int[] FlattenPatchCommands(List<PatchCommand> commands)
    {
        int[] result = new int[commands.Count * CommandStride];
        int outIndex = 0;
        foreach (PatchCommand command in commands)
        {
            result[outIndex++] = command.LocalX;
            result[outIndex++] = command.LocalY;
            result[outIndex++] = command.Visual;
            result[outIndex++] = command.PatchSize;
            result[outIndex++] = command.Variant;
        }
        return result;
    }

    private void AddOverlayCommands(
        List<DrawCommand> commands,
        int localX,
        int localY,
        int cycle,
        int baseVisual,
        int[] corners
    )
    {
        foreach (int visual in _visualSpec.VisualIndices)
        {
            int mask = BuildMask(corners, visual);
            if (mask == 0 || mask == 15 || visual == baseVisual)
                continue;
            commands.Add(new DrawCommand(localX, localY, visual, mask, cycle));
        }
    }

    private void AddWaterEdgeCommands(
        List<DrawCommand> shoreCommands,
        List<DrawCommand> foamCommands,
        int localX,
        int localY,
        int cycle,
        int[] corners
    )
    {
        int waterMask = 0;
        for (int cornerIndex = 0; cornerIndex < corners.Length; cornerIndex++)
        {
            if (IsWaterVisual(corners[cornerIndex]))
                waterMask |= 1 << cornerIndex;
        }

        if (waterMask != 0 && waterMask != 15)
            foamCommands.Add(new DrawCommand(localX, localY, _visualSpec.FoamVisualIndex, waterMask, cycle));

        foreach (int visual in _visualSpec.LandVisualIndices)
        {
            int landMask = BuildMask(corners, visual);
            if (landMask == 0 || landMask == 15)
                continue;
            shoreCommands.Add(new DrawCommand(localX, localY, visual, landMask, cycle));
        }
    }

    private static int BuildMask(int[] corners, int visual)
    {
        int mask = 0;
        for (int cornerIndex = 0; cornerIndex < corners.Length; cornerIndex++)
        {
            if (corners[cornerIndex] == visual)
                mask |= 1 << cornerIndex;
        }
        return mask;
    }

    private static int[] FlattenDrawCommands(List<DrawCommand> commands)
    {
        int[] result = new int[commands.Count * CommandStride];
        int outIndex = 0;
        foreach (DrawCommand command in commands)
        {
            result[outIndex++] = command.LocalX;
            result[outIndex++] = command.LocalY;
            result[outIndex++] = command.Visual;
            result[outIndex++] = command.Mask;
            result[outIndex++] = command.Cycle;
        }
        return result;
    }

    private int[] BuildWaterRects(int[] chunkTiles, int chunkSize, CancellationToken cancellationToken)
    {
        var rects = new List<WaterRect>();
        var openRects = new Dictionary<string, WaterRect>();

        for (int localY = 0; localY < chunkSize; localY++)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var nextOpenRects = new Dictionary<string, WaterRect>();
            int localX = 0;
            while (localX < chunkSize)
            {
                while (localX < chunkSize && !IsWaterTerrain(SampleTile(chunkTiles, chunkSize, localX, localY)))
                    localX++;
                if (localX >= chunkSize)
                    break;

                int runStartX = localX;
                while (localX < chunkSize && IsWaterTerrain(SampleTile(chunkTiles, chunkSize, localX, localY)))
                    localX++;

                int runWidth = localX - runStartX;
                string runKey = $"{runStartX}:{runWidth}";
                if (openRects.TryGetValue(runKey, out WaterRect previousRect))
                {
                    previousRect.Height += 1;
                    nextOpenRects[runKey] = previousRect;
                }
                else
                {
                    nextOpenRects[runKey] = new WaterRect(runStartX, localY, runWidth, 1);
                }
            }

            foreach (KeyValuePair<string, WaterRect> pair in openRects)
            {
                if (!nextOpenRects.ContainsKey(pair.Key))
                    rects.Add(pair.Value);
            }

            openRects = nextOpenRects;
        }

        foreach (WaterRect rect in openRects.Values)
            rects.Add(rect);

        int[] result = new int[rects.Count * WaterRectStride];
        int outIndex = 0;
        foreach (WaterRect rect in rects)
        {
            result[outIndex++] = rect.X;
            result[outIndex++] = rect.Y;
            result[outIndex++] = rect.Width;
            result[outIndex++] = rect.Height;
        }
        return result;
    }

    private int SampleTile(int[] tiles, int chunkSize, int localX, int localY)
    {
        int index = localY * chunkSize + localX;
        if (index < 0 || index >= tiles.Length)
            return _visualSpec.DefaultRuntimeId;
        return tiles[index];
    }

    private bool IsWaterTerrain(int terrainId)
    {
        return _visualSpec.IsWaterTerrain(terrainId);
    }

    private bool IsWaterVisual(int visual)
    {
        return _visualSpec.IsWaterVisual(visual);
    }

    private int VisualPriority(int visual)
    {
        return _visualSpec.GetVisualPriority(visual);
    }

    private int CompareDrawCommands(DrawCommand left, DrawCommand right)
    {
        int priorityCompare = VisualPriority(left.Visual).CompareTo(VisualPriority(right.Visual));
        if (priorityCompare != 0)
            return priorityCompare;
        int yCompare = left.LocalY.CompareTo(right.LocalY);
        if (yCompare != 0)
            return yCompare;
        return left.LocalX.CompareTo(right.LocalX);
    }

    private static int PosMod(int value, int modulo)
    {
        int result = value % modulo;
        return result < 0 ? result + modulo : result;
    }

    private readonly struct DrawCommand
    {
        public readonly int LocalX;
        public readonly int LocalY;
        public readonly int Visual;
        public readonly int Mask;
        public readonly int Cycle;

        public DrawCommand(int localX, int localY, int visual, int mask, int cycle)
        {
            LocalX = localX;
            LocalY = localY;
            Visual = visual;
            Mask = mask;
            Cycle = cycle;
        }
    }

    private readonly struct PatchCommand
    {
        public readonly int LocalX;
        public readonly int LocalY;
        public readonly int Visual;
        public readonly int PatchSize;
        public readonly int Variant;

        public PatchCommand(int localX, int localY, int visual, int patchSize, int variant)
        {
            LocalX = localX;
            LocalY = localY;
            Visual = visual;
            PatchSize = patchSize;
            Variant = variant;
        }
    }

    private struct WaterRect
    {
        public int X;
        public int Y;
        public int Width;
        public int Height;

        public WaterRect(int x, int y, int width, int height)
        {
            X = x;
            Y = y;
            Width = width;
            Height = height;
        }
    }
}
