using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Scripting.APIUpdating;
using UnityEngine.Serialization;


// [MovedFrom("UnityEngine.Experimental.Rendering.LWRP")]
// public enum RenderQueueType
// {
//     Opaque,
//     Transparent,
// }

[ExcludeFromPreset]
[MovedFrom("UnityEngine.Experimental.Rendering.LWRP")]
public class VolumeLightFrature : ScriptableRendererFeature
{
    [System.Serializable]
    public class MyRenderObjectsSettings
    {
        public string passTag = "RenderObjectsFeature";
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;

        public FilterSettings filterSettings = new FilterSettings();

        public Material overrideMaterial = null;
        public int overrideMaterialPassIndex = 0;

        public bool overrideDepthState = false;
        public CompareFunction depthCompareFunction = CompareFunction.LessEqual;
        public bool enableWrite = true;

        public StencilStateData stencilSettings = new StencilStateData();

        public RenderObjects.CustomCameraSettings cameraSettings = new RenderObjects.CustomCameraSettings();
        
        public MyRenderObjectsSettings(){}
    }

    [System.Serializable]
    public class FilterSettings
    {
        // TODO: expose opaque, transparent, all ranges as drop down
        public RenderQueueType RenderQueueType;
        public LayerMask LayerMask;
        public string[] PassNames;

        public FilterSettings()
        {
            RenderQueueType = RenderQueueType.Opaque;
            LayerMask = 0;
        }
    }

    // [System.Serializable]
    // public class CustomCameraSettings
    // {
    //     public bool overrideCamera = false;
    //     public bool restoreCamera = true;
    //     public Vector4 offset;
    //     public float cameraFieldOfView = 60.0f;
    // }

    public MyRenderObjectsSettings settings = new MyRenderObjectsSettings();

    VolumeLightPass renderObjectsPass;

    public override void Create()
    {
        FilterSettings filter = settings.filterSettings;


        if (settings.Event < RenderPassEvent.BeforeRenderingPrePasses)
            settings.Event = RenderPassEvent.BeforeRenderingPrePasses;

        renderObjectsPass = new VolumeLightPass(settings.passTag, settings.Event, filter.PassNames,
            filter.RenderQueueType, filter.LayerMask, settings.cameraSettings);

        renderObjectsPass.overrideMaterial = settings.overrideMaterial;
        renderObjectsPass.overrideMaterialPassIndex = settings.overrideMaterialPassIndex;

        if (settings.overrideDepthState)
            renderObjectsPass.SetDetphState(settings.enableWrite, settings.depthCompareFunction);

        if (settings.stencilSettings.overrideStencilState)
            renderObjectsPass.SetStencilState(settings.stencilSettings.stencilReference,
                settings.stencilSettings.stencilCompareFunction, settings.stencilSettings.passOperation,
                settings.stencilSettings.failOperation, settings.stencilSettings.zFailOperation);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        //renderObjectsPass.cameraRT = renderer.cameraColorTarget;
        renderer.EnqueuePass(renderObjectsPass);
    }
}