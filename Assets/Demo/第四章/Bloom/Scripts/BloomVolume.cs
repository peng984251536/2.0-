



using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable, VolumeComponentMenuForRenderPipeline("MyPostProcessing/BloomVolume", typeof(UniversalRenderPipeline))]
public sealed class BloomVolume : VolumeComponent, IPostProcessComponent
{
  

    //调整参数
    public ClampedFloatParameter threshold = new ClampedFloatParameter(1,0,5);
    public ClampedFloatParameter intensity = new ClampedFloatParameter(0,0,20) ;
    public ClampedFloatParameter width = new ClampedFloatParameter(1,1,1.5f);
    public ClampedFloatParameter scatter = new ClampedFloatParameter(0f,0.05f,0.95f);
    
    public ColorParameter _ClampColor = new ColorParameter(Color.white);
    
    public BoolParameter isUseMask = new BoolParameter(false);
    public bool IsActive() => intensity.value > 0f;
    

    public bool IsTileCompatible() => false;
}