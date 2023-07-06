using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// public class MyTAA : ScriptableRenderPass
// {
//     private const string k_tag = "HBAO";
//     
//     private static readonly int noiseCB_ID = Shader.PropertyToID("_NoiseCB");
//     private static readonly int intensity_ID = Shader.PropertyToID("_Intensity");
//     private static readonly int radius_ID = Shader.PropertyToID("_Radius");
//     private static readonly int negInvRadius2_ID = Shader.PropertyToID("_NegInvRadius2");
//     private static readonly int maxRadiusPixels_ID = Shader.PropertyToID("_MaxRadiusPixels");
//     private static readonly int distanceFalloff_ID = Shader.PropertyToID("_DistanceFalloff");
//     private static readonly int angleBias_ID = Shader.PropertyToID("_AngleBias");
//     private static readonly int aoMultiplier_ID = Shader.PropertyToID("_AOMultiplier");
//     private static readonly int s_MyAOMap = Shader.PropertyToID("_MyAmbientOcclusionTex");
//     private static readonly int s_hbaoRT1_ID = Shader.PropertyToID("_HBAORT1");
//     private static readonly int s_hbaoRT2_ID = Shader.PropertyToID("_HBAORT2");
//     private static readonly int s_hbaoRT3_ID = Shader.PropertyToID("_HBAORT3");
//
//     private RenderTargetIdentifier m_HBAOTexture1Target =
//         new RenderTargetIdentifier(s_hbaoRT1_ID, 0, CubemapFace.Unknown, -1);
//     private RenderTargetIdentifier m_HBAOTexture2Target =
//         new RenderTargetIdentifier(s_hbaoRT2_ID, 0, CubemapFace.Unknown, -1);
//     private RenderTargetIdentifier m_HBAOTexture3Target =
//         new RenderTargetIdentifier(s_hbaoRT3_ID, 0, CubemapFace.Unknown, -1);
//
//     public RenderTargetIdentifier cameraRenderTarget;
//     private ComputeBuffer noiseCB;
//     private HBAORenderSettings settings;
//     private Material effectMat;
//
//     public float DirectLightingStrength;
//     public float BilaterFilterFactor; //法线判定的插值
//     public Vector2 BlurRadius; //滤波的采样范围
//
//     //设置一些开关
//     private const string k_TestViewPosKeyword = "_TESTVIEWPOS";
//
//     public HBAORenderPass()
//     {
//         profilingSampler = new ProfilingSampler(k_tag);
//     }
//
//     public void OnInit(Material _effectMat, HBAORenderSettings _renderSettings)
//     {
//         effectMat = _effectMat;
//         settings = _renderSettings;
//         if (noiseCB != null)
//         {
//             noiseCB.Release();
//         }
//
//         //设置ComputerBuffer的参数
//         Vector2[] noiseData = GenerateNoise();
//         noiseCB = new ComputeBuffer(noiseData.Length, sizeof(float) * 2);
//         noiseCB.SetData(noiseData);
//     }
//
//     public void OnDestroy()
//     {
//     }
//
//     public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
//     {
//         //告诉URP我们需要深度和法线贴图
//         ConfigureInput(ScriptableRenderPassInput.Depth | ScriptableRenderPassInput.Normal);
//     }
//
//     public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
//     {
//         //用于矩阵转换的参数
//         Camera cam = renderingData.cameraData.camera;
//         Matrix4x4 p_Matrix = cam.projectionMatrix;
//         Matrix4x4 v_Matrix = cam.worldToCameraMatrix;
//         effectMat.SetMatrix("_PMatrix_invers", p_Matrix.inverse);
//         effectMat.SetMatrix("_VMatrix_invers", v_Matrix.inverse);
//         effectMat.SetMatrix("_VMatrix", v_Matrix);
//         effectMat.SetMatrix("_PMatrix", p_Matrix);
//         
//         //双线性高斯模糊
//         //双边滤波
//         Vector4 bilParams = new Vector4
//         (
//             BlurRadius.x,
//             BlurRadius.y,
//             BilaterFilterFactor,
//             DirectLightingStrength
//         );
//         effectMat.SetVector("_bilateralParams", bilParams);
//
//         //传入shader需要的参数
//         int width = renderingData.cameraData.cameraTargetDescriptor.width;
//         int height = renderingData.cameraData.cameraTargetDescriptor.height;
//         float fov = renderingData.cameraData.camera.fieldOfView;
//         float tanHalfFovY = Mathf.Tan(0.5f * fov * Mathf.Deg2Rad);
//
//         //effectMat.SetBuffer(noiseCB_ID, noiseCB);
//         cmd.SetGlobalBuffer(noiseCB_ID, noiseCB);
//         Vector4[] noiseList = GenerateNoise(true);
//
//         cmd.SetGlobalVectorArray("_NoiseCB2", noiseList);
//         cmd.SetGlobalFloat(intensity_ID, settings.intensity);
//         cmd.SetGlobalFloat(radius_ID, settings.radius * 0.5f * height / (2.0f * tanHalfFovY));
//         cmd.SetGlobalFloat(negInvRadius2_ID, -1.0f / (settings.radius * settings.radius));
//         float maxRadiusPixels = settings.maxRadiusPixels * Mathf.Sqrt((width * height) / (1080.0f * 1920.0f));
//         cmd.SetGlobalFloat(maxRadiusPixels_ID, Mathf.Max(16, maxRadiusPixels));
//         cmd.SetGlobalFloat(distanceFalloff_ID,settings.distanceFalloff);
//         cmd.SetGlobalFloat(angleBias_ID, settings.angleBias);
//         cmd.SetGlobalFloat(aoMultiplier_ID, 2.0f / (1.0f - settings.angleBias));
//         SetKeyword(cmd);
//
//         RenderTextureDescriptor m_Descriptor = renderingData.cameraData.cameraTargetDescriptor;
//         m_Descriptor.msaaSamples = 1;
//         m_Descriptor.depthBufferBits = 0;
//         m_Descriptor.colorFormat = RenderTextureFormat.RGB565;
//         //申请一张RT叫 hbaoRT_ID
//         cmd.GetTemporaryRT(s_hbaoRT1_ID, m_Descriptor, FilterMode.Bilinear);
//         cmd.GetTemporaryRT(s_hbaoRT2_ID, m_Descriptor, FilterMode.Bilinear);
//         cmd.GetTemporaryRT(s_hbaoRT3_ID, m_Descriptor, FilterMode.Bilinear);
//
//         RenderTargetIdentifier[] RTList = new RenderTargetIdentifier[]
//         {
//             m_HBAOTexture1Target,m_HBAOTexture2Target,m_HBAOTexture3Target
//         };
//         ConfigureTarget(RTList);
//         ConfigureClear(ClearFlag.None, Color.white);
//     }
//
//     public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
//     {
//         var cmd = CommandBufferPool.Get();
//         using (new ProfilingScope(cmd, profilingSampler))
//         {
//             cmd.SetGlobalBuffer(noiseCB_ID, noiseCB);
//
//             //CoreUtils.DrawFullScreen(cmd, effectMat, null, 0);
//             cmd.Blit(m_HBAOTexture1Target, m_HBAOTexture1Target, effectMat, 0);
//
//             //高斯滤波
//             cmd.SetGlobalTexture(s_MyAOMap, m_HBAOTexture1Target);
//             cmd.Blit(m_HBAOTexture1Target, m_HBAOTexture2Target, effectMat, 1);
//             cmd.SetGlobalTexture(s_MyAOMap, m_HBAOTexture2Target);
//             cmd.Blit(m_HBAOTexture2Target, m_HBAOTexture3Target, effectMat, 2);
//             
//             //混合输出
//             cmd.SetGlobalTexture(s_MyAOMap, m_HBAOTexture3Target);
//             cmd.Blit(cameraRenderTarget,m_HBAOTexture1Target);
//             cmd.SetGlobalTexture("_MainTex",m_HBAOTexture1Target);
//             cmd.Blit(m_HBAOTexture3Target, cameraRenderTarget,effectMat,3);
//
//             //计算完后释放RT
//             cmd.ReleaseTemporaryRT(s_hbaoRT1_ID);
//             cmd.ReleaseTemporaryRT(s_hbaoRT2_ID);
//             cmd.ReleaseTemporaryRT(s_hbaoRT3_ID);
//         }
//
//         context.ExecuteCommandBuffer(cmd);
//         CommandBufferPool.Release(cmd);
//     }
//
//     private void SetKeyword(CommandBuffer cmd)
//     {
//         CoreUtils.SetKeyword(effectMat, k_TestViewPosKeyword, settings.isMyMatrixParmas);
//     }
//
//     /// <summary>
//     /// 生产噪点
//     /// </summary>
//     /// <returns></returns>
//     private Vector2[] GenerateNoise()
//     {
//         Vector2[] noises = new Vector2[4 * 4];
//
//         for (int i = 0; i < noises.Length; i++)
//         {
//             float x = Random.value;
//             float y = Random.value;
//             noises[i] = new Vector2(x, y);
//         }
//
//         return noises;
//     }
//
//     private Vector4[] _noises;
//
//     private Vector4[] GenerateNoise(bool isVector4)
//     {
//         if (_noises != null)
//         {
//             return _noises;
//         }
//
//         Vector4[] noises = new Vector4[4 * 4];
//
//         for (int i = 0; i < noises.Length; i++)
//         {
//             float x = Random.value;
//             float y = Random.value;
//             noises[i] = new Vector4(x, y, 0, 0);
//         }
//
//         _noises = noises;
//         return noises;
//     }
// }