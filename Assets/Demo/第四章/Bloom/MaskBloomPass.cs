using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


//unity提供的渲染pass的父类
public class MaskBloomPass : ScriptableRenderPass
{
    private string m_ProfilerTag;

    //用于性能分析
    private ProfilingSampler m_ProfilingSampler;

    //用于覆盖渲染状态
    private RenderStateBlock m_RenderStateBlock;

    //渲染队列
    private RenderQueueType m_renderQueueType;

    //渲染时的过滤模式
    private FilteringSettings m_FilteringSettings;

    //
    public Material material;
    public RenderTargetHandle bloomRTHandle;
    public RenderTargetHandle bloomRTHandleNew;
    public RenderTextureDescriptor descriptor;
    public RenderTargetIdentifier cameraRenderTarget;
    public int intensity;

    //创建该shader中各个pass的ShaderTagId
    private ShaderTagId m_ShaderTagId = new ShaderTagId("BloomOnly");

    //TestRenderPass类的构造器，实例化的时候调用
    //Pass的构造方法，参数都由Feature传入
    //设置层级tag,性能分析的名字、渲染事件、过滤、队列、渲染覆盖设置等
    public MaskBloomPass(string profilerTag, RenderPassEvent renderPassEvent,
        FilterSettings filterSettings)
    {
        //调试用
        base.profilingSampler = new ProfilingSampler(nameof(TestRenderPass));
        m_ProfilerTag = profilerTag;
        m_ProfilingSampler = new ProfilingSampler(profilerTag);

        this.renderPassEvent = renderPassEvent;
        m_renderQueueType = filterSettings.renderQueueType;
        RenderQueueRange renderQueueRange = (filterSettings.renderQueueType == RenderQueueType.Transparent)
            ? RenderQueueRange.transparent
            : RenderQueueRange.opaque;

        uint renderingLayerMask = (uint) 1 << filterSettings.renderingLayerMask - 1;
        m_FilteringSettings = new FilteringSettings(renderQueueRange, filterSettings.layerMask,renderingLayerMask);

        m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
    }

    public void Setup(
        RenderTextureDescriptor baseDescriptor,
        RenderTargetHandle bloomTexture, RenderTargetHandle bloomTextureNew)
    {
        this.bloomRTHandle = bloomTexture;
        this.bloomRTHandleNew = bloomTextureNew;

        // Texture format pre-lookup
        if (SystemInfo.IsFormatSupported(GraphicsFormat.B10G11R11_UFloatPack32,
                FormatUsage.Linear | FormatUsage.Render))
        {
            descriptor.graphicsFormat = GraphicsFormat.B10G11R11_UFloatPack32;
        }
        else
        {
            descriptor.graphicsFormat = QualitySettings.activeColorSpace == ColorSpace.Linear
                ? GraphicsFormat.R8G8B8A8_SRGB
                : GraphicsFormat.R8G8B8A8_UNorm;
        }

        this.descriptor = baseDescriptor;
        descriptor.useMipMap = false;
        descriptor.autoGenerateMips = false;
        descriptor.depthBufferBits = 0;
        descriptor.msaaSamples = 1;
    }

    //设置深度状态
    public void SetDepthState(bool writeEnabled, CompareFunction function = CompareFunction.Less)
    {
        m_RenderStateBlock.mask |= RenderStateMask.Depth;
        m_RenderStateBlock.depthState = new DepthState(writeEnabled, function);
    }

    /// <summary>
    /// 在GPU中注册贴图
    /// </summary>
    /// <param name="cmd"></param>
    /// <param name="renderingData"></param>
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        cmd.GetTemporaryRT(bloomRTHandle.id, descriptor, FilterMode.Bilinear);
        //cmd.GetTemporaryRT(bloomRTHandle.id, descriptor, FilterMode.Bilinear);
        ConfigureTarget(new RenderTargetIdentifier(bloomRTHandle.Identifier(), 0, CubemapFace.Unknown, -1));

        cmd.GetTemporaryRT(bloomRTHandleNew.id, descriptor, FilterMode.Bilinear);
        //cmd.GetTemporaryRT(bloomRTHandle.id, descriptor, FilterMode.Bilinear);
        //ConfigureTarget(new RenderTargetIdentifier(bloomRTHandleNew.Identifier(), 0, CubemapFace.Unknown, -1));

        ConfigureClear(ClearFlag.All, Color.black);
    }

    /// <summary>
    /// 最重要的方法，用来定义CommandBuffer并执行
    /// </summary>
    /// <param name="context"></param>
    /// <param name="renderingData"></param>
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer cmd = CommandBufferPool.Get();

        using (new ProfilingScope(cmd, m_ProfilingSampler))
        {
            SortingCriteria sortingCriteria = (m_renderQueueType == RenderQueueType.Transparent)
                ? SortingCriteria.CommonTransparent
                : renderingData.cameraData.defaultOpaqueSortFlags;

        //设置 渲染设置
        var drawingSettings = CreateDrawingSettings(
            m_ShaderTagId, ref renderingData, sortingCriteria);
        //drawingSettings.overrideMaterial = overrideMaterial;


        //这里不需要所以没有直接写CommandBuffer，在下面Feature的AddRenderPasses加入了渲染队列，底层还是CB
        //发出渲染命令，内容包括制定的材质，还有材质的哪个pass
        //包括符合类型的，场景中的GameObject
        context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_FilteringSettings);

        if (material == null)
        {
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
            return;
        }

        int mipCount = this.intensity;

        RenderTargetHandle[] handles = new RenderTargetHandle[mipCount * 2 + 2];
        handles[0] = bloomRTHandle;
        handles[mipCount * 2 + 1] = bloomRTHandleNew;
        for (int i = 1; i < mipCount * 2; i++)
        {
            handles[i] = new RenderTargetHandle();
            handles[i].Init("_MySourceTex" + i);
        }

        for (int i = 0; i < mipCount; i++)
        {
            descriptor.width = Mathf.Max(3, descriptor.width >> 1);
            descriptor.height = Mathf.Max(1, descriptor.height >> 1);

            cmd.GetTemporaryRT(handles[i * 2 + 1].id, descriptor, FilterMode.Bilinear);
            cmd.GetTemporaryRT(handles[i * 2 + 2].id, descriptor, FilterMode.Bilinear);

            cmd.SetGlobalTexture(MaskBloomFeature.sourceTex, handles[i * 2].Identifier());
            cmd.Blit(handles[i * 2].Identifier(), handles[i * 2 + 1].Identifier(), material, 1);

            cmd.SetGlobalTexture(MaskBloomFeature.sourceTex, handles[i * 2 + 1].Identifier());
            cmd.Blit(handles[i * 2 + 1].Identifier(), handles[i * 2 + 2].Identifier(), material, 0);
        }

        for (int i = mipCount - 1; i >= 0; i--)
        {
            RenderTargetIdentifier lowMip = handles[mipCount - 1 == i ? i * 2 + 2 : i * 2 + 1].Identifier();
            RenderTargetIdentifier highMip = handles[i * 2].Identifier();
            RenderTargetIdentifier dst = handles[i * 2 - 1 > 0 ? i * 2 - 1 : mipCount * 2 + 1].Identifier();

            cmd.SetGlobalTexture(MaskBloomFeature.bloomLowTex, lowMip); //Low
            cmd.SetGlobalTexture(MaskBloomFeature.sourceTex, highMip); //Hight
            cmd.Blit(highMip, BlitDstDiscardContent(cmd, dst), material, 2);
        }

            //直接把cameraRenderTarget当tex传入shader中，在scenes模式会显示不出来
            //
            //cameraRenderTarget = RenderTargetHandle.CameraTarget.Identifier();
            cmd.SetGlobalTexture(MaskBloomFeature.sourceTex, handles[mipCount * 2 + 1].Identifier());
            cmd.SetGlobalTexture(MaskBloomFeature.bloomLowTex, handles[0].Identifier());
            cmd.Blit(cameraRenderTarget,handles[0].Identifier());
            cmd.Blit(handles[mipCount * 2 + 1].Identifier(), cameraRenderTarget, material, 3);
            
            for (int i = 0; i < mipCount; i++)
            {
                cmd.ReleaseTemporaryRT(handles[i * 2 + 1].id);
                cmd.ReleaseTemporaryRT(handles[i * 2 + 2].id);
            }

        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public override void OnCameraCleanup(CommandBuffer cmd)
    {
        if (cmd == null)
            throw new ArgumentNullException("cmd");

        if (bloomRTHandle != RenderTargetHandle.CameraTarget)
        {
            cmd.ReleaseTemporaryRT(bloomRTHandle.id);
            bloomRTHandle = RenderTargetHandle.CameraTarget;
        }
    }

    private BuiltinRenderTextureType BlitDstDiscardContent(CommandBuffer cmd, RenderTargetIdentifier rt)
    {
        // We set depth to DontCare because rt might be the source of PostProcessing used as a temporary target
        // Source typically comes with a depth buffer and right now we don't have a way to only bind the color attachment of a RenderTargetIdentifier
        cmd.SetRenderTarget(new RenderTargetIdentifier(rt, 0, CubemapFace.Unknown, -1),
            RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store,
            RenderBufferLoadAction.DontCare, RenderBufferStoreAction.DontCare);
        return BuiltinRenderTextureType.CurrentActive;
    }
}
