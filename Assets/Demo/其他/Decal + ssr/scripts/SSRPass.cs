using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Scripting.APIUpdating;


[MovedFrom("UnityEngine.Experimental.Rendering.LWRP")]
public class SSRPass : ScriptableRenderPass
{
    public Material ssrefMat;
    public float downsampleDivider;
    public RenderTargetHandle copy_iblTex;  
        
    private string m_ProfilerTag;
    private RenderTextureDescriptor m_Descriptor;
    private TemporalMgr _temporalMgr;
    

    private RenderTargetHandle m_SSRefRT;
    private RenderTargetHandle m_SSRayCast;
    private RenderTargetHandle m_SSRayCastMask;

    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        //告诉URP我们需要深度和法线贴图
        ConfigureInput(ScriptableRenderPassInput.Motion);
    }

    public SSRPass(string profilerTag,
         TemporalMgr temporalMgr,Material material)
    {
        m_ProfilerTag = profilerTag;
        profilingSampler = new ProfilingSampler(m_ProfilerTag);
        this.ssrefMat = material;
        
        //renderPassEvent = RenderPassEvent.BeforeRenderingDeferredLights;
        renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        _temporalMgr = temporalMgr;
    }
    
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        Camera cam = renderingData.cameraData.camera;
        //用于矩阵转换的参数
        Matrix4x4 vp_Matrix = cam.projectionMatrix * cam.worldToCameraMatrix;
        ssrefMat.SetMatrix("_VPMatrix_invers", vp_Matrix.inverse);
        ssrefMat.SetMatrix("_VPMatrix", vp_Matrix);
        ssrefMat.SetMatrix("_VMatrix", cam.worldToCameraMatrix);
        ssrefMat.SetMatrix("_VMatrix_invers", cam.worldToCameraMatrix.inverse);
        
        
        //球协光照
        //SphericalHarmonicsL2 ambient = RenderSettings.ambientProbe;
        // 将球谐光照数据传递给Shader
        //volemeFogMat.SetVectorArray("_SHData", ConvertSHData(ambient));


        m_Descriptor = renderingData.cameraData.cameraTargetDescriptor;
        m_Descriptor.msaaSamples = 1;
        m_Descriptor.depthBufferBits = 0;
        m_Descriptor.colorFormat = RenderTextureFormat.ARGB32;
        m_Descriptor.width = (int)(m_Descriptor.width/ downsampleDivider) ;
        m_Descriptor.height = (int)(m_Descriptor.height/downsampleDivider);
        _temporalMgr.OnCameraSetup(cmd,ref renderingData,m_Descriptor);
        

        this.m_SSRayCastMask.Init("_SSRayCastMask");
        this.m_SSRayCast.Init("_SSRayCast");
        this.m_SSRefRT.Init("_SSRefRT");

        //申请一张多通道贴图
        cmd.GetTemporaryRT(m_SSRefRT.id, m_Descriptor, FilterMode.Bilinear);
        cmd.GetTemporaryRT(m_SSRayCast.id, m_Descriptor, FilterMode.Bilinear);
        //单通道贴图
        RenderTextureDescriptor descriptor = m_Descriptor;
        descriptor.colorFormat = RenderTextureFormat.R16;
        //descriptor.msaaSamples = 4;
        // descriptor.autoGenerateMips = true;
        // descriptor.enableRandomWrite = true;
        cmd.GetTemporaryRT(m_SSRayCastMask.id, descriptor, FilterMode.Bilinear);

        RenderTargetIdentifier[] ids = new RenderTargetIdentifier[] 
        {
            m_SSRefRT.id,m_SSRayCast.id,
            m_SSRayCastMask.id
        };
        ConfigureTarget(ids);
        ConfigureClear(ClearFlag.None, Color.white);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        ref CameraData cameraData = ref renderingData.cameraData;
        Camera camera = cameraData.camera;
        RenderTargetIdentifier camerRT = renderingData.cameraData.renderer.cameraColorTarget;
        
        CommandBuffer cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, profilingSampler))
        {
            //搞不懂摄像机的id为啥非得拷贝一份才有用
            RenderTargetHandle rt = new RenderTargetHandle();
            rt.Init("_CamTex");
            // RenderTargetHandle rt2 = new RenderTargetHandle();
            // rt2.Init("_MyBaseMap");
            RenderTextureDescriptor baseDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            baseDescriptor.useMipMap = true;
            baseDescriptor.autoGenerateMips = true;
            baseDescriptor.enableRandomWrite = true;
            baseDescriptor.depthBufferBits = 0;
            baseDescriptor.msaaSamples = 1;
            baseDescriptor.colorFormat = RenderTextureFormat.DefaultHDR;
            cmd.GetTemporaryRT(rt.id,baseDescriptor , FilterMode.Bilinear);
            //cmd.GetTemporaryRT(rt2.id,baseDescriptor , FilterMode.Bilinear);
            cmd.Blit(camerRT,rt.Identifier());
            //cmd.Blit("_GBuffer0",rt2.Identifier());
            cmd.SetGlobalTexture("_CameraTexture",rt.Identifier());
            //cmd.SetGlobalTexture("_MyBaseMap",rt2.Identifier());


            //------做光线步进计算SSR
            //------架子GB的法线贴图
            //cmd.Blit(rt.Identifier(),m_SSRefRT_ID,ssrefMat,0);
            RenderTargetIdentifier[] SSRayCastList = new RenderTargetIdentifier[]
            {
                m_SSRayCast.Identifier(), m_SSRayCastMask.Identifier()
            };
            //设置渲染目标
            cmd.SetRenderTarget(
                SSRayCastList,
                m_SSRayCastMask.Identifier()
                );
            //渲染 RayCast信息
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity,
                ssrefMat, 0, (int)0);
            //cmd.Blit(m_SSRayCastMask.Identifier(),camerRT);

            // //----------利用 RayCast信息渲染 反射贴图
            cmd.SetGlobalTexture("_SSRayCast",m_SSRayCast.Identifier());
            cmd.SetGlobalTexture("_SSRayCastMask",m_SSRayCastMask.Identifier());
            //SSR颜色计算
            cmd.Blit(m_SSRayCast.Identifier(),m_SSRefRT.Identifier(),ssrefMat,1);
            //Temporal减噪计算
            RenderTargetIdentifier temRT = _temporalMgr.Execute(cmd, m_SSRefRT.Identifier(), ssrefMat, 2);
            //把SSR和IBL混合
            cmd.SetGlobalTexture("_SSRayColor",temRT);
            cmd.Blit(m_SSRayCast.Identifier(),camerRT,ssrefMat,3);
            //cmd.Blit(m_SSRayCast.Identifier(),camerRT,ssrefMat,3);
            //cmd.Blit(temRT,camerRT);
            //ssrefMat.SetTexture(normalID,"");
            
            //计算完后释放RT
            //cmd.ReleaseTemporaryRT(m_VolumeFogRT_ID);

        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
}

public class SSRMaskPass : ScriptableRenderPass
{
    //用于覆盖渲染状态
    private RenderStateBlock m_RenderStateBlock;

    private FilteringSettings m_FilteringSettings;

    //渲染队列
    private RenderQueueType m_renderQueueType;
    private RenderTextureDescriptor m_Descriptor;
    private RenderTargetHandle m_SSRMask;

    //创建该shader中各个pass的ShaderTagId
    private List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>()
    {
        new ShaderTagId("MySSRMask"),
    };


    //TestRenderPass类的构造器，实例化的时候调用
    //Pass的构造方法，参数都由Feature传入
    //设置层级tag,性能分析的名字、渲染事件、过滤、队列、渲染覆盖设置等
    public SSRMaskPass(string profilerTag)
    {
        //调试用
        base.profilingSampler = new ProfilingSampler(profilerTag);
        
        m_renderQueueType = RenderQueueType.Opaque;
        RenderQueueRange renderQueueRange = RenderQueueRange.opaque;

        uint renderingLayerMask = (uint)1 << 1 - 1;
        m_FilteringSettings = new FilteringSettings(renderQueueRange, -1, renderingLayerMask);

        m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
        //m_RenderStateBlock.mask |= RenderStateMask.Depth;
        m_RenderStateBlock.depthState = new DepthState(false, CompareFunction.LessEqual);
    }

    public void SetUp(RenderPassEvent _renderPassEvent)
    {
        this.renderPassEvent = _renderPassEvent;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        base.OnCameraSetup(cmd, ref renderingData);

        m_Descriptor = renderingData.cameraData.cameraTargetDescriptor;
        m_Descriptor.msaaSamples = 1;
        m_Descriptor.depthBufferBits = 0;
        m_Descriptor.colorFormat = RenderTextureFormat.R8;
         m_Descriptor.width = (int)(m_Descriptor.width);
         m_Descriptor.height = (int)(m_Descriptor.height);
         //m_Descriptor.width = (int)(1024);
        //m_Descriptor.height = (int)(1024);

        this.m_SSRMask.Init("_SSRMaskMap");
        cmd.GetTemporaryRT(m_SSRMask.id, m_Descriptor, FilterMode.Bilinear);
        ConfigureTarget(m_SSRMask.Identifier());
        ConfigureClear(ClearFlag.Color, Color.black);
    }
    
    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        //告诉URP我们需要深度和法线贴图
        ConfigureInput(ScriptableRenderPassInput.Depth);
    }

    /// <summary>
    /// 最重要的方法，用来定义CommandBuffer并执行
    /// </summary>
    /// <param name="context"></param>
    /// <param name="renderingData"></param>
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        ref CameraData cameraData = ref renderingData.cameraData;
        RenderTargetIdentifier camerRT = renderingData.cameraData.renderer.cameraColorTarget;

        CommandBuffer cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, profilingSampler))
        {
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            //渲染设置
            SortingCriteria sortingCriteria = (m_renderQueueType == RenderQueueType.Transparent)
                ? SortingCriteria.CommonTransparent
                : renderingData.cameraData.defaultOpaqueSortFlags;
            SortingCriteria sorting = SortingCriteria.RenderQueue;


            //设置 渲染设置
            var drawingSettings = CreateDrawingSettings(
                m_ShaderTagIdList, ref renderingData, sorting);
            //drawingSettings.overrideMaterial = overrideMaterial;
            //不透明
            RenderQueueRange renderQueueRange = RenderQueueRange.opaque;
            m_FilteringSettings = new FilteringSettings(renderQueueRange, -1);

            var clearFlag = ClearFlag.Color;
            var clearColor =Color.black;
            // cmd.ClearRenderTarget(clearFlag,clearColor,);
            cmd.SetRenderTarget(m_SSRMask.Identifier());
            //CoreUtils.SetRenderTarget(cmd,m_CharShadowRT.Identifier(),clearFlag , clearColor);
            context.DrawRenderers(renderingData.cullResults,
                ref drawingSettings,
                ref m_FilteringSettings);
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    
}