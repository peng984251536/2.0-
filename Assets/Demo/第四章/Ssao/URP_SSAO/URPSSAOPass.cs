using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class URPSSAOPass : ScriptableRenderPass
    {
        // Public Variables
        public string profilerTag;
        public Material material;

        // Private Variables
        private ScreenSpaceAmbientOcclusionSettings m_CurrentSettings;
        private Matrix4x4[] m_CameraViewProjections = new Matrix4x4[2];
        private Vector4[] m_CameraTopLeftCorner = new Vector4[2];
        private Vector4[] m_CameraXExtent = new Vector4[2];
        private Vector4[] m_CameraYExtent = new Vector4[2];
        private Vector4[] m_CameraZExtent = new Vector4[2];
        private ProfilingSampler m_ProfilingSampler;

        private RenderTargetIdentifier m_SSAOTexture1Target =
            new RenderTargetIdentifier(s_SSAOTexture1ID, 0, CubemapFace.Unknown, -1);

        private RenderTargetIdentifier m_SSAOTexture2Target =
            new RenderTargetIdentifier(s_SSAOTexture2ID, 0, CubemapFace.Unknown, -1);

        private RenderTargetIdentifier m_SSAOTexture3Target =
            new RenderTargetIdentifier(s_SSAOTexture3ID, 0, CubemapFace.Unknown, -1);

        private RenderTextureDescriptor m_Descriptor;

        // Constants
        private const string k_SSAOAmbientOcclusionParamName = "_AmbientOcclusionParam";
        private const string k_SSAOTextureName = "_ScreenSpaceOcclusionTexture";

        // Statics
        private static readonly int s_BaseMapID = Shader.PropertyToID("_BaseMap");
        private static readonly int s_SSAOParamsID = Shader.PropertyToID("_SSAOParams");
        private static readonly int s_ProjectionParams2ID = Shader.PropertyToID("_ProjectionParams2");
        private static readonly int s_CameraViewProjectionsID = Shader.PropertyToID("_CameraViewProjections");
        private static readonly int s_CameraViewTopLeftCornerID = Shader.PropertyToID("_CameraViewTopLeftCorner");
        private static readonly int s_CameraViewXExtentID = Shader.PropertyToID("_CameraViewXExtent");
        private static readonly int s_CameraViewYExtentID = Shader.PropertyToID("_CameraViewYExtent");
        private static readonly int s_CameraViewZExtentID = Shader.PropertyToID("_CameraViewZExtent");
        private static readonly int s_SSAOTexture1ID = Shader.PropertyToID("_SSAO_OcclusionTexture1");
        private static readonly int s_SSAOTexture2ID = Shader.PropertyToID("_SSAO_OcclusionTexture2");
        private static readonly int s_SSAOTexture3ID = Shader.PropertyToID("_SSAO_OcclusionTexture3");

        private static readonly int _SourceSize = Shader.GetGlobalInt("_SourceSize");

        //Keywords
        // Constants
        //公共的设置，主要是一些开关
        private const string k_OrthographicCameraKeyword = "_ORTHOGRAPHIC";
        private const string k_NormalReconstructionLowKeyword = "_RECONSTRUCT_NORMAL_LOW";
        private const string k_NormalReconstructionMediumKeyword = "_RECONSTRUCT_NORMAL_MEDIUM";
        private const string k_NormalReconstructionHighKeyword = "_RECONSTRUCT_NORMAL_HIGH";
        private const string k_SourceDepthKeyword = "_SOURCE_DEPTH";
        private const string k_SourceDepthNormalsKeyword = "_SOURCE_DEPTH_NORMALS";
        private const string k_SourceGBufferKeyword = "_SOURCE_GBUFFER";

        private enum ShaderPasses
        {
            AO = 0,
            BlurHorizontal = 1,
            BlurVertical = 2,
            BlurFinal = 3
        }

        public URPSSAOPass()
        {
            m_CurrentSettings = new ScreenSpaceAmbientOcclusionSettings();
        }

        /// <summary>
        /// 每帧都执行，修改Freature传入的设置
        /// </summary>
        /// <param name="featureSettings"></param>
        /// <returns></returns>
        /// <exception cref="ArgumentOutOfRangeException"></exception>
        public bool Setup(ScreenSpaceAmbientOcclusionSettings featureSettings)
        {
            m_CurrentSettings = featureSettings;
            m_ProfilingSampler = new ProfilingSampler(profilerTag);
            //挑选深度的类型
            //告诉管线我这个pass需要什么图，让引擎帮忙启用对应的pass
            //来得到对应的图
            switch (m_CurrentSettings.Source)
            {
                case ScreenSpaceAmbientOcclusionSettings.DepthSource.Depth:
                    ConfigureInput(ScriptableRenderPassInput.Depth);
                    break;
                case ScreenSpaceAmbientOcclusionSettings.DepthSource.DepthNormals:
                    ConfigureInput(ScriptableRenderPassInput.Normal);
                    break;
                default:
                    throw new ArgumentOutOfRangeException();
            }

            this.renderPassEvent = m_CurrentSettings._renderPassEvent;
            
            return material != null
                   && m_CurrentSettings.Intensity > 0.0f
                   && m_CurrentSettings.Radius > 0.0f
                   && m_CurrentSettings.SampleCount > 0;
        }

        /// <summary>
        /// 设置渲染中可能会用到的一些参数
        /// </summary>
        /// <param name="cmd"></param>
        /// <param name="renderingData"></param>
        /// <exception cref="ArgumentOutOfRangeException"></exception>
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor cameraTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            int downsampleDivider = m_CurrentSettings.Downsample ? 2 : 1;

            // 设置ssao的强度，半径范围、等
            Vector4 ssaoParams = new Vector4(
                m_CurrentSettings.Intensity, // Intensity
                m_CurrentSettings.Radius, // Radius
                1.0f / downsampleDivider, // Downsampling
                m_CurrentSettings.SampleCount // Sample count
            );
            material.SetVector(s_SSAOParamsID, ssaoParams);


            //------默认情况eyeCount = 1
            //------
#if ENABLE_VR && ENABLE_XR_MODULE
                int eyeCount =
 renderingData.cameraData.xr.enabled && renderingData.cameraData.xr.singlePassEnabled ? 2 : 1;
#else
            int eyeCount = 1;
#endif
            for (int eyeIndex = 0; eyeIndex < eyeCount; eyeIndex++)
            {
                Matrix4x4 view = renderingData.cameraData.GetViewMatrix(eyeIndex);
                Matrix4x4 proj = renderingData.cameraData.GetProjectionMatrix(eyeIndex);
                m_CameraViewProjections[eyeIndex] = proj * view;

                // camera view space without translation, used by SSAO.hlsl ReconstructViewPos() to calculate view vector.
                Matrix4x4 cview = view;
                cview.SetColumn(3, new Vector4(0.0f, 0.0f, 0.0f, 1.0f));
                Matrix4x4 cviewProj = proj * cview;
                Matrix4x4 cviewProjInv = cviewProj.inverse;

                Vector4 topLeftCorner = cviewProjInv.MultiplyPoint(new Vector4(-1, 1, -1, 1));
                Vector4 topRightCorner = cviewProjInv.MultiplyPoint(new Vector4(1, 1, -1, 1));
                Vector4 bottomLeftCorner = cviewProjInv.MultiplyPoint(new Vector4(-1, -1, -1, 1));
                Vector4 farCentre = cviewProjInv.MultiplyPoint(new Vector4(0, 0, 1, 1));
                m_CameraTopLeftCorner[eyeIndex] = topLeftCorner;
                m_CameraXExtent[eyeIndex] = topRightCorner - topLeftCorner;
                m_CameraYExtent[eyeIndex] = bottomLeftCorner - topLeftCorner;
                m_CameraZExtent[eyeIndex] = farCentre;

                Vector4 t = Vector4.one;
                t[0] = 0.5f;
            }

            //设置一些在场景中的参数，用于利用深度值
            //转回世界空间
            material.SetVector(s_ProjectionParams2ID,
                new Vector4(1.0f / renderingData.cameraData.camera.nearClipPlane, 0.0f, 0.0f, 0.0f));
            material.SetMatrixArray(s_CameraViewProjectionsID, m_CameraViewProjections);
            material.SetVectorArray(s_CameraViewTopLeftCornerID, m_CameraTopLeftCorner);
            material.SetVectorArray(s_CameraViewXExtentID, m_CameraXExtent);
            material.SetVectorArray(s_CameraViewYExtentID, m_CameraYExtent);
            material.SetVectorArray(s_CameraViewZExtentID, m_CameraZExtent);

            // Update keywords
            // 设置Key的状态
            CoreUtils.SetKeyword(material, k_OrthographicCameraKeyword, renderingData.cameraData.camera.orthographic);

            //如果采样的是法线信息
            if (m_CurrentSettings.Source == ScreenSpaceAmbientOcclusionSettings.DepthSource.Depth)
            {
                switch (m_CurrentSettings.NormalSamples)
                {
                    case ScreenSpaceAmbientOcclusionSettings.NormalQuality.Low:
                        CoreUtils.SetKeyword(material, k_NormalReconstructionLowKeyword, true);
                        CoreUtils.SetKeyword(material, k_NormalReconstructionMediumKeyword, false);
                        CoreUtils.SetKeyword(material, k_NormalReconstructionHighKeyword, false);
                        break;
                    case ScreenSpaceAmbientOcclusionSettings.NormalQuality.Medium:
                        CoreUtils.SetKeyword(material, k_NormalReconstructionLowKeyword, false);
                        CoreUtils.SetKeyword(material, k_NormalReconstructionMediumKeyword, true);
                        CoreUtils.SetKeyword(material, k_NormalReconstructionHighKeyword, false);
                        break;
                    case ScreenSpaceAmbientOcclusionSettings.NormalQuality.High:
                        CoreUtils.SetKeyword(material, k_NormalReconstructionLowKeyword, false);
                        CoreUtils.SetKeyword(material, k_NormalReconstructionMediumKeyword, false);
                        CoreUtils.SetKeyword(material, k_NormalReconstructionHighKeyword, true);
                        break;
                    default:
                        throw new ArgumentOutOfRangeException();
                }
            }

            //如果采样的是深度-法线信息
            switch (m_CurrentSettings.Source)
            
            {
                case ScreenSpaceAmbientOcclusionSettings.DepthSource.DepthNormals:
                    CoreUtils.SetKeyword(material, k_SourceDepthKeyword, false);
                    CoreUtils.SetKeyword(material, k_SourceDepthNormalsKeyword, true);
                    CoreUtils.SetKeyword(material, k_SourceGBufferKeyword, false);
                    break;
                default:
                    CoreUtils.SetKeyword(material, k_SourceDepthKeyword, true);
                    CoreUtils.SetKeyword(material, k_SourceDepthNormalsKeyword, false);
                    CoreUtils.SetKeyword(material, k_SourceGBufferKeyword, false);
                    break;
            }

            // Get temporary render textures
            m_Descriptor = cameraTargetDescriptor;
            m_Descriptor.msaaSamples = 1;
            m_Descriptor.depthBufferBits = 0;
            m_Descriptor.width /= downsampleDivider;
            m_Descriptor.height /= downsampleDivider;
            m_Descriptor.colorFormat = RenderTextureFormat.ARGB32;
            cmd.GetTemporaryRT(s_SSAOTexture1ID, m_Descriptor, FilterMode.Bilinear);

            m_Descriptor.width *= downsampleDivider;
            m_Descriptor.height *= downsampleDivider;
            cmd.GetTemporaryRT(s_SSAOTexture2ID, m_Descriptor, FilterMode.Bilinear);
            cmd.GetTemporaryRT(s_SSAOTexture3ID, m_Descriptor, FilterMode.Bilinear);

            // Configure targets and clear color
            ConfigureTarget(s_SSAOTexture2ID);
            ConfigureClear(ClearFlag.None, Color.white);
        }

        /// <inheritdoc/>
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (material == null)
            {
                Debug.LogErrorFormat(
                    "{0}.Execute(): Missing material. {1} render pass will not execute. Check for missing reference in the renderer resources.",
                    GetType().Name, profilerTag);
                return;
            }

            CommandBuffer cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                CoreUtils.SetKeyword(cmd, ShaderKeywordStrings.ScreenSpaceOcclusion, true);
                this.SetSourceSize(cmd, m_Descriptor);

                // Execute the SSAO
                // 0 pass 进行ssao采样
                Render(cmd, m_SSAOTexture1Target, ShaderPasses.AO);

                // Execute the Blur Passes
                // 水平/垂直采样 再进行blur混合
                RenderAndSetBaseMap(cmd, m_SSAOTexture1Target, m_SSAOTexture2Target, ShaderPasses.BlurHorizontal);
                RenderAndSetBaseMap(cmd, m_SSAOTexture2Target, m_SSAOTexture3Target, ShaderPasses.BlurVertical);
                RenderAndSetBaseMap(cmd, m_SSAOTexture3Target, m_SSAOTexture2Target, ShaderPasses.BlurFinal);

                // Set the global SSAO texture and AO Params
                //提前把最终渲染好的贴图 m_SSAOTexture2Target 赋予给 k_SSAOTextureName
                //在unity自己的shader执行时调用
                cmd.SetGlobalTexture(k_SSAOTextureName, m_SSAOTexture2Target);
                //让最终ao时调用，调整强度
                cmd.SetGlobalVector(k_SSAOAmbientOcclusionParamName,
                    new Vector4(0f, 0f, 0f, m_CurrentSettings.DirectLightingStrength));
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        private void Render(CommandBuffer cmd, RenderTargetIdentifier target, ShaderPasses pass)
        {
            //设置一张贴图，同时把这个pass 渲染上去
            cmd.SetRenderTarget(
                target,
                RenderBufferLoadAction.DontCare,
                RenderBufferStoreAction.Store,
                target,
                RenderBufferLoadAction.DontCare,
                RenderBufferStoreAction.DontCare
            );
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, material, 0, (int) pass);
        }

        private void RenderAndSetBaseMap(CommandBuffer cmd, RenderTargetIdentifier baseMap,
            RenderTargetIdentifier target,
            ShaderPasses pass)
        {
            //设置这个s_baseMapID，在未完成渲染时，则由其带调用上一个pass渲染的图
            cmd.SetGlobalTexture(s_BaseMapID, baseMap);
            Render(cmd, target, pass);
        }

        /// <inheritdoc/>
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            if (cmd == null)
            {
                throw new ArgumentNullException("cmd");
            }

            CoreUtils.SetKeyword(cmd, ShaderKeywordStrings.ScreenSpaceOcclusion, false);
            cmd.ReleaseTemporaryRT(s_SSAOTexture1ID);
            cmd.ReleaseTemporaryRT(s_SSAOTexture2ID);
            cmd.ReleaseTemporaryRT(s_SSAOTexture3ID);
        }
        
        private void SetSourceSize(CommandBuffer cmd, RenderTextureDescriptor desc)
        {
            float width = desc.width;
            float height = desc.height;
            if (desc.useDynamicScale)
            {
                width *= ScalableBufferManager.widthScaleFactor;
                height *= ScalableBufferManager.heightScaleFactor;
            }
            cmd.SetGlobalVector(_SourceSize, new Vector4(width, height, 1.0f / width, 1.0f / height));
        }
    }



