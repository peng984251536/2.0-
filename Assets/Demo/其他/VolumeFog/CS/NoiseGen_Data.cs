using System.Collections.Generic;
using Unity.Mathematics;
using UnityEditor;
using UnityEngine;
using UnityEngine.Experimental.Rendering;


// public class NoiseGen_Data : ScriptableObject
// {
//     public ComputeShader worleyCS;
//
//     internal enum NoiseType
//     {
//         PerlinWorley,
//         Worley,
//         Perlin
//     }
//
//     static string NoiseTypeToKernelName(NoiseType noiseType)
//     {
//         switch (noiseType)
//         {
//             case NoiseType.PerlinWorley:
//                 return "PerlinWorleyNoiseEvaluator";
//             case NoiseType.Worley:
//                 return "WorleyNoiseEvaluator";
//             case NoiseType.Perlin:
//                 return "PerlinNoiseEvaluator";
//         }
//
//         return "";
//     }
//
//     /// <summary>
//     /// 生成一个3D纹理
//     /// </summary>
//     /// <param name="width"></param>
//     /// <param name="height"></param>
//     /// <param name="depth"></param>
//     /// <param name="noiseType"></param>
//     /// <returns></returns>
//     [MenuItem("CreateExamples/3DTexture")]
//     private Texture3D GenerateWorleyfBm(int width, NoiseType noiseType)
//     {
//         // Load our compute shader
//         if (worleyCS == null)
//             return null;
//
//         // 配置纹理
//         int size = width;
//         TextureFormat format = TextureFormat.RGBA32; //压缩格式
//         TextureWrapMode wrapMode = TextureWrapMode.Clamp;
//         // 创建纹理并应用配置
//         Texture3D texture = new Texture3D(size, size, size, format, false);
//         texture.wrapMode = wrapMode;
//         // 创建 3 维数组以存储颜色数据
//         Color[] colors = new Color[size * size * size];
//         // 填充数组，使纹理的 x、y 和 z 值映射为红色、蓝色和绿色
//         float inverseResolution = 1.0f / (size - 1.0f);
//         for (int z = 0; z < size; z++)
//         {
//             int zOffset = z * size * size;
//             for (int y = 0; y < size; y++)
//             {
//                 int yOffset = y * size;
//                 for (int x = 0; x < size; x++)
//                 {
//                     //todo - 设置颜色
//                     colors[x + yOffset + zOffset] = new Color(x * inverseResolution,
//                         y * inverseResolution, z * inverseResolution, 1.0f);
//                 }
//             }
//         }
//
//         // 将颜色值复制到纹理
//         texture.SetPixels(colors);
//         // 将更改应用到纹理，然后将更新的纹理上传到 GPU
//         texture.Apply();
//
//         return texture;
//     }
//
//
//     public void UpdateNoise()
//     {
//         ValidateParamaters();
//         CreateTexture(ref shapeTexture, shapeResolution, shapeNoiseName);
//         CreateTexture(ref detailTexture, detailResolution, detailNoiseName);
//
//         if (updateNoise && noiseCompute)
//         {
//             var timer = System.Diagnostics.Stopwatch.StartNew();
//
//             updateNoise = false;
//             WorleyNoiseSettings activeSettings = ActiveSettings;
//             if (activeSettings == null)
//             {
//                 return;
//             }
//
//             buffersToRelease = new List<ComputeBuffer>();
//
//             int activeTextureResolution = ActiveTexture.width;
//
//             // Set values:
//             noiseCompute.SetFloat("persistence", activeSettings.persistence);
//             noiseCompute.SetInt("resolution", activeTextureResolution);
//             noiseCompute.SetVector("channelMask", ChannelMask);
//
//             // Set noise gen kernel data:
//             noiseCompute.SetTexture(0, "Result", ActiveTexture);
//             var minMaxBuffer = CreateBuffer(new int[] { int.MaxValue, 0 }, sizeof(int), "minMax", 0);
//             UpdateWorley(ActiveSettings);
//             noiseCompute.SetTexture(0, "Result", ActiveTexture);
//             //var noiseValuesBuffer = CreateBuffer (activeNoiseValues, sizeof (float) * 4, "values");
//
//             // Dispatch noise gen kernel
//             int numThreadGroups = Mathf.CeilToInt(activeTextureResolution / (float)computeThreadGroupSize);
//             noiseCompute.Dispatch(0, numThreadGroups, numThreadGroups, numThreadGroups);
//
//             // Set normalization kernel data:
//             noiseCompute.SetBuffer(1, "minMax", minMaxBuffer);
//             noiseCompute.SetTexture(1, "Result", ActiveTexture);
//             // Dispatch normalization kernel
//             noiseCompute.Dispatch(1, numThreadGroups, numThreadGroups, numThreadGroups);
//
//             if (logComputeTime)
//             {
//                 // Get minmax data just to force main thread to wait until compute shaders are finished.
//                 // This allows us to measure the execution time.
//                 var minMax = new int[2];
//                 minMaxBuffer.GetData(minMax);
//
//                 Debug.Log($"Noise Generation: {timer.ElapsedMilliseconds}ms");
//             }
//
//             // Release buffers
//             foreach (var buffer in buffersToRelease)
//             {
//                 buffer.Release();
//             }
//         }
//     }
//
//     void ValidateParamaters()
//     {
//         detailResolution = Mathf.Max(1, detailResolution);
//         shapeResolution = Mathf.Max(1, shapeResolution);
//     }
// }