//SSAO 的一些设置

using System;
using UnityEngine;
using UnityEngine.Rendering.Universal;

[Serializable]
public class ScreenSpaceAmbientOcclusionSettings
{
    // Parameters
    [SerializeField] internal bool Downsample = false;
    [SerializeField] internal DepthSource Source = DepthSource.DepthNormals;
    [SerializeField] internal NormalQuality NormalSamples = NormalQuality.Medium;
    [SerializeField] internal float Intensity = 3.0f;
    [SerializeField] [Range(0,1)]internal float DirectLightingStrength = 0.25f;//与原图叠加的强度
    [SerializeField] internal float Radius = 0.035f;
    [SerializeField] internal float RangeStrength = 0;
    [SerializeField] [Range(0,20)]internal int SampleCount = 6;
    [SerializeField] internal RenderPassEvent _renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    [SerializeField] private Texture m_NoiseTex;

    internal Texture noiseMap
    {
        get
        {
            if (m_NoiseTex==null)
            {
                return Texture2D.grayTexture;
            }

            return m_NoiseTex;
        }
    } 

    // Enums
    internal enum DepthSource
    {
        Depth = 0,
        DepthNormals = 1,
        //GBuffer = 2
    }

    internal enum NormalQuality
    {
        Low,
        Medium,
        High
    }
}