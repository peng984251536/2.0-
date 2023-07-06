using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// [System.Serializable]
//
// //custom 过滤模式
// public class FilterSettings
// {
//     public RenderQueueType renderQueueType;//透明还是不透明，Unity定义的enum
//     public LayerMask layerMask;//渲染目标的Layer
//     [Range(1, 32)] public int renderingLayerMask;//我想要指定的RenderingLayerMask
//
//     public FilterSettings()
//     {
//         renderQueueType = RenderQueueType.Opaque;//默认不透明
//         layerMask = -1;//默认渲染所有层
//         renderingLayerMask = 31;//默认渲染32
//     }
// }

public class SurfaceOutlineFeature : ScriptableRendererFeature
{
    public RenderPassEvent FirstEvent = RenderPassEvent.AfterRenderingOpaques;//渲染完不透明物体后
    public RenderPassEvent SecondEvent = RenderPassEvent.AfterRenderingSkybox;//渲染完天空盒之后
    public SurfaceRenderSetting surfaceRenderSetting;

    private bool shouldRender = false;//外部传入决定是否渲染
    List<SurfaceOutlinePass> m_ScriptablePasses = new List<SurfaceOutlinePass>(2);
    
    /// <summary>
    /// 用来生产RenderPass
    /// </summary>
    /// <exception cref="NotImplementedException"></exception>
    public override void Create()
    {
        if(m_ScriptablePasses == null) return;
        m_ScriptablePasses.Clear();
        
        m_ScriptablePasses.Clear();
        var firstPass = new SurfaceOutlinePass(name, FirstEvent, surfaceRenderSetting);
        m_ScriptablePasses.Add(firstPass);
        //var secondPass = new SurfaceOutlinePass(name, SecondEvent, surfaceRenderSetting);
        //m_ScriptablePasses.Add(secondPass);
    }

    /// <summary>
    /// 添加Pass到渲染队列
    /// </summary>
    /// <param name="renderer"></param>
    /// <param name="renderingData"></param>
    /// <exception cref="NotImplementedException"></exception>
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if(m_ScriptablePasses == null) return;
        foreach (var pass in m_ScriptablePasses)
        {
            renderer.EnqueuePass(pass);
        }
    }
}