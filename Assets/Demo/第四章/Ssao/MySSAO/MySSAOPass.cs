using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Random = UnityEngine.Random;

public class MySSAOPass : ScriptableRenderPass
{
    // Public Variables
    public string profilerTag;
    public Material material;
    public float BilaterFilterFactor; //法线判定的插值
    public Vector2 BlurRadius; //滤波的采样范围

    // Private Variables
    private ScreenSpaceAmbientOcclusionSettings m_CurrentSettings;
    private Matrix4x4[] m_CameraViewProjections = new Matrix4x4[2];
    private Vector4[] m_CameraTopLeftCorner = new Vector4[2];
    private Vector4[] m_CameraXExtent = new Vector4[2];
    private Vector4[] m_CameraYExtent = new Vector4[2];
    private Vector4[] m_CameraZExtent = new Vector4[2];
    private ProfilingSampler m_ProfilingSampler;
    private Vector4[] _randomVector3Array;

    private RenderTargetIdentifier m_SSAOTexture1Target =
        new RenderTargetIdentifier(s_SSAOTexture1ID, 0, CubemapFace.Unknown, -1);

    private RenderTargetIdentifier m_SSAOTexture2Target =
        new RenderTargetIdentifier(s_SSAOTexture2ID, 0, CubemapFace.Unknown, -1);

    private RenderTargetIdentifier m_SSAOTexture3Target =
        new RenderTargetIdentifier(s_SSAOTexture3ID, 0, CubemapFace.Unknown, -1);

    private RenderTargetIdentifier cameraRenderTarget;

    public RenderTargetIdentifier SetCamRT
    {
        set { this.cameraRenderTarget = value; }
    }

    private RenderTextureDescriptor m_Descriptor;

    // Constants
    private const string k_SSAOAmbientOcclusionParamName = "_AmbientOcclusionParam";
    private const string k_SSAOTextureName = "_ScreenSpaceOcclusionTexture";

    // Statics
    private static readonly int s_NoiseMapID = Shader.PropertyToID("_NoiseMap");
    private static readonly int s_MyAOMap = Shader.PropertyToID("_MyAmbientOcclusionTex");
    private static readonly int s_SSAOParamsID = Shader.PropertyToID("_SSAOParams");
    private static readonly int s_RandomVectors = Shader.PropertyToID("_SSAO_RandomVectors");
    private static readonly int s_SSAOTexture1ID = Shader.PropertyToID("_SSAO_OcclusionTexture1");
    private static readonly int s_SSAOTexture2ID = Shader.PropertyToID("_SSAO_OcclusionTexture2");
    private static readonly int s_SSAOTexture3ID = Shader.PropertyToID("_SSAO_OcclusionTexture3");
    private static readonly int _VPMatrix_invers = Shader.PropertyToID("_VPMatrix_invers");
    private static readonly int s_BilFilteringParamsID = Shader.PropertyToID("_bilateralParams");


    //Keywords
    // Constants
    //公共的设置，主要是一些开关
    private const string k_OrthographicCameraKeyword = "_ORTHOGRAPHIC";
    private const string k_NormalReconstructionLowKeyword = "_RECONSTRUCT_NORMAL_LOW";
    private const string k_NormalReconstructionMediumKeyword = "_RECONSTRUCT_NORMAL_MEDIUM";
    private const string k_NormalReconstructionHighKeyword = "_RECONSTRUCT_NORMAL_HIGH";
    private const string k_SourceDepthKeyword = "_SOURCE_DEPTH";
    private const string k_SourceDepthNormalsKeyword = "_SOURCE_DEPTH_NORMALS";
    private const string k_SourceGBufferKeyword = "_SOURCE_GBUFFER";

    private enum ShaderPasses
    {
        AO = 0,
        BlurHorizontal = 1,
        BlurVertical = 2,
        BlurFinal = 3
    }

    public MySSAOPass()
    {
        m_CurrentSettings = new ScreenSpaceAmbientOcclusionSettings();
    }

    /// <summary>
    /// 每帧都执行，修改Freature传入的设置
    /// </summary>
    /// <param name="featureSettings"></param>
    /// <returns></returns>
    /// <exception cref="ArgumentOutOfRangeException"></exception>
    public bool Setup(ScreenSpaceAmbientOcclusionSettings featureSettings)
    {
        m_CurrentSettings = featureSettings;
        m_ProfilingSampler = new ProfilingSampler(profilerTag);
        //挑选深度的类型
        //告诉管线我这个pass需要什么图，让引擎帮忙启用对应的pass
        //来得到对应的图
        switch (m_CurrentSettings.Source)
        {
            case ScreenSpaceAmbientOcclusionSettings.DepthSource.Depth:
                ConfigureInput(ScriptableRenderPassInput.Depth);
                break;
            case ScreenSpaceAmbientOcclusionSettings.DepthSource.DepthNormals:
                ConfigureInput(ScriptableRenderPassInput.Normal);
                break;
            default:
                throw new ArgumentOutOfRangeException();
        }

        this.renderPassEvent = m_CurrentSettings._renderPassEvent;

        return material != null;
        //        && m_CurrentSettings.Intensity > 0.0f
        //        && m_CurrentSettings.Radius > 0.0f
        //        && m_CurrentSettings.SampleCount > 0;
    }

    /// <summary>
    /// 设置渲染中可能会用到的一些参数
    /// </summary>
    /// <param name="cmd"></param>
    /// <param name="renderingData"></param>
    /// <exception cref="ArgumentOutOfRangeException"></exception>
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        RenderTextureDescriptor cameraTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
        int downsampleDivider = 1; //m_CurrentSettings.Downsample ? 2 : 1;


        // 设置ssao的强度，半径范围、等
        Vector4 ssaoParams = new Vector4(
            m_CurrentSettings.Intensity, // Intensity
            m_CurrentSettings.Radius, // Radius
            m_CurrentSettings.RangeStrength, // RangeStrength
            m_CurrentSettings.SampleCount // Sample count
        );
        material.SetVector(s_SSAOParamsID, ssaoParams);
        Camera cam = renderingData.cameraData.camera;
        Matrix4x4 vp_Matrix = cam.projectionMatrix * cam.worldToCameraMatrix;
        material.SetMatrix(_VPMatrix_invers, vp_Matrix.inverse);
        Matrix4x4 v_Matrix = cam.worldToCameraMatrix;
        material.SetMatrix("_VMatrix", v_Matrix);
        Matrix4x4 p_Matrix = cam.projectionMatrix;
        material.SetMatrix("_PMatrix", p_Matrix);
        //传入一组随机向量
        material.SetVectorArray(s_RandomVectors, GetRandomVectorArray(m_CurrentSettings.SampleCount));
        material.SetTexture(s_NoiseMapID, m_CurrentSettings.noiseMap);

        //双边滤波
        Vector4 bilParams = new Vector4
        (
            BlurRadius.x,
            BlurRadius.y,
            BilaterFilterFactor,
            0
        );
        material.SetVector(s_BilFilteringParamsID, bilParams);
        
        material.SetFloat("_DirectLightingStrength",m_CurrentSettings.DirectLightingStrength);


        // Get temporary render textures
        m_Descriptor = cameraTargetDescriptor;
        m_Descriptor.msaaSamples = 1;
        m_Descriptor.depthBufferBits = 0;
        m_Descriptor.width /= downsampleDivider;
        m_Descriptor.height /= downsampleDivider;
        m_Descriptor.colorFormat = RenderTextureFormat.ARGB32;
        cmd.GetTemporaryRT(s_SSAOTexture1ID, m_Descriptor, FilterMode.Bilinear);
        m_Descriptor.width /= downsampleDivider;
        m_Descriptor.height /= downsampleDivider;
        cmd.GetTemporaryRT(s_SSAOTexture2ID, m_Descriptor, FilterMode.Bilinear);
        cmd.GetTemporaryRT(s_SSAOTexture3ID,m_Descriptor,FilterMode.Bilinear);
        //cmd.GetTemporaryRT(s_SSAOTexture3ID, m_Descriptor, FilterMode.Bilinear);

        // Configure targets and clear color
        ConfigureTarget(s_SSAOTexture2ID);
        ConfigureClear(ClearFlag.None, Color.white);
    }

    /// <inheritdoc/>
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (material == null)
        {
            Debug.LogErrorFormat(
                "{0}.Execute(): Missing material. {1} render pass will not execute. Check for missing reference in the renderer resources.",
                GetType().Name, profilerTag);
            return;
        }

        CommandBuffer cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, m_ProfilingSampler))
        {
            cmd.Blit(m_SSAOTexture1Target, m_SSAOTexture1Target, material, 0);

            //高斯滤波
            cmd.SetGlobalTexture(s_MyAOMap, m_SSAOTexture1Target);
            cmd.Blit(m_SSAOTexture1Target, m_SSAOTexture2Target, material, 1);
            cmd.SetGlobalTexture(s_MyAOMap, m_SSAOTexture2Target);
            cmd.Blit(m_SSAOTexture2Target, m_SSAOTexture1Target, material, 2);
            
            //混合输出
            cmd.SetGlobalTexture(s_MyAOMap, m_SSAOTexture1Target);
            cmd.Blit(cameraRenderTarget,m_SSAOTexture3Target);
            cmd.SetGlobalTexture("_MainTex",m_SSAOTexture3Target);
            cmd.Blit(m_SSAOTexture1Target, cameraRenderTarget);
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    private int defauleCount = -1;

    public Vector4[] GetRandomVectorArray(int SampleCount)
    {
        if (_randomVector3Array != null && defauleCount == m_CurrentSettings.SampleCount)
            return _randomVector3Array;

        Vector4[] array = new Vector4[20];
        //Random random = new Random();
        for (int i = 0; i < SampleCount; i++)
        {
            Vector3 randomVec = Vector3.Normalize
            (
                new Vector3
                (
                    i % 2 == 0 ? Random.Range(0, 1.0f) : Random.Range(-1.0f, 0),
                    Random.Range(-1.0f, 1.0f),
                    Random.Range(0.3f, 1.0f)
                )
            );
            array[i] = new Vector4(randomVec.x, randomVec.y, randomVec.z, 0);
        }

        _randomVector3Array = array;
        defauleCount = SampleCount;

        return array;
    }
}