using System;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Scripting.APIUpdating;
using UnityEngine.Serialization;


[ExcludeFromPreset]
[MovedFrom("UnityEngine.Experimental.Rendering.LWRP")]
public class MSAAInSceneFrature : ScriptableRendererFeature
{
    
    /// <summary>
    /// 创建时调用
    /// </summary>
    public override void Create()
    {

    }

    protected override void Dispose(bool disposing)
    {
        
    }

    /// <summary>
    /// 
    /// </summary>
    /// <param name="renderer"></param>
    /// <param name="renderingData"></param>
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        CameraData data = renderingData.cameraData;
        if (data.isSceneViewCamera)
        {
            data.camera.allowMSAA = true;
            data.cameraTargetDescriptor.msaaSamples = 3;
        }
    }
}