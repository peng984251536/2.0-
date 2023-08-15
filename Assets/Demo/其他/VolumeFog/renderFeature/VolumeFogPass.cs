using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Scripting.APIUpdating;

using shapeSettings = VolumeFogFrature.ShapeSettings;
using noiseSettings = VolumeFogFrature.NoiseSettings;

[MovedFrom("UnityEngine.Experimental.Rendering.LWRP")]
public class VolumeFogPass : ScriptableRenderPass
{
    public Material volemeFog;
    
    private string m_ProfilerTag;
    private ProfilingSampler m_ProfilingSampler;
    private shapeSettings _shapeSettings;
    private noiseSettings _noiseSettings;
    
    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        //告诉URP我们需要深度和法线贴图
        ConfigureInput(ScriptableRenderPassInput.None);
    }

    public VolumeFogPass(string profilerTag ,shapeSettings _shapeSettings,noiseSettings _noiseSettings,
        Material material)
    {
        m_ProfilerTag = profilerTag;
        profilingSampler = new ProfilingSampler(m_ProfilerTag);
        this._shapeSettings = _shapeSettings;
        this._noiseSettings = _noiseSettings;
        this.volemeFog = material;
        
        renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
    }
    

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        //ConfigureTarget(RTList);
        ConfigureClear(ClearFlag.None, Color.white);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        ref CameraData cameraData = ref renderingData.cameraData;
        Camera camera = cameraData.camera;
        
        
        CommandBuffer cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, m_ProfilingSampler))
        {

        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
}