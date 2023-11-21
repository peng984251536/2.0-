using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Scripting.APIUpdating;


[MovedFrom("UnityEngine.Experimental.Rendering.LWRP")]
public class DOF_Pass : ScriptableRenderPass
{
    public Material dofMaterial;
    public int downsampleDivider;

    private string m_ProfilerTag;
    private RenderTextureDescriptor m_Descriptor;


    private RenderTargetHandle m_cocRT;
    // private RenderTargetHandle m_SSRayCast;
    // private RenderTargetHandle m_SSRayCastMask;

    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        //告诉URP我们需要深度和法线贴图
        ConfigureInput(ScriptableRenderPassInput.Depth);
    }

    public DOF_Pass(string profilerTag,Material material)
    {
        m_ProfilerTag = profilerTag;
        profilingSampler = new ProfilingSampler(m_ProfilerTag);
        this.dofMaterial = material;
        
        //renderPassEvent = RenderPassEvent.BeforeRenderingDeferredLights;
        
    }

    public void SetUp(RenderPassEvent _renderPassEvent)
    {
        this.renderPassEvent = _renderPassEvent;
    }
    
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        Camera cam = renderingData.cameraData.camera;
        //用于矩阵转换的参数
        Matrix4x4 vp_Matrix = cam.projectionMatrix * cam.worldToCameraMatrix;
        dofMaterial.SetMatrix("_VPMatrix_invers", vp_Matrix.inverse);
        dofMaterial.SetMatrix("_VPMatrix", vp_Matrix);
        dofMaterial.SetMatrix("_VMatrix", cam.worldToCameraMatrix);
        dofMaterial.SetMatrix("_VMatrix_invers", cam.worldToCameraMatrix.inverse);
        
        
        //球协光照
        //SphericalHarmonicsL2 ambient = RenderSettings.ambientProbe;
        // 将球谐光照数据传递给Shader
        //volemeFogMat.SetVectorArray("_SHData", ConvertSHData(ambient));


        m_Descriptor = renderingData.cameraData.cameraTargetDescriptor;
        m_Descriptor.msaaSamples = 1;
        m_Descriptor.depthBufferBits = 0;
        m_Descriptor.colorFormat = RenderTextureFormat.RHalf;
        //m_Descriptor.width = m_Descriptor.width>> downsampleDivider ;
        //m_Descriptor.height = m_Descriptor.height>>downsampleDivider;


        this.m_cocRT.Init("_cocTexture");

        //申请一张多通道贴图
        cmd.GetTemporaryRT(m_cocRT.id, m_Descriptor, FilterMode.Bilinear);
        //cmd.GetTemporaryRT(m_SSRayCast.id, m_Descriptor, FilterMode.Bilinear);
        //单通道贴图
        //RenderTextureDescriptor descriptor = m_Descriptor;
        //descriptor.colorFormat = RenderTextureFormat.R16;
        //descriptor.msaaSamples = 4;
        // descriptor.autoGenerateMips = true;
        // descriptor.enableRandomWrite = true;
        //cmd.GetTemporaryRT(m_SSRayCastMask.id, descriptor, FilterMode.Bilinear);

        RenderTargetIdentifier[] ids = new RenderTargetIdentifier[] 
        {
            //m_SSRefRT.id,m_SSRayCast.id,
            m_cocRT.id
        };
        ConfigureTarget(ids);
        ConfigureClear(ClearFlag.Color, Color.black);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        ref CameraData cameraData = ref renderingData.cameraData;
        Camera camera = cameraData.camera;
        RenderTargetIdentifier camerRT = renderingData.cameraData.renderer.cameraColorTarget;
        camerRT = renderingData.cameraData.renderer.cameraDepthTarget;
        
        CommandBuffer cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, profilingSampler))
        {
            //搞不懂摄像机的id为啥非得拷贝一份才有用
            RenderTargetHandle rt = new RenderTargetHandle();
            rt.Init("_CamTex");
            RenderTargetHandle rt2 = new RenderTargetHandle();
            rt2.Init("_DOFTexture");
            RenderTextureDescriptor baseDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            baseDescriptor.useMipMap = true;
            baseDescriptor.autoGenerateMips = true;
            baseDescriptor.enableRandomWrite = true;
            baseDescriptor.depthBufferBits = 0;
            baseDescriptor.msaaSamples = 1;
            baseDescriptor.colorFormat = RenderTextureFormat.DefaultHDR;
            cmd.GetTemporaryRT(rt.id,baseDescriptor , FilterMode.Bilinear);
            cmd.GetTemporaryRT(rt2.id,baseDescriptor , FilterMode.Bilinear);
            cmd.Blit(camerRT,rt.Identifier());
            cmd.SetGlobalTexture("_CameraTexture",rt.Identifier());


            
            cmd.Blit(rt.Identifier(),m_cocRT.Identifier(),dofMaterial,0);
            cmd.SetGlobalTexture("_cocTexture",m_cocRT.Identifier());
            
            
            //cmd.Blit(rt.Identifier(),camerRT,dofMaterial,1);
            //CoC
            cmd.Blit(rt.Identifier(),rt2.Identifier(),dofMaterial,1);
            // cmd.SetGlobalTexture("_DOFTexture",rt2.Identifier());
            //Filter
            cmd.SetGlobalTexture("_filterTexture",rt2.Identifier());
            cmd.Blit(m_cocRT.Identifier(),rt.Identifier(),dofMaterial,2);
            cmd.SetGlobalTexture("_filterTexture",rt.Identifier());
            cmd.Blit(m_cocRT.Identifier(),rt2.Identifier(),dofMaterial,3);
            //final
            cmd.Blit(rt2.Identifier(),camerRT);


            //------做光线步进计算SSR
            //------架子GB的法线贴图
            //cmd.Blit(rt.Identifier(),m_SSRefRT_ID,ssrefMat,0);
            // RenderTargetIdentifier[] SSRayCastList = new RenderTargetIdentifier[]
            // {
            //     m_SSRayCast.Identifier(), m_SSRayCastMask.Identifier()
            // };
            // //设置渲染目标
            // cmd.SetRenderTarget(
            //     SSRayCastList,
            //     m_SSRayCastMask.Identifier()
            //     );
            // //渲染 RayCast信息
            // cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity,
            //     dofMaterial, 0, (int)0);
            // //cmd.Blit(m_SSRayCastMask.Identifier(),camerRT);
            //
            // // //----------利用 RayCast信息渲染 反射贴图
            // cmd.SetGlobalTexture("_SSRayCast",m_SSRayCast.Identifier());
            // cmd.SetGlobalTexture("_SSRayCastMask",m_SSRayCastMask.Identifier());
            // //SSR颜色计算
            // cmd.Blit(m_SSRayCast.Identifier(),m_SSRefRT.Identifier(),dofMaterial,1);
            // //Temporal减噪计算
            // RenderTargetIdentifier temRT = _temporalMgr.Execute(cmd, m_SSRefRT.Identifier(), dofMaterial, 2);
            // //把SSR和IBL混合
            // cmd.SetGlobalTexture("_SSRayColor",temRT);
            // cmd.Blit(m_SSRayCast.Identifier(),camerRT,dofMaterial,3);
            // //cmd.Blit(m_SSRayCast.Identifier(),camerRT,ssrefMat,3);
            // //cmd.Blit(temRT,camerRT);
            // //ssrefMat.SetTexture(normalID,"");
            //
            // //计算完后释放RT
            // //cmd.ReleaseTemporaryRT(m_VolumeFogRT_ID);

        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
}