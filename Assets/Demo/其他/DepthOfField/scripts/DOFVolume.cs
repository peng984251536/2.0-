
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable, VolumeComponentMenuForRenderPipeline("MyPostProcessing/DOFVolume", typeof(UniversalRenderPipeline))]
public sealed class DOFVolume : VolumeComponent, IPostProcessComponent
{
    //调整参数
    
    public FloatParameter _FocusDistance = new FloatParameter(5.0f);
    public ClampedFloatParameter _FocusRange = new ClampedFloatParameter(0.0f, 0.0f, 5.0f);
    public ClampedFloatParameter _FocusRadius = new ClampedFloatParameter(2.0f, 0.0f, 10.0f);
    public ClampedFloatParameter intensity = new ClampedFloatParameter(0.0f,0,5) ;
    
    
    // public ClampedFloatParameter threshold = new ClampedFloatParameter(1,0,5);
    // public ClampedFloatParameter width = new ClampedFloatParameter(1,1,1.5f);
    // public ClampedFloatParameter scatter = new ClampedFloatParameter(0f,0.05f,0.95f);
    // public ColorParameter _ClampColor = new ColorParameter(Color.white);
    // public BoolParameter isUseMask = new BoolParameter(false);
    public bool IsActive() => intensity.value > 0f;
    
    
    public bool IsTileCompatible() => false;
}