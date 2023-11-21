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
public class SSRFrature : ScriptableRendererFeature
{
    [System.Serializable]
    public class rayMarchSettings
    {
        [Range(1, 5)] public float _downsampleDivider = 1.0f;
        public Texture2D _NoiseTex;
        public Vector2 _NoiseSize = new Vector2(1, 1);

        [Range(0, 1)] public float _BRDFBias = 0.7f;
        [Range(0.0f, 1.0f)] public float _EdgeFactor = 0.25f;
        public int _rayStepNum = 50;
        public float _rayStepScale = 0.25f;
        public float _thickness = -0.61f;
        public bool IsImportanceSampling = true;
        public bool IsMulitSampling = true;
        public bool IsPatioFilter = true;
        public bool BRDF_SSR = true;
        public bool Fireflies = true;
    }


    private SSRPass pass;
    private SSRMaskPass m_ssrMaskPass;
    private const string k_IsImportanceSampling = "_IMPORTANCE_SAMPLING";
    private const string k_IsMulitSampling = "_MULIT_SAMPLING";
    private const string k_IsPatioFilter = "_PATIO_FILTER";
    private const string k_BRDFSSR = "_BRDFSSR";
    private CopyColorPass copyColorPass;
    private RenderTargetHandle Ibl_RTHandle;

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
        CameraData cameraData = renderingData.cameraData;
        if(cameraData.isSceneViewCamera)
            return;
        if (pass == null)
            return;
        if (m_ssrMaskPass == null)
        {
            m_ssrMaskPass = new SSRMaskPass(nameof(SSRMaskPass));
        }
        if (copyColorPass == null)
        {
            copyColorPass = new CopyColorPass(RenderPassEvent.AfterRenderingGbuffer,
                ssr_mat);
        }
        if (Ibl_RTHandle.id==0)
        {
            Ibl_RTHandle = new RenderTargetHandle();
            Ibl_RTHandle.Init( "_CopyIBLTex");
        }
        copyColorPass.Setup(renderer.cameraColorTarget,
            Ibl_RTHandle, Downsampling.None);
        m_ssrMaskPass.SetUp(RenderPassEvent.AfterRenderingGbuffer-5);
        renderer.EnqueuePass(copyColorPass);
        renderer.EnqueuePass(pass);
        renderer.EnqueuePass(m_ssrMaskPass);
        pass.downsampleDivider = _RayMarchSettings._downsampleDivider;
        pass.copy_iblTex = Ibl_RTHandle;

        if (ssr_mat == null)
            return;
        ssr_mat.SetFloat("_BRDFBias", _RayMarchSettings._BRDFBias);
        ssr_mat.SetFloat("_EdgeFactor", _RayMarchSettings._EdgeFactor);
        ssr_mat.SetTexture("_NoiseTex", _RayMarchSettings._NoiseTex);
        ssr_mat.SetVector("_NoiseSize", _RayMarchSettings._NoiseSize);
        ssr_mat.SetFloat("_downsampleDivider", _RayMarchSettings._downsampleDivider);


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
        ssr_mat.SetVector("_JitterSizeAndOffset", jitterParams);
        ssr_mat.SetVector("_DebugParams", DebugParams);

        float _Fireflies = _RayMarchSettings.Fireflies ? 1 : 0;
        ssr_mat.SetFloat("_Fireflies", _Fireflies);
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