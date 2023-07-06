using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// //SSAO 的一些设置
// [Serializable]
// public class ScreenSpaceAmbientOcclusionSettings
// {
//     // Parameters
//     [SerializeField] internal bool Downsample = false;
//     [SerializeField] internal DepthSource Source = DepthSource.DepthNormals;
//     [SerializeField] internal NormalQuality NormalSamples = NormalQuality.Medium;
//     [SerializeField] internal float Intensity = 3.0f;
//     [SerializeField] internal float DirectLightingStrength = 0.25f;
//     [SerializeField] internal float Radius = 0.035f;
//     [SerializeField] internal int SampleCount = 6;
//     [SerializeField] internal RenderPassEvent _renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
//
//     // Enums
//     internal enum DepthSource
//     {
//         Depth = 0,
//         DepthNormals = 1,
//         //GBuffer = 2
//     }
//
//     internal enum NormalQuality
//     {
//         Low,
//         Medium,
//         High
//     }
// }

[DisallowMultipleRendererFeature]
public class MySSAOFeature : ScriptableRendererFeature
{
    // Serialized Fields
    [SerializeField, HideInInspector] private Shader m_Shader = null;

    [SerializeField] private ScreenSpaceAmbientOcclusionSettings m_Settings = new ScreenSpaceAmbientOcclusionSettings();


    // Private Fields
    [SerializeField] private Material m_Material;
    
    [SerializeField] [Range(0,1)]private float BilaterFilterFactor; //法线判定的插值
   [SerializeField] private Vector2 BlurRadius; //滤波的采样范围
    
    private MySSAOPass m_SSAOPass = null;
    private const string k_ShaderName = "Hidden/Universal Render Pipeline/ScreenSpaceAmbientOcclusion";

    ///这个类被管线创建时调用
    /// <inheritdoc/>
    public override void Create()
    {
        // Create the pass...
        if (m_SSAOPass == null)
        {
            m_SSAOPass = new MySSAOPass();
        }

        GetMaterial();
        m_SSAOPass.profilerTag = name;
        m_SSAOPass.BlurRadius = BlurRadius;
        m_SSAOPass.BilaterFilterFactor = BilaterFilterFactor;
    }

    /// <inheritdoc/>
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (!GetMaterial())
        {
            Debug.LogErrorFormat(
                "{0}.AddRenderPasses(): Missing material. {1} render pass will not be added. Check for missing reference in the renderer resources.",
                GetType().Name, m_SSAOPass.profilerTag);
            return;
        }
        
        bool shouldAdd = m_SSAOPass.Setup(m_Settings);
        if (shouldAdd)
        {
            if (m_SSAOPass != null)
            {
                m_SSAOPass.SetCamRT = renderer.cameraColorTarget;
            }

            renderer.EnqueuePass(m_SSAOPass);
        }
    }

    // /// <inheritdoc/>
    // protected override void Dispose(bool disposing)
    // {
    //     CoreUtils.Destroy(m_Material);
    // }

    private bool GetMaterial()
    {
        if (m_Material != null)
        {
            m_SSAOPass.material = m_Material;
            return true;
        }

        if (m_Shader == null)
        {
            m_Shader = Shader.Find(k_ShaderName);
            if (m_Shader == null)
            {
                return false;
            }
        }

        m_Material = CoreUtils.CreateEngineMaterial(m_Shader);
        m_SSAOPass.material = m_Material;
        return m_Material != null;
    }
}