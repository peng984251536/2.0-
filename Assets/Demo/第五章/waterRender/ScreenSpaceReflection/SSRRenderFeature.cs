using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
public class ScreenSpaceReflectionSettings
{
   public  Material refMat = null;

    //[Range(0, 1000.0f)]
    //public float maxRayMarchingDistance = 500.0f;
    [Range(10, 256)]
    public int maxRayMarchingStep = 64;
    [Range(0.0f,10.0f)]
    public float screenStep = 1.0f;
    [Range(-1.0f,1.0f)]
    public float depthThickness = 0.01f;
}

public class SSRRenderFeature : ScriptableRendererFeature
{
    public ScreenSpaceReflectionSettings renderSettings;
    public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
    
    private SSRRenderPass renderPass;

    public override void Create()
    {
        this.OnCreate();
    }

    protected override void Dispose(bool disposing)
    {
        if (renderPass != null)
        {
            renderPass.OnDestroy();
            renderPass = null;
        }
    }

    public void OnCreate()
    {
        if (renderPass == null)
        {
            renderPass = new SSRRenderPass()
            {
                renderPassEvent = renderPassEvent,
            };
        }

        renderPass.OnInit( renderSettings);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (renderPass == null)
        {
            return;
        }
        
        renderPass.cameraRenderTarget = renderer.cameraColorTarget;
        renderer.EnqueuePass(renderPass);
    }
}