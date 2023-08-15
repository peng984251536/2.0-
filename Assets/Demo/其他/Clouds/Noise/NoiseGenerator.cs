using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class NoiseGenerator : MonoBehaviour {

    const int computeThreadGroupSize = 8;
    public const string detailNoiseName = "DetailNoise";
    public const string shapeNoiseName = "ShapeNoise";

    public enum CloudNoiseType { Shape, Detail }
    public enum TextureChannel { R, G, B, A ,none}

    [Header ("Editor Settings")]
    public CloudNoiseType activeTextureType;
    public TextureChannel activeChannel;
    public bool autoUpdate;
    public bool logComputeTime;

    [Header ("Noise Settings")]
    public int shapeResolution = 132;
    public int detailResolution = 32;

    public WorleyNoiseSettings[] shapeSettings;
    public WorleyNoiseSettings[] detailSettings;
    public ComputeShader noiseCompute;
    public ComputeShader copy;

    [Header ("Viewer Settings")]
    public bool viewerEnabled;
    public bool viewerGreyscale = true;
    public bool viewerShowAllChannels;
    [Range (0, 1)]
    public float viewerSliceDepth;
    [Range (1, 5)]
    public float viewerTileAmount = 1;
    [Range (0, 1)]
    public float viewerSize = 1;

    // Internal
    List<ComputeBuffer> buffersToRelease;
    bool updateNoise;

    [HideInInspector]
    public bool showSettingsEditor = true;
    [SerializeField, HideInInspector]
    public RenderTexture shapeTexture;
    [SerializeField, HideInInspector]
    public RenderTexture detailTexture;

    /// <summary>
    /// 更新噪点贴图，主要在修改参数后触发
    /// </summary>
    public void UpdateNoise () {
        ValidateParamaters ();
        CreateTexture (ref shapeTexture, shapeResolution, shapeNoiseName);
        CreateTexture (ref detailTexture, detailResolution, detailNoiseName);

        //上诉开启更新后这里更新cs的信息
        if (updateNoise && noiseCompute) {
            var timer = System.Diagnostics.Stopwatch.StartNew ();

            updateNoise = false;
            WorleyNoiseSettings activeSettings = ActiveSettings;//拿到配置信息
            if (activeSettings == null) {
                return;
            }

            buffersToRelease = new List<ComputeBuffer> ();

            int activeTextureResolution = ActiveTexture.width;

            // Set values:
            noiseCompute.SetFloat ("persistence", activeSettings.persistence);
            noiseCompute.SetInt ("resolution", activeTextureResolution);
            noiseCompute.SetVector ("channelMask", ChannelMask);

            // Set noise gen kernel data:
            noiseCompute.SetTexture (0, "Result", ActiveTexture);
            var minMaxBuffer = CreateBuffer (new int[] { int.MaxValue, 0 }, sizeof (int), "minMax", 0);
            UpdateWorley (ActiveSettings);
            noiseCompute.SetTexture (0, "Result", ActiveTexture);
            //var noiseValuesBuffer = CreateBuffer (activeNoiseValues, sizeof (float) * 4, "values");

            // Dispatch noise gen kernel
            //生成Worley噪点 到 3D噪点图 
            //创建采样数
            int numThreadGroups = Mathf.CeilToInt (activeTextureResolution / (float) computeThreadGroupSize);
            //启动内核0
            noiseCompute.Dispatch (0, numThreadGroups, numThreadGroups, numThreadGroups);

            // Set normalization kernel data:
            noiseCompute.SetBuffer (1, "minMax", minMaxBuffer);
            noiseCompute.SetTexture (1, "Result", ActiveTexture);
            // Dispatch normalization kernel
            //启动内核1
            noiseCompute.Dispatch (1, numThreadGroups, numThreadGroups, numThreadGroups);

            if (logComputeTime) {
                // Get minmax data just to force main thread to wait until compute shaders are finished.
                // This allows us to measure the execution time.
                var minMax = new int[2];
                minMaxBuffer.GetData (minMax);
                
                Debug.Log ($"Noise Generation: {timer.ElapsedMilliseconds}ms");
            }

            // Release buffers
            foreach (var buffer in buffersToRelease) {
                buffer.Release ();
            }
        }
    }

    /// <summary>
    /// 用于
    /// </summary>
    /// <param name="saveName"></param>
    /// <param name="target"></param>
    public void Load (string saveName, RenderTexture target) {
        string sceneName = UnityEngine.SceneManagement.SceneManager.GetActiveScene ().name;
        saveName = sceneName + "_" + saveName;
        Texture3D savedTex = (Texture3D) Resources.Load (saveName);
        if (savedTex != null && savedTex.width == target.width) {
            copy.SetTexture (0, "tex", savedTex);
            copy.SetTexture (0, "renderTex", target);
            int numThreadGroups = Mathf.CeilToInt (savedTex.width / 8f);
            copy.Dispatch (0, numThreadGroups, numThreadGroups, numThreadGroups);
        }
    }

    public RenderTexture ActiveTexture {
        get {
            return (activeTextureType == CloudNoiseType.Shape) ? shapeTexture : detailTexture;
        }
    }

    /// <summary>
    /// 这里挑选设置的参数，但是默认是空的
    /// </summary>
    public WorleyNoiseSettings ActiveSettings {
        get {
            WorleyNoiseSettings[] settings = (activeTextureType == CloudNoiseType.Shape) ? shapeSettings : detailSettings;
            int activeChannelIndex = (int) activeChannel;
            if (activeChannelIndex >= settings.Length) {
                return null;
            }
            return settings[activeChannelIndex];
        }
    }

    public Vector4 ChannelMask {
        get {
            Vector4 channelWeight = new Vector4 (
                (activeChannel == NoiseGenerator.TextureChannel.R) ? 1 : 0,
                (activeChannel == NoiseGenerator.TextureChannel.G) ? 1 : 0,
                (activeChannel == NoiseGenerator.TextureChannel.B) ? 1 : 0,
                (activeChannel == NoiseGenerator.TextureChannel.A) ? 1 : 0
            );
            return channelWeight;
        }
    }

    /// <summary>
    /// 更新CS里面的一个参数
    /// </summary>
    /// <param name="settings"></param>
    void UpdateWorley (WorleyNoiseSettings settings) {
        var prng = new System.Random (settings.seed);
        CreateWorleyPointsBuffer (prng, settings.numDivisionsA, "pointsA");
        CreateWorleyPointsBuffer (prng, settings.numDivisionsB, "pointsB");
        CreateWorleyPointsBuffer (prng, settings.numDivisionsC, "pointsC");

        noiseCompute.SetInt ("numCellsA", settings.numDivisionsA);
        noiseCompute.SetInt ("numCellsB", settings.numDivisionsB);
        noiseCompute.SetInt ("numCellsC", settings.numDivisionsC);
        noiseCompute.SetBool ("invertNoise", settings.invert);
        noiseCompute.SetInt ("tile", settings.tile);

    }

    void CreateWorleyPointsBuffer (System.Random prng, int numCellsPerAxis, string bufferName) {
        var points = new Vector3[numCellsPerAxis * numCellsPerAxis * numCellsPerAxis];
        float cellSize = 1f / numCellsPerAxis;

        for (int x = 0; x < numCellsPerAxis; x++) {
            for (int y = 0; y < numCellsPerAxis; y++) {
                for (int z = 0; z < numCellsPerAxis; z++) {
                    float randomX = (float) prng.NextDouble ();
                    float randomY = (float) prng.NextDouble ();
                    float randomZ = (float) prng.NextDouble ();
                    Vector3 randomOffset = new Vector3 (randomX, randomY, randomZ) * cellSize;
                    Vector3 cellCorner = new Vector3 (x, y, z) * cellSize;

                    int index = x + numCellsPerAxis * (y + z * numCellsPerAxis);
                    points[index] = cellCorner + randomOffset;
                }
            }
        }

        CreateBuffer (points, sizeof (float) * 3, bufferName);
    }

    // Create buffer with some data, and set in shader. Also add to list of buffers to be released
    /// <summary>
    /// buffersToRelease 重置
    /// </summary>
    /// <param name="data"></param>
    /// <param name="stride"></param>
    /// <param name="bufferName"></param>
    /// <param name="kernel"></param>
    /// <returns></returns>
    ComputeBuffer CreateBuffer (System.Array data, int stride, string bufferName, int kernel = 0) {
        var buffer = new ComputeBuffer (data.Length, stride, ComputeBufferType.Structured);
        buffersToRelease.Add (buffer);
        buffer.SetData (data);
        noiseCompute.SetBuffer (kernel, bufferName, buffer);
        return buffer;
    }

    void CreateTexture (ref RenderTexture texture, int resolution, string name) {
        var format = UnityEngine.Experimental.Rendering.GraphicsFormat.R16G16B16A16_UNorm;
        if (texture == null || !texture.IsCreated () || texture.width != resolution || texture.height != resolution || texture.volumeDepth != resolution || texture.graphicsFormat != format) {
            //Debug.Log ("Create tex: update noise: " + updateNoise);
            if (texture != null) {
                texture.Release ();
            }
            texture = new RenderTexture (resolution, resolution, 0);
            texture.graphicsFormat = format;
            texture.volumeDepth = resolution;
            texture.enableRandomWrite = true;
            texture.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
            texture.name = name;

            texture.Create ();
            Load (name, texture);
        }
        texture.wrapMode = TextureWrapMode.Repeat;
        texture.filterMode = FilterMode.Bilinear;
    }

    public void ManualUpdate () {
        updateNoise = true;
        UpdateNoise ();
    }

    void OnValidate () { }

    public void ActiveNoiseSettingsChanged () {
        if (autoUpdate) {
            updateNoise = true;
        }
    }

    /// <summary>
    /// 保证detailResolution和shapeResolution大于1
    /// </summary>
    void ValidateParamaters () {
        detailResolution = Mathf.Max (1, detailResolution);
        shapeResolution = Mathf.Max (1, shapeResolution);
    }
}