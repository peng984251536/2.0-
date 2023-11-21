using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// [System.Serializable]
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

public class GrayRayBloomFeature : ScriptableRendererFeature
{
    public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques; //和官方的一样用来表示什么时候插入Pass，默认在渲染完不透明物体后
    public FilterSettings filterSettings = new FilterSettings(); //上面的一些自定义过滤设置
    public Material material;

    //调整参数
    [Range(0, 5)] public float threshold = 1;
    [Range(0, 30)] public int intensity = 5;
    [Range(1,1.5f)] public float width = 5;
    [Range(0, 1)] public float scatter = 0.7f;
    [Range(0, 1)] public float godRay_X = 0.5f;
    [Range(0, 1)] public float godRay_Y = 0.5f;
    public float rayBlur = 3;

    [Space(10)] //下面三个是和Unity一样的深度设置
    public bool overrideDepthState = false;

    public bool isRender = true;

    public CompareFunction depthCompareFunction = CompareFunction.LessEqual;
    public bool enableWrite = true;

    //用于存储需要渲染的Pass队列
    private MaskBloomPass m_ScriptablePasse;
    RenderTargetHandle m_BloomTexture;
    RenderTargetHandle m_BloomTextureNew;

    public static readonly int Params = Shader.PropertyToID("_MyBloomParams");
    public static readonly int GrayParams = Shader.PropertyToID("_MyGodGrayParams");
    public static readonly int sourceTex = Shader.PropertyToID("_MySourceTex");
    public static readonly int bloomLowTex = Shader.PropertyToID("_BloomLowTex");

    /// <summary>
    /// 用来生产RenderPass
    /// </summary>
    /// <exception cref="NotImplementedException"></exception>
    public override void Create()
    {
        m_BloomTexture.Init("_MyCameraBloomTexture");
        this.m_BloomTextureNew = new RenderTargetHandle();
        this.m_BloomTextureNew.Init("_MyBloomParamsNew");

        m_ScriptablePasse = new MaskBloomPass(name, Event, filterSettings);
        m_ScriptablePasse.material = this.material;

        if (overrideDepthState)
            m_ScriptablePasse.SetDepthState(enableWrite, depthCompareFunction);
    }

    /// <summary>
    /// 添加Pass到渲染队列
    /// </summary>
    /// <param name="renderer"></param>
    /// <param name="renderingData"></param>
    /// <exception cref="NotImplementedException"></exception>
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (m_ScriptablePasse != null)
        {
            RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
            m_ScriptablePasse.Setup(descriptor, m_BloomTexture, m_BloomTextureNew);
            m_ScriptablePasse.cameraRenderTarget = renderer.cameraColorTarget;
            renderer.EnqueuePass(m_ScriptablePasse);
        }

        Shader.SetGlobalVector(Params, new Vector4(threshold, intensity, width, scatter));
        Shader.SetGlobalVector(GrayParams, new Vector3(godRay_X, godRay_Y,rayBlur));
    }
}