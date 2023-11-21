using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

//DrawOpaqueObjects
//unity提供的渲染pass的父类
public class CharacterShadowPass : ScriptableRenderPass
{
    //用于覆盖渲染状态
    private RenderStateBlock m_RenderStateBlock;

    private FilteringSettings m_FilteringSettings;

    //渲染队列
    private RenderQueueType m_renderQueueType;
    private RenderTextureDescriptor m_Descriptor;
    private RenderTargetHandle m_CharShadowRT;
    private RenderTargetHandle m_CharShadowRampRT;

    //创建该shader中各个pass的ShaderTagId
    private List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>()
    {
        new ShaderTagId("CharacterShadow"),
    };


    //TestRenderPass类的构造器，实例化的时候调用
    //Pass的构造方法，参数都由Feature传入
    //设置层级tag,性能分析的名字、渲染事件、过滤、队列、渲染覆盖设置等
    public CharacterShadowPass(string profilerTag): base()
    {
        //调试用
        base.profilingSampler = new ProfilingSampler(profilerTag);
        
        m_renderQueueType = RenderQueueType.Opaque;
        RenderQueueRange renderQueueRange = RenderQueueRange.opaque;

        uint renderingLayerMask = (uint)1 << 1 - 1;
        m_FilteringSettings = new FilteringSettings(renderQueueRange, -1, renderingLayerMask);

        m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
        m_RenderStateBlock.mask |= RenderStateMask.Depth;
        m_RenderStateBlock.depthState = new DepthState(true, CompareFunction.LessEqual);
    }

    public void SetUp(RenderPassEvent _renderPassEvent)
    {
        this.renderPassEvent = _renderPassEvent;
    }
    
    
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        base.OnCameraSetup(cmd, ref renderingData);

        int piex = 0;
        ScreenPiex sss = CharShadowManager.Instance.screenPiex;
        switch (sss==null?ScreenPiex.Number1024:sss)
        {
            case ScreenPiex.Number512:
                piex = 512;
                break;
            case ScreenPiex.Number1024:
                piex = 1024;
                break;
            case ScreenPiex.Number2048:
                piex = 2048;
                break;
            default:
                piex = 1024;
                break;
        }
        
        m_Descriptor = renderingData.cameraData.cameraTargetDescriptor;
        m_Descriptor.msaaSamples = 1;
        m_Descriptor.depthBufferBits = 32;
        m_Descriptor.colorFormat = RenderTextureFormat.Shadowmap;
         m_Descriptor.width = (int)(piex);
         m_Descriptor.height = (int)(piex);
         //m_Descriptor.width = (int)(1024);
        //m_Descriptor.height = (int)(1024);

        this.m_CharShadowRT.Init("_CharShadowMap");
        cmd.GetTemporaryRT(m_CharShadowRT.id, m_Descriptor, FilterMode.Bilinear);
        this.m_CharShadowRampRT.Init("_CharShadowRampRT");
        m_Descriptor.colorFormat = RenderTextureFormat.R16;
        cmd.GetTemporaryRT(m_CharShadowRampRT.id, m_Descriptor, FilterMode.Bilinear);
        
        RenderTargetIdentifier[] ids = new RenderTargetIdentifier[] 
        {
            m_CharShadowRT.Identifier()//,m_CharShadowRampRT.Identifier()
        };
        ConfigureTarget(ids);
        ConfigureClear(ClearFlag.All, Color.black);
    }
    

    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        //告诉URP我们需要深度和法线贴图
        ConfigureInput(ScriptableRenderPassInput.Depth | ScriptableRenderPassInput.Normal);
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


            
            //设置渲染目标
            // RenderTargetIdentifier[] ShadowList = new RenderTargetIdentifier[]
            // {
            //     m_CharShadowRT.Identifier(), m_CharShadowRampRT.Identifier()
            // };
            // cmd.SetRenderTarget(ShadowList,m_CharShadowRT.Identifier());
//GBuffer

            context.DrawRenderers(renderingData.cullResults,
                ref drawingSettings,
                ref m_FilteringSettings);
            
            cmd.Blit(m_CharShadowRT.Identifier(),m_CharShadowRampRT.Identifier());
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    
}