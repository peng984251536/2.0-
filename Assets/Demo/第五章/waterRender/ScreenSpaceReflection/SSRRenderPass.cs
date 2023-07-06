using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SSRRenderPass : ScriptableRenderPass
{
    private const string k_tag = "ScreenSpaceReflection";

    public ScreenSpaceReflectionSettings ssrSetting;

    private static readonly int s_ssrRT1_ID = Shader.PropertyToID("_PlanarReflectionTexture");

    private RenderTargetIdentifier m_HBAOTexture1Target =
        new RenderTargetIdentifier(s_ssrRT1_ID, 0, CubemapFace.Unknown, -1);

    public RenderTargetIdentifier cameraRenderTarget;

    //设置一些开关
    private const string k_TestViewPosKeyword = "_TESTVIEWPOS";

    public SSRRenderPass()
    {
        profilingSampler = new ProfilingSampler(k_tag);
    }

    public void OnInit(ScreenSpaceReflectionSettings _renderSettings)
    {
        this.ssrSetting = _renderSettings;
    }

    public void OnDestroy()
    {
    }

    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        //告诉URP我们需要深度和法线贴图
        ConfigureInput(ScriptableRenderPassInput.Depth | ScriptableRenderPassInput.Normal);
    }


    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        //用于矩阵转换的参数
        Camera cam = renderingData.cameraData.camera;
        Matrix4x4 p_Matrix = cam.projectionMatrix;
        Matrix4x4 v_Matrix = cam.worldToCameraMatrix;
        Shader.SetGlobalMatrix("_PMatrix_invers", p_Matrix.inverse);
        Shader.SetGlobalMatrix("_VMatrix_invers", v_Matrix.inverse);
        Shader.SetGlobalMatrix("_VMatrix", v_Matrix);
        Shader.SetGlobalMatrix("_PMatrix", p_Matrix);

        Vector4 ssrParms = new Vector4
        (
            ssrSetting.maxRayMarchingStep,
            ssrSetting.screenStep,
            ssrSetting.depthThickness,
            0
        );
        Shader.SetGlobalVector("_SSRParms",ssrParms);


        RenderTextureDescriptor m_Descriptor = renderingData.cameraData.cameraTargetDescriptor;
        m_Descriptor.msaaSamples = 1;
        m_Descriptor.depthBufferBits = 0;
        m_Descriptor.colorFormat = RenderTextureFormat.RGB565;
        //申请一张RT叫 hbaoRT_ID
        cmd.GetTemporaryRT(s_ssrRT1_ID, m_Descriptor, FilterMode.Bilinear);
        //把RT设为配置目标
        RenderTargetIdentifier[] RTList = new RenderTargetIdentifier[]
        {
            m_HBAOTexture1Target
        };
        ConfigureTarget(RTList);
        ConfigureClear(ClearFlag.None, Color.white);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, profilingSampler))
        {
            // cmd.SetRenderTarget(
            //     m_HBAOTexture1Target,
            //     RenderBufferLoadAction.DontCare,
            //     RenderBufferStoreAction.Store,
            //     m_HBAOTexture1Target,
            //     RenderBufferLoadAction.DontCare,
            //     RenderBufferStoreAction.DontCare
            // );
            // cmd.DrawMesh(ssrSetting.mesh, Matrix4x4.identity, ssrSetting.refMat);

            //cmd.Blit(cameraRenderTarget, m_HBAOTexture1Target, ssrSetting.refMat);
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }


    /// <summary>
    /// 生产噪点
    /// </summary>
    /// <returns></returns>
    private Vector2[] GenerateNoise()
    {
        Vector2[] noises = new Vector2[4 * 4];

        for (int i = 0; i < noises.Length; i++)
        {
            float x = Random.value;
            float y = Random.value;
            noises[i] = new Vector2(x, y);
        }

        return noises;
    }

    private Vector4[] _noises;

    private Vector4[] GenerateNoise(bool isVector4)
    {
        if (_noises != null)
        {
            return _noises;
        }

        Vector4[] noises = new Vector4[4 * 4];

        for (int i = 0; i < noises.Length; i++)
        {
            float x = Random.value;
            float y = Random.value;
            noises[i] = new Vector4(x, y, 0, 0);
        }

        _noises = noises;
        return noises;
    }
}