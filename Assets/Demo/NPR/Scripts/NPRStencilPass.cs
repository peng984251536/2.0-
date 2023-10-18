using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


//unity提供的渲染pass的父类
public class NPRStencilPass : ScriptableRenderPass
{

    //用于覆盖渲染状态
    private RenderStateBlock m_RenderStateBlock;
    private FilteringSettings m_FilteringSettings;
    
    //渲染队列
    private RenderQueueType m_renderQueueType;

    //渲染时的过滤模式
    [SerializeField]
    private SurfaceRenderSetting m_setting;

    //创建该shader中各个pass的ShaderTagId
    private List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>()
    {
        new ShaderTagId("StencilMaskRead"),
        new ShaderTagId("StencilMaskBlend"),
        new ShaderTagId("MyUniversalForward")
    };

    //TestRenderPass类的构造器，实例化的时候调用
    //Pass的构造方法，参数都由Feature传入
    //设置层级tag,性能分析的名字、渲染事件、过滤、队列、渲染覆盖设置等
    public NPRStencilPass(string profilerTag, RenderPassEvent renderPassEvent)
    {
        //调试用
        base.profilingSampler = new ProfilingSampler(nameof(profilerTag));

        this.renderPassEvent = renderPassEvent;
        m_renderQueueType = RenderQueueType.Opaque;
        RenderQueueRange renderQueueRange = RenderQueueRange.opaque;

        uint renderingLayerMask = (uint) 1 << 1 - 1;
        m_FilteringSettings = new FilteringSettings(renderQueueRange,-1,renderingLayerMask);

        m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
        m_RenderStateBlock.mask |= RenderStateMask.Depth;
        m_RenderStateBlock.depthState = new DepthState(true, CompareFunction.LessEqual);
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
            
            
            
            context.DrawRenderers(renderingData.cullResults, 
                ref drawingSettings, 
                ref m_FilteringSettings);
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
    
}



