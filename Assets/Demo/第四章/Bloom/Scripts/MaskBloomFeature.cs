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

public class MaskBloomFeature : ScriptableRendererFeature
{
    public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques; //和官方的一样用来表示什么时候插入Pass，默认在渲染完不透明物体后
    public FilterSettings filterSettings = new FilterSettings(); //上面的一些自定义过滤设置


    //用于存储需要渲染的Pass队列
    private MaskBloomPass m_ScriptablePasse;
    RenderTargetHandle m_BloomTexture;
    RenderTargetHandle m_BloomTextureNew;
    public static readonly int Params = Shader.PropertyToID("_MyBloomParams");
    public static readonly int sourceTex = Shader.PropertyToID("_MySourceTex");
    public static readonly int bloomLowTex = Shader.PropertyToID("_BloomLowTex");
    
    public Material material;
    private Shader m_shader;
    private BloomVolume _volumeStack;

    /// <summary>
    /// 用来生产RenderPass
    /// </summary>
    /// <exception cref="NotImplementedException"></exception>
    public override void Create()
    {
        if (material == null)
        {
            return;
            //material = new Material(m_shader);
        }
        
        
        _volumeStack = VolumeManager.instance.stack.GetComponent<BloomVolume>();
        if(_volumeStack==null)
            return;
        
        m_BloomTexture.Init("_MyCameraBloomTexture");
        this.m_BloomTextureNew = new RenderTargetHandle();
        this.m_BloomTextureNew.Init("_MyBloomParamsNew");

        m_ScriptablePasse = new MaskBloomPass(name,Event, filterSettings);
        m_ScriptablePasse.material = material;
        m_ScriptablePasse.isUseMask = false;

    }

    /// <summary>
    /// 添加Pass到渲染队列
    /// </summary>
    /// <param name="renderer"></param>
    /// <param name="renderingData"></param>
    /// <exception cref="NotImplementedException"></exception>
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (_volumeStack == null)
        {
            _volumeStack = VolumeManager.instance.stack.GetComponent<BloomVolume>();
            if(_volumeStack==null)
                return;
        }
        if(!_volumeStack.IsActive())
            return;
        if(_volumeStack.intensity.value<=0.01f)
            return;
        if (m_ScriptablePasse != null)
        {
            RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
            m_ScriptablePasse.Setup(descriptor, m_BloomTexture, m_BloomTextureNew);
            m_ScriptablePasse.cameraRenderTarget = renderer.cameraColorTarget;
            renderer.EnqueuePass(m_ScriptablePasse);
        }

        material.SetColor("_ClampColor",_volumeStack._ClampColor.value);
        material.SetVector(Params, new Vector4(
            _volumeStack.threshold.value,
            _volumeStack.intensity.value,
            _volumeStack.width.value, 
            _volumeStack.scatter.value));
    }
}