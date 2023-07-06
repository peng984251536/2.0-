using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class HBAORenderFeature : ScriptableRendererFeature
{
    public Shader effectShader;
    public HBAORenderSettings renderSettings;

    private bool needCreate;
    private HBAORenderPass renderPass;
    private Material effectMat;

    [SerializeField] [Range(0, 1)] private float DirectLightingStrength;//ao阴影做线性插值
    [SerializeField] [Range(0,1)]private float BilaterFilterFactor; //法线判定的插值
    [SerializeField] private Vector2 BlurRadius; //滤波的采样范围

    public override void Create()
    {
        needCreate = true;
    }

    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(effectMat);
        if (renderPass != null)
        {
            renderPass.OnDestroy();
            renderPass = null;
        }
    }

    public void OnCreate()
    {
        if (!needCreate)
        {
            return;
        }

        needCreate = false;

        if (renderPass == null)
        {
            renderPass = new HBAORenderPass()
            {
                renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing,
            };
        }

        if (effectMat == null || effectMat.shader != effectShader)
        {
            CoreUtils.Destroy(effectMat);
            if (effectShader != null)
            {
                effectMat = CoreUtils.CreateEngineMaterial(effectShader);
            }
        }

        renderPass.OnInit(effectMat, renderSettings);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (effectShader == null)
        {
            return;
        }

        OnCreate();
        renderPass.cameraRenderTarget = renderer.cameraColorTarget;
        renderPass.BlurRadius = BlurRadius;
        renderPass.BilaterFilterFactor = BilaterFilterFactor;
        renderPass.DirectLightingStrength = DirectLightingStrength;
        renderer.EnqueuePass(renderPass);
    }
}