using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.Universal.Internal;

public class OpauqeTextureFeature : ScriptableRendererFeature
{
    //和官方的一样用来表示什么时候插入Pass，默认在渲染完不透明物体后
    public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
    public Material material;//我想用的新的渲染指定物体的材质

    //用于存储需要渲染的Pass队列
    private CopyColorPass m_ScriptablePasse;
    
    /// <summary>
    /// 用来生产RenderPass
    /// </summary>
    /// <exception cref="NotImplementedException"></exception>
    public override void Create()
    {
        this.m_ScriptablePasse = new CopyColorPass(
            Event,material ,material);
    }

    
    /// <summary>
    /// 添加Pass到渲染队列
    /// </summary>
    /// <param name="renderer"></param>
    /// <param name="renderingData"></param>
    /// <exception cref="NotImplementedException"></exception>
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var src = renderer.cameraColorTarget;
        //renderingData.cameraData.cameraTargetDescriptor;
        RenderTargetHandle dest = new RenderTargetHandle();
        
        dest.Init("_MyOpauqeTexture");
        
        renderer.EnqueuePass(m_ScriptablePasse);
        Downsampling _downsampling = Downsampling._2xBilinear;
        
        
        m_ScriptablePasse.Setup(renderer.cameraColorTarget,dest,_downsampling);
        //把camera渲染到的画面src 传入GlassBlurRenderPass里。
        
    }
}