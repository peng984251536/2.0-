using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


//unity提供的渲染pass的父类
public class SurfaceOutlinePass : ScriptableRenderPass
{
    private string m_ProfilerTag;

    //用于性能分析
    private ProfilingSampler m_ProfilingSampler;

    //用于覆盖渲染状态
    private RenderStateBlock m_RenderStateBlock;

    //渲染队列
    private RenderQueueType m_renderQueueType;

    //渲染时的过滤模式
    [SerializeField]
    private SurfaceRenderSetting m_setting;

    //覆盖的材质
    public Material overrideMaterial { get; set; }
    public int overrideMaterialPassIndex { get; set; }

    //创建该shader中各个pass的ShaderTagId
    private List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>()
    {
        new ShaderTagId("SRPDefaultUnlit"),
        new ShaderTagId("UniversalForward"),
        new ShaderTagId("UniversalForwardOnly"),
        new ShaderTagId("LightweightForward")
    };

    //TestRenderPass类的构造器，实例化的时候调用
    //Pass的构造方法，参数都由Feature传入
    //设置层级tag,性能分析的名字、渲染事件、过滤、队列、渲染覆盖设置等
    public SurfaceOutlinePass(string profilerTag, RenderPassEvent renderPassEvent,
        SurfaceRenderSetting surfaceRenderSetting)
    {
        base.profilingSampler = new ProfilingSampler(nameof(TestRenderPass));
        m_ProfilerTag = profilerTag;
        m_ProfilingSampler = new ProfilingSampler(profilerTag);

        this.renderPassEvent = renderPassEvent;
        this.m_setting = surfaceRenderSetting;
        // m_renderQueueType = surfaceRenderSetting.;
        // RenderQueueRange renderQueueRange = (filterSettings.renderQueueType == RenderQueueType.Transparent)
        //     ? RenderQueueRange.transparent
        //     : RenderQueueRange.opaque;
        // uint renderingLayerMask = (uint) 1 << filterSettings.renderingLayerMask - 1;
        // m_FilteringSettings = new FilteringSettings(renderQueueRange, filterSettings.layerMask, renderingLayerMask);
        //
        // m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
    }

    //设置深度状态
    public void SetDepthState(bool writeEnabled, CompareFunction function = CompareFunction.Less)
    {
        m_RenderStateBlock.mask |= RenderStateMask.Depth;
        m_RenderStateBlock.depthState = new DepthState(writeEnabled, function);
    }

    /// <summary>
    /// 最重要的方法，用来定义CommandBuffer并执行
    /// </summary>
    /// <param name="context"></param>
    /// <param name="renderingData"></param>
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (!m_setting.RendererPrefab||
            !Application.isPlaying)
            return;

        if (!GolbalSetting.Instance.isRendering)
        {
            return;
        }
        

        CommandBuffer cmd = CommandBufferPool.Get();
        cmd.name = "SurfaceOutline";
        var trans = m_setting.RendererInstance.transform;
        trans.position = GolbalSetting.Instance.gobal_pos+m_setting.Offset;
        trans.rotation = m_setting.Rotation;
        // m_setting.RendererInstance.size =
        //     new Vector2(m_setting.Size.x, m_setting.Size.z);
        m_setting.RendererInstance.transform.localScale = new Vector2(m_setting.Size.x, m_setting.Size.z);
        cmd.DrawRenderer(m_setting.RendererInstance,m_setting.RendererInstance.material);
        //cmd.DrawMesh(new Mesh(),new Matrix4x4,new Material());
        context.ExecuteCommandBuffer(cmd);

        CommandBufferPool.Release(cmd);
    }
}



