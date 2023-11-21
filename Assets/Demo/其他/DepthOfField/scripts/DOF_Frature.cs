using System;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal.Internal;
using UnityEngine.Scripting.APIUpdating;
using UnityEngine.Serialization;


[ExcludeFromPreset]
[MovedFrom("UnityEngine.Experimental.Rendering.LWRP")]
public class DOF_Frature : ScriptableRendererFeature
{


    private DOF_Pass pass;
    private const string k_IsImportanceSampling = "_IMPORTANCE_SAMPLING";
    private const string k_IsMulitSampling = "_MULIT_SAMPLING";
    private const string k_IsPatioFilter = "_PATIO_FILTER";
    private const string k_BRDFSSR = "_BRDFSSR";

    public RenderPassEvent m_RenderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    [HideInInspector]
    public Shader dofShader;
    
    
    private Material dofMaterial;
    private DOFVolume m_dofVolume = null;
    

    public Vector4 DebugParams = Vector4.zero;
    


    public override void Create()
    {
        if(dofMaterial==null)
            dofMaterial = new Material(dofShader);
        dofMaterial.hideFlags = HideFlags.HideAndDontSave;
        if (pass == null)
            pass = new DOF_Pass(name, dofMaterial);
    }

    protected override void Dispose(bool disposing)
    {
        //_temporalMgr = null;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if(m_dofVolume==null)
        {
            m_dofVolume = VolumeManager.instance.stack.GetComponent<DOFVolume>();
            if(m_dofVolume==null)
                return;
        }
        
        if(!m_dofVolume.IsActive())
            return;
        if(m_dofVolume.intensity.value<=0.01f)
            return;
        if(m_dofVolume._FocusRadius.value<=0.01f)
            return;
        
        
        if (pass == null)
            return;
        pass.SetUp(m_RenderPassEvent);
        renderer.EnqueuePass(pass);

        if (dofMaterial == null)
            return;
        dofMaterial.SetFloat("_FocusDistance",m_dofVolume._FocusDistance.value);
        dofMaterial.SetFloat("_FocusRange",m_dofVolume._FocusRange.value);
        dofMaterial.SetFloat("_FocusRadius",m_dofVolume._FocusRadius.value);
        dofMaterial.SetFloat("_FocusIntensity",m_dofVolume.intensity.value);


        //     ssr_mat.SetFloat("_BRDFBias", _RayMarchSettings._BRDFBias);
    //     ssr_mat.SetFloat("_EdgeFactor", _RayMarchSettings._EdgeFactor);
    //     ssr_mat.SetTexture("_NoiseTex", _RayMarchSettings._NoiseTex);
    //     ssr_mat.SetVector("_NoiseSize", _RayMarchSettings._NoiseSize);
    //     ssr_mat.SetFloat("_downsampleDivider", _RayMarchSettings._downsampleDivider);
    //
    //
    //     Vector4 rayParams = new Vector4
    //     (
    //         _RayMarchSettings._rayStepNum,
    //         _RayMarchSettings._rayStepScale,
    //         _RayMarchSettings._thickness,
    //         0
    //     );
    //     ssr_mat.SetVector("_rayParams", rayParams);
    //     Vector4 jitterParams = new Vector4
    //     (
    //         _RayMarchSettings._NoiseSize.x,
    //         _RayMarchSettings._NoiseSize.y,
    //         _temporalMgr.GetHaltonVector2().x,
    //         _temporalMgr.GetHaltonVector2().y
    //     );
    //     ssr_mat.SetVector("_JitterSizeAndOffset", jitterParams);
    //     ssr_mat.SetVector("_DebugParams", DebugParams);
    //
    //     float _Fireflies = _RayMarchSettings.Fireflies ? 1 : 0;
    //     ssr_mat.SetFloat("_Fireflies", _Fireflies);
    //     CoreUtils.SetKeyword(ssr_mat, k_IsImportanceSampling,
    //         _RayMarchSettings.IsImportanceSampling);
    //     CoreUtils.SetKeyword(ssr_mat, k_IsMulitSampling,
    //         _RayMarchSettings.IsMulitSampling);
    //     CoreUtils.SetKeyword(ssr_mat, k_IsPatioFilter,
    //         _RayMarchSettings.IsPatioFilter);
    //     CoreUtils.SetKeyword(ssr_mat, k_BRDFSSR,
    //         _RayMarchSettings.BRDF_SSR);
    }
}