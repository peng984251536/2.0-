using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CustomRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;

        public Material blitMaterial = null;

        //public int blitMaterialPassIndex = -1;
        //目标RenderTexture 
        public RenderTexture renderTexture = null;
    }

    public Settings settings = new Settings();
    private CustomPass blitPass;

    public override void Create()
    {
        blitPass = new CustomPass(name, settings);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (settings.blitMaterial == null)
        {
            Debug.LogWarningFormat("丢失blit材质");
            return;
        }

        blitPass.renderPassEvent = settings.renderPassEvent;
        blitPass.Setup(renderer.cameraDepthTarget);
        renderer.EnqueuePass(blitPass);
    }
}

class RenderTextureFeature : ScriptableRendererFeature
{
    public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques; //和官方的一样用来表示什么时候插入Pass，默认在渲染完不透明物体后
    public FilterSettings filterSettings = new FilterSettings(); //上面的一些自定义过滤设置
    public Material material; //我想用的新的渲染指定物体的材质
    public int[] passes; //我想指定的几个Pass的Index

    [Space(10)] //下面三个是和Unity一样的深度设置
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
        if (passes == null) return;
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
        if (passes == null) return;
        foreach (var pass in m_ScriptablePasses)
        {
            renderer.EnqueuePass(pass);
        }
    }
}