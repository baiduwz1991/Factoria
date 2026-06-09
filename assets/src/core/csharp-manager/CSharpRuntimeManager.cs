using Godot;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

public partial class CSharpRuntimeManager : Node
{
    private readonly object _terrainJobsLock = new();
    private readonly Dictionary<string, TerrainVisualJob> _terrainJobs = new();
    private readonly ConcurrentQueue<TerrainVisualJobResult> _terrainResults = new();

    public override void _ExitTree()
    {
        CancelAllTerrainVisualJobs();
    }

    public bool StartTerrainVisualJob(
        string key,
        Vector2I chunkCoord,
        int chunkSize,
        int tileSize,
        int[] terrainSnapshot,
        int[] chunkTiles
    )
    {
        if (string.IsNullOrEmpty(key))
            return false;

        int[] snapshotCopy = terrainSnapshot != null
            ? (int[])terrainSnapshot.Clone()
            : Array.Empty<int>();
        int[] chunkTilesCopy = chunkTiles != null
            ? (int[])chunkTiles.Clone()
            : Array.Empty<int>();
        var job = new TerrainVisualJob(key);

        lock (_terrainJobsLock)
        {
            if (_terrainJobs.ContainsKey(key))
                return false;
            _terrainJobs[key] = job;
        }

        _ = Task.Run(() => RunTerrainVisualJob(
            job,
            chunkCoord,
            chunkSize,
            tileSize,
            snapshotCopy,
            chunkTilesCopy
        ));
        return true;
    }

    public void CancelTerrainVisualJob(string key)
    {
        if (string.IsNullOrEmpty(key))
            return;

        TerrainVisualJob job = null;
        lock (_terrainJobsLock)
        {
            _terrainJobs.TryGetValue(key, out job);
        }
        job?.Cancel();
    }

    public void CancelAllTerrainVisualJobs()
    {
        List<TerrainVisualJob> jobs;
        lock (_terrainJobsLock)
        {
            jobs = new List<TerrainVisualJob>(_terrainJobs.Values);
            _terrainJobs.Clear();
        }

        foreach (TerrainVisualJob job in jobs)
        {
            job.SuppressResult = true;
            job.Cancel();
        }

        while (_terrainResults.TryDequeue(out _))
        {
        }
    }

    public GodotArray DrainTerrainVisualResults(int maxResults)
    {
        int safeMaxResults = maxResults <= 0 ? int.MaxValue : maxResults;
        var drained = new GodotArray();
        for (int index = 0; index < safeMaxResults; index++)
        {
            if (!_terrainResults.TryDequeue(out TerrainVisualJobResult result))
                break;

            var resultData = new GodotDictionary
            {
                ["key"] = result.Key,
                ["cancelled"] = result.Cancelled
            };
            if (result.VisualData != null)
                resultData["visual_data"] = result.VisualData.ToDictionary();
            if (!string.IsNullOrEmpty(result.ErrorMessage))
                resultData["error_message"] = result.ErrorMessage;
            drained.Add(resultData);
        }
        return drained;
    }

    public Node2D CreateTerrainChunkCanvas(GodotDictionary visualData)
    {
        var canvas = new TerrainChunkCanvas();
        canvas.Configure(visualData);
        return canvas;
    }

    private void RunTerrainVisualJob(
        TerrainVisualJob job,
        Vector2I chunkCoord,
        int chunkSize,
        int tileSize,
        int[] terrainSnapshot,
        int[] chunkTiles
    )
    {
        try
        {
            TerrainChunkVisualData visualData = new TerrainRuntime().BuildChunkVisualData(
                chunkCoord,
                chunkSize,
                tileSize,
                terrainSnapshot,
                chunkTiles,
                job.CancellationToken
            );
            EnqueueTerrainResult(job, TerrainVisualJobResult.Completed(job.Key, visualData));
        }
        catch (OperationCanceledException)
        {
            EnqueueTerrainResult(job, TerrainVisualJobResult.CreateCancelled(job.Key));
        }
        catch (Exception exception)
        {
            EnqueueTerrainResult(job, TerrainVisualJobResult.Failed(job.Key, exception.Message));
        }
        finally
        {
            lock (_terrainJobsLock)
            {
                if (_terrainJobs.TryGetValue(job.Key, out TerrainVisualJob currentJob) && ReferenceEquals(currentJob, job))
                    _terrainJobs.Remove(job.Key);
            }
            job.Dispose();
        }
    }

    private void EnqueueTerrainResult(TerrainVisualJob job, TerrainVisualJobResult result)
    {
        if (job.SuppressResult)
            return;
        _terrainResults.Enqueue(result);
    }

    private sealed class TerrainVisualJob : IDisposable
    {
        private readonly CancellationTokenSource _cancellationTokenSource = new();

        public string Key { get; }
        public bool SuppressResult { get; set; }
        public CancellationToken CancellationToken => _cancellationTokenSource.Token;

        public TerrainVisualJob(string key)
        {
            Key = key;
        }

        public void Cancel()
        {
            _cancellationTokenSource.Cancel();
        }

        public void Dispose()
        {
            _cancellationTokenSource.Dispose();
        }
    }

    private sealed class TerrainVisualJobResult
    {
        public string Key { get; }
        public TerrainChunkVisualData VisualData { get; }
        public bool Cancelled { get; }
        public string ErrorMessage { get; }

        private TerrainVisualJobResult(
            string key,
            TerrainChunkVisualData visualData,
            bool cancelled,
            string errorMessage
        )
        {
            Key = key;
            VisualData = visualData;
            Cancelled = cancelled;
            ErrorMessage = errorMessage;
        }

        public static TerrainVisualJobResult Completed(string key, TerrainChunkVisualData visualData)
        {
            return new TerrainVisualJobResult(key, visualData, false, string.Empty);
        }

        public static TerrainVisualJobResult CreateCancelled(string key)
        {
            return new TerrainVisualJobResult(key, null, true, string.Empty);
        }

        public static TerrainVisualJobResult Failed(string key, string errorMessage)
        {
            return new TerrainVisualJobResult(key, null, false, errorMessage);
        }
    }
}
