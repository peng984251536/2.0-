using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

//DrawOpaqueObjects
//unity提供的渲染pass的父类
public class CharShadowReceivePass : ScriptableRenderPass
{

    //用于覆盖渲染状态
    private RenderStateBlock m_RenderStateBlock;
    private FilteringSettings m_FilteringSettings;
    //渲染队列
    private RenderQueueType m_renderQueueType;
    private Material m_SSShadowMat;
    private RenderTextureDescriptor m_Descriptor;
    private RenderTargetHandle m_ShadowRT;


    //TestRenderPass类的构造器，实例化的时候调用
    //Pass的构造方法，参数都由Feature传入
    //设置层级tag,性能分析的名字、渲染事件、过滤、队列、渲染覆盖设置等
    public CharShadowReceivePass(string profilerTag)
    {
        //调试用
        base.profilingSampler = new ProfilingSampler(profilerTag);
        
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        base.OnCameraSetup(cmd, ref renderingData);
        this.m_ShadowRT.Init("_ShadowMap");
        
        m_Descriptor = renderingData.cameraData.cameraTargetDescriptor;
        m_Descriptor.msaaSamples = 1;
        m_Descriptor.depthBufferBits = 0;
        m_Descriptor.colorFormat = RenderTextureFormat.R16;

        cmd.GetTemporaryRT(m_ShadowRT.id, m_Descriptor, FilterMode.Bilinear);
        ConfigureTarget(m_ShadowRT.Identifier());
        ConfigureClear(ClearFlag.None, Color.white);
    }

    public void SetUp(RenderPassEvent _renderPassEvent,Material material)
    {
        this.renderPassEvent = _renderPassEvent;
        this.m_SSShadowMat = material;
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

            //绘制SS阴影
            cmd.SetRenderTarget(m_ShadowRT.Identifier());
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity,
                m_SSShadowMat, 0, (int)0);
            
            // cmd.SetRenderTarget(SSRayCastList);
            // cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity,
            //     ssrefMat, 0, (int)0);
            
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

}