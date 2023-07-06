using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CustomPass : ScriptableRenderPass
{
    private CustomRenderFeature.Settings settings;
    string m_ProfilerTag;
    RenderTargetIdentifier source;

    public CustomPass(string tag, CustomRenderFeature.Settings settings)
    {
        m_ProfilerTag = tag;
        this.settings = settings;
    }

    public void Setup(RenderTargetIdentifier src)
    {
        source = src;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer command = CommandBufferPool.Get(m_ProfilerTag);
        command.Blit(source, settings.renderTexture, settings.blitMaterial);
        context.ExecuteCommandBuffer(command);
        CommandBufferPool.Release(command);
    }
}
