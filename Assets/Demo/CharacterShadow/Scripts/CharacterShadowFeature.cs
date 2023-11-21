using System;
using System.Collections.Generic;
using Unity.Mathematics;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Scripting.APIUpdating;
using UnityEngine.Serialization;


//[ExcludeFromPreset]
[MovedFrom("UnityEngine.Experimental.Rendering.Universal")]
public class CharacterShadowFeature : ScriptableRendererFeature
{
    private CharacterShadowPass pass;
    private CharShadowReceivePass receivePass;

    
    public Material SSShadowMat;
    public RenderPassEvent _RenderPassEvent = RenderPassEvent.AfterRenderingShadows;
    public RenderPassEvent _ReceiveRenderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

    /// <summary>
    /// 创建时调用
    /// </summary>
    public override void Create()
    {
        if (pass == null)
            pass = new CharacterShadowPass(name);
        if (receivePass == null)
            receivePass = new CharShadowReceivePass(name);

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
        if(CharShadowManager.Instance==null)
            return;
        if (pass != null)
        {
            pass.SetUp(_RenderPassEvent);
            renderer.EnqueuePass(pass);

            if (SSShadowMat != null)
            {
                
                receivePass.SetUp(_ReceiveRenderPassEvent, SSShadowMat);
                renderer.EnqueuePass(receivePass);
            }
        }
    }
}