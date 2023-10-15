using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Scripting.APIUpdating;
using shapeSettings = VolumeFogFrature.ShapeSettings;
using noiseSettings = VolumeFogFrature.NoiseSettings;

[MovedFrom("UnityEngine.Experimental.Rendering.LWRP")]
public class VolumeFogPass : ScriptableRenderPass
{
    public Material volemeFogMat;

    private string m_ProfilerTag;

    //private ProfilingSampler m_ProfilingSampler;
    private shapeSettings _shapeSettings;
    private noiseSettings _noiseSettings;
    private RenderTextureDescriptor m_Descriptor;
    public float downsampleDivider;

    private TemporalMgr _temporalMgr;

    //volumeCloud RT
    private static readonly int m_VolumeFogRT_ID = Shader.PropertyToID("_VolumeFogRT");
    private RenderTargetIdentifier m_VolumeFogRT =
        new RenderTargetIdentifier(m_VolumeFogRT_ID, 0, CubemapFace.Unknown, -1);
    private static readonly int m_VolumeFogRT2_ID = Shader.PropertyToID("_VolumeFogRT2");
    private RenderTargetIdentifier m_VolumeFogRT2 =
        new RenderTargetIdentifier(m_VolumeFogRT2_ID, 0, CubemapFace.Unknown, -1);
    // private static readonly int m_PreTexture_ID = Shader.PropertyToID("_PreTexture");
    // private RenderTargetIdentifier m_PreTexture =
    //     new RenderTargetIdentifier(m_PreTexture_ID, 0, CubemapFace.Unknown, -1);
    //PreTex
    

    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        //告诉URP我们需要深度和法线贴图
        ConfigureInput(ScriptableRenderPassInput.Motion);
    }

    public VolumeFogPass(string profilerTag, shapeSettings _shapeSettings, noiseSettings _noiseSettings,
        TemporalMgr temporalMgr, Material material)
    {
        m_ProfilerTag = profilerTag;
        profilingSampler = new ProfilingSampler(m_ProfilerTag);
        this._shapeSettings = _shapeSettings;
        this._noiseSettings = _noiseSettings;
        this.volemeFogMat = material;

        renderPassEvent = RenderPassEvent.AfterRenderingSkybox + 2;
        _temporalMgr = temporalMgr;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        Camera cam = renderingData.cameraData.camera;
        //用于矩阵转换的参数
        Matrix4x4 vp_Matrix = cam.projectionMatrix * cam.worldToCameraMatrix;
        volemeFogMat.SetMatrix("_VPMatrix_invers", vp_Matrix.inverse);


        //球协光照
        //SphericalHarmonicsL2 ambient = RenderSettings.ambientProbe;
        // 将球谐光照数据传递给Shader
        //volemeFogMat.SetVectorArray("_SHData", ConvertSHData(ambient));
        
        m_Descriptor = renderingData.cameraData.cameraTargetDescriptor;
        m_Descriptor.msaaSamples = 1;
        m_Descriptor.depthBufferBits = 0;
        m_Descriptor.colorFormat = RenderTextureFormat.ARGB4444;
        m_Descriptor.width = (int)(m_Descriptor.width / downsampleDivider);
        m_Descriptor.height = (int)(m_Descriptor.height / downsampleDivider);
        _temporalMgr.OnCameraSetup(cmd, ref renderingData,m_Descriptor);


        //申请一张RT叫 VolumeFogRT_ID
        cmd.GetTemporaryRT(m_VolumeFogRT_ID, m_Descriptor, FilterMode.Bilinear);
        cmd.GetTemporaryRT(m_VolumeFogRT2_ID, m_Descriptor, FilterMode.Bilinear);
        //cmd.GetTemporaryRT(m_PreTexture_ID, m_Descriptor, FilterMode.Bilinear);
        RenderTargetIdentifier[] ids = new RenderTargetIdentifier[]
        {
            m_VolumeFogRT, m_VolumeFogRT2
        };
        ConfigureTarget(ids);
        ConfigureClear(ClearFlag.None, Color.white);
        
        //
        // if (m_PreTexture == null)
        // {
        //     // m_PreTexture = new RenderTexture(m_Descriptor.width,m_Descriptor.height,
        //     //     -1,m_Descriptor.colorFormat);
        //     m_PreTexture =  RenderTexture.GetTemporary(m_Descriptor.width,m_Descriptor.height,
        //         -1, RenderTextureFormat.ARGB4444, RenderTextureReadWrite.Default, 1);
        //     m_PreTexture.filterMode = FilterMode.Bilinear;
        //     m_PreTexture.wrapMode = TextureWrapMode.Clamp;
        // }
    }


    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {

        
        ref CameraData cameraData = ref renderingData.cameraData;
        RenderTargetIdentifier camerRT = renderingData.cameraData.renderer.cameraColorTarget;

        CommandBuffer cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, profilingSampler))
        {
            //搞不懂摄像机的id为啥非得拷贝一份才有用
            RenderTargetHandle rt = new RenderTargetHandle();
            rt.Init("_MyMainTex");
            RenderTextureDescriptor baseDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            baseDescriptor.useMipMap = false;
            baseDescriptor.autoGenerateMips = false;
            baseDescriptor.depthBufferBits = 0;
            baseDescriptor.msaaSamples = 1;
            cmd.GetTemporaryRT(rt.id, baseDescriptor, FilterMode.Bilinear);
            cmd.Blit(camerRT, rt.Identifier());
        
        
            //先把体积云渲染在一张RT上
            cmd.SetGlobalTexture("_CameraTexture", rt.Identifier());
            cmd.Blit(m_VolumeFogRT, m_VolumeFogRT, volemeFogMat, 0);
        
            //高斯滤波
            cmd.SetGlobalTexture("_VolumeFogRT", m_VolumeFogRT);
            cmd.Blit(m_VolumeFogRT, m_VolumeFogRT2, volemeFogMat, 1);
            cmd.SetGlobalTexture("_VolumeFogRT", m_VolumeFogRT2);
            cmd.Blit(m_VolumeFogRT2, m_VolumeFogRT, volemeFogMat, 2);
        
            //时预降噪
            RenderTargetIdentifier newRT_ID = _temporalMgr.Execute(cmd,
                m_VolumeFogRT,
                volemeFogMat, 4);

            //
            cmd.SetGlobalTexture("_VolumeFogRT", newRT_ID);
            cmd.Blit(newRT_ID, camerRT, volemeFogMat, 3);
        
            //计算完后释放RT
            cmd.ReleaseTemporaryRT(rt.id);
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    
}