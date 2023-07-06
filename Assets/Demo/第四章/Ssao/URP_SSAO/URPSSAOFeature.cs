using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


[DisallowMultipleRendererFeature]
public class URPSSAOFeature : ScriptableRendererFeature
{
    // Serialized Fields
    [SerializeField, HideInInspector] private Shader m_Shader = null;

    [SerializeField] private ScreenSpaceAmbientOcclusionSettings m_Settings = new ScreenSpaceAmbientOcclusionSettings();


    // Private Fields
    [SerializeField]private Material m_Material;
    private URPSSAOPass m_SSAOPass = null;
    private const string k_ShaderName = "Hidden/Universal Render Pipeline/ScreenSpaceAmbientOcclusion";

    ///这个类被管线创建时调用
    /// <inheritdoc/>
    public override void Create()
    {
        // Create the pass...
        if (m_SSAOPass == null)
        {
            m_SSAOPass = new URPSSAOPass();
        }

        GetMaterial();
        m_SSAOPass.profilerTag = name;
        m_SSAOPass.renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
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
            renderer.EnqueuePass(m_SSAOPass);
        }
    }

    /// <inheritdoc/>
    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(m_Material);
    }

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