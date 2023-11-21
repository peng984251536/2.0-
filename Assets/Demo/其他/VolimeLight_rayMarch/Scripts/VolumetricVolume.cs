using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[System.Serializable,]
public sealed class VolumetricVolume : VolumeComponent, IPostProcessComponent
{
    [Tooltip("是否开启效果")]
    public BoolParameter enableEffect = new BoolParameter(true);
    public ClampedIntParameter downsampleDivider = new ClampedIntParameter(0,0,4);
    public ClampedFloatParameter _StepSize = new ClampedFloatParameter(0.5f, 0.1f, 10.0f);
    public ClampedIntParameter _MaxStep = new ClampedIntParameter(50,0,100);
    public ClampedFloatParameter _LightIntensity = new ClampedFloatParameter(0f, 0, 3);
    public ColorParameter _LightColor = new ColorParameter(Color.white);
    public ClampedFloatParameter _LightAttenIntensity = new ClampedFloatParameter(0.35f,0f,1.0f);
    public ClampedFloatParameter _LightAttenSmooth = new ClampedFloatParameter(0.2f,0f,1.0f);
    
    // 实现接口
    public bool IsActive() => enableEffect == true;
    public bool IsTileCompatible() => false;
} 