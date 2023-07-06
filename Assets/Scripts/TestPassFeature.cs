using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[System.Serializable]

//custom 过滤模式
public class FilterSettings
{
    public RenderQueueType renderQueueType;//透明还是不透明，Unity定义的enum
    public LayerMask layerMask;//渲染目标的Layer
    [Range(1, 32)] public int renderingLayerMask;//我想要指定的RenderingLayerMask

    public FilterSettings()
    {
        renderQueueType = RenderQueueType.Opaque;//默认不透明
        layerMask = -1;//默认渲染所有层
        renderingLayerMask = 31;//默认渲染32
    }
}

public class TestPassFeature : ScriptableRendererFeature
{
    public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;//和官方的一样用来表示什么时候插入Pass，默认在渲染完不透明物体后
    public FilterSettings filterSettings = new FilterSettings();//上面的一些自定义过滤设置
    public Material material;//我想用的新的渲染指定物体的材质
    public int[] passes;//我想指定的几个Pass的Index
    [Space(10)]//下面三个是和Unity一样的深度设置
    public bool overrideDepthState = false;
    public CompareFunction depthCompareFunction = CompareFunction.LessEqual;
    public bool enableWrite = true;

    //用于存储需要渲染的Pass队列
    private List<TestRenderPass> m_ScriptablePasses = new List<TestRenderPass>(2);
    
    /// <summary>
    /// 用来生产RenderPass
    /// </summary>
    /// <exception cref="NotImplementedException"></exception>
    public override void Create()
    {
        if(passes == null) return;
        m_ScriptablePasses.Clear();
        //根据Shader的Pass数生成多个RenderPass
        for (int i = 0; i < passes.Length; i++)
        {
            var scriptablePass = new TestRenderPass(name, Event, filterSettings);
            scriptablePass.overrideMaterial = material;
            scriptablePass.overrideMaterialPassIndex = passes[i];

            if (overrideDepthState)
                scriptablePass.SetDepthState(enableWrite, depthCompareFunction);

            m_ScriptablePasses.Add(scriptablePass);
        }
    }

    /// <summary>
    /// 添加Pass到渲染队列
    /// </summary>
    /// <param name="renderer"></param>
    /// <param name="renderingData"></param>
    /// <exception cref="NotImplementedException"></exception>
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if(passes == null) return;
        foreach (var pass in m_ScriptablePasses)
        {
            renderer.EnqueuePass(pass);
        }
    }
}