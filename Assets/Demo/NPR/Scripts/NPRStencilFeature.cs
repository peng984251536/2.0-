using System;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Scripting.APIUpdating;
using UnityEngine.Serialization;


//[ExcludeFromPreset]
[MovedFrom("UnityEngine.Experimental.Rendering.Universal")]
public class NPRStencilFeature : ScriptableRendererFeature
{
    private NPRStencilPass pass;

    public RenderPassEvent _RenderPassEvent=RenderPassEvent.BeforeRenderingOpaques;
    
    /// <summary>
    /// 创建时调用
    /// </summary>
    public override void Create()
    {
        if (pass == null)
            pass = new NPRStencilPass(name, _RenderPassEvent+1);

        var stack = VolumeManager.instance.stack;
    }

    protected override void Dispose(bool disposing)
    {
        pass = null;
    }

    /// <summary>
    /// 
    /// </summary>
    /// <param name="renderer"></param>
    /// <param name="renderingData"></param>
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (pass != null)
        {
            renderer.EnqueuePass(pass);
        }
    }
}