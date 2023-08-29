using System;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Scripting.APIUpdating;
using UnityEngine.Serialization;


[ExcludeFromPreset]
[MovedFrom("UnityEngine.Experimental.Rendering.LWRP")]
public class SSRFrature : ScriptableRendererFeature
{
    [System.Serializable]
    public class rayMarchSettings
    {
        [Range(1, 5)] public float _downsampleDivider = 1.0f;
        public Texture2D _NoiseTex;
        public Vector2 _NoiseSize = new Vector2(1, 1);

        [Range(0,1)]
        public float _BRDFBias = 0.7f;
        [Range(0.0f, 1.0f)]
        public float _EdgeFactor = 0.25f;
        public int _rayStepNum = 10;
        public float _rayStepScale = 1.0f;
        public float _thickness = 0.1f;
        public bool IsImportanceSampling = true;
        public bool IsMulitSampling = true;
        public bool IsPatioFilter = true;
        public bool BRDF_SSR = true;
    }


    private SSRPass pass;
    private const string k_IsImportanceSampling = "_IMPORTANCE_SAMPLING";
    private const string k_IsMulitSampling = "_MULIT_SAMPLING";
    private const string k_IsPatioFilter = "_PATIO_FILTER";
    private const string k_BRDFSSR = "_BRDFSSR";
    
    public Material ssr_mat;
    public rayMarchSettings _RayMarchSettings = new rayMarchSettings();
    public TemporalMgr _temporalMgr = new TemporalMgr();
    public Vector4 DebugParams = Vector4.zero;

    //[Header("--------------")] 
    


    public override void Create()
    {
        // if (_noiseSettings.VolemeFog_Shader != null&&volemeFog != null)
        //     volemeFog = new Material(_noiseSettings.VolemeFog_Shader);
        if (pass == null)
            pass = new SSRPass(name, _temporalMgr, ssr_mat);
    }

    protected override void Dispose(bool disposing)
    {
        //_temporalMgr = null;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (pass == null)
            return;
        renderer.EnqueuePass(pass);
        pass.downsampleDivider = _RayMarchSettings._downsampleDivider;

        if (ssr_mat == null)
            return;
        ssr_mat.SetFloat("_BRDFBias",_RayMarchSettings._BRDFBias);
        ssr_mat.SetFloat("_EdgeFactor",_RayMarchSettings._EdgeFactor);
        ssr_mat.SetTexture("_NoiseTex",_RayMarchSettings._NoiseTex);
        ssr_mat.SetVector("_NoiseSize",_RayMarchSettings._NoiseSize);
        ssr_mat.SetFloat("_downsampleDivider",_RayMarchSettings._downsampleDivider);


        Vector4 rayParams = new Vector4
        (
            _RayMarchSettings._rayStepNum,
            _RayMarchSettings._rayStepScale,
            _RayMarchSettings._thickness,
            0
        );
        ssr_mat.SetVector("_rayParams", rayParams);
        Vector4 jitterParams = new Vector4
        (
            _RayMarchSettings._NoiseSize.x,
            _RayMarchSettings._NoiseSize.y,
            _temporalMgr.GetHaltonVector2().x,
            _temporalMgr.GetHaltonVector2().y
        );
        ssr_mat.SetVector("_JitterSizeAndOffset",jitterParams);
        ssr_mat.SetVector("_DebugParams",DebugParams);
        
        CoreUtils.SetKeyword(ssr_mat, k_IsImportanceSampling,
            _RayMarchSettings.IsImportanceSampling);
        CoreUtils.SetKeyword(ssr_mat, k_IsMulitSampling,
            _RayMarchSettings.IsMulitSampling);
        CoreUtils.SetKeyword(ssr_mat, k_IsPatioFilter,
            _RayMarchSettings.IsPatioFilter);
        CoreUtils.SetKeyword(ssr_mat, k_BRDFSSR,
            _RayMarchSettings.BRDF_SSR);
    }
}