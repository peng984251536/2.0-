﻿using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Scripting.APIUpdating;

[MovedFrom("UnityEngine.Experimental.Rendering.LWRP")]
public class VolumeLightPass : ScriptableRenderPass
{
    RenderQueueType renderQueueType;
    FilteringSettings m_FilteringSettings;
    RenderObjects.CustomCameraSettings m_CameraSettings;
    string m_ProfilerTag;
    ProfilingSampler m_ProfilingSampler;

    public Material overrideMaterial { get; set; }
    public int overrideMaterialPassIndex { get; set; }

    //public RenderTargetIdentifier cameraRT;

    List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>();

    public void SetDetphState(bool writeEnabled, CompareFunction function = CompareFunction.Less)
    {
        m_RenderStateBlock.mask |= RenderStateMask.Depth;
        m_RenderStateBlock.depthState = new DepthState(writeEnabled, function);
    }

    public void SetStencilState(int reference, CompareFunction compareFunction, StencilOp passOp, StencilOp failOp,
        StencilOp zFailOp)
    {
        StencilState stencilState = StencilState.defaultValue;
        stencilState.enabled = true;
        stencilState.SetCompareFunction(compareFunction);
        stencilState.SetPassOperation(passOp);
        stencilState.SetFailOperation(failOp);
        stencilState.SetZFailOperation(zFailOp);

        m_RenderStateBlock.mask |= RenderStateMask.Stencil;
        m_RenderStateBlock.stencilReference = reference;
        m_RenderStateBlock.stencilState = stencilState;
    }

    RenderStateBlock m_RenderStateBlock;

    public VolumeLightPass(string profilerTag, RenderPassEvent renderPassEvent, string[] shaderTags,
        RenderQueueType renderQueueType, int layerMask, RenderObjects.CustomCameraSettings cameraSettings)
    {
        base.profilingSampler = new ProfilingSampler(nameof(VolumeLightPass));

        m_ProfilerTag = profilerTag;
        m_ProfilingSampler = new ProfilingSampler(profilerTag);
        this.renderPassEvent = renderPassEvent;
        this.renderQueueType = renderQueueType;
        this.overrideMaterial = null;
        this.overrideMaterialPassIndex = 0;
        RenderQueueRange renderQueueRange = (renderQueueType == RenderQueueType.Transparent)
            ? RenderQueueRange.transparent
            : RenderQueueRange.opaque;
        m_FilteringSettings = new FilteringSettings(renderQueueRange, layerMask);

        if (shaderTags != null && shaderTags.Length > 0)
        {
            foreach (var passName in shaderTags)
                m_ShaderTagIdList.Add(new ShaderTagId(passName));
        }
        else
        {
            m_ShaderTagIdList.Add(new ShaderTagId("SRPDefaultUnlit"));
            m_ShaderTagIdList.Add(new ShaderTagId("UniversalForward"));
            m_ShaderTagIdList.Add(new ShaderTagId("UniversalForwardOnly"));
            m_ShaderTagIdList.Add(new ShaderTagId("LightweightForward"));
        }

        m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
        m_CameraSettings = cameraSettings;
    }

    // public VolumeLightPass(URPProfileId profileId, RenderPassEvent renderPassEvent, string[] shaderTags,
    //     RenderQueueType renderQueueType, int layerMask, RenderObjects.CustomCameraSettings cameraSettings)
    //     : this(profileId.GetType().Name, renderPassEvent, shaderTags, renderQueueType, layerMask, cameraSettings)
    // {
    //     m_ProfilingSampler = ProfilingSampler.Get(profileId);
    // }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        Camera _cam = renderingData.cameraData.camera;
        Matrix4x4 vp_Matrix = _cam.projectionMatrix * _cam.worldToCameraMatrix;
        overrideMaterial.SetMatrix("_VPMatrix_invers", vp_Matrix.inverse);
        Matrix4x4 v_Matrix = _cam.worldToCameraMatrix;
        overrideMaterial.SetMatrix("_VMatrix", v_Matrix);
        Matrix4x4 p_Matrix = _cam.projectionMatrix;
        overrideMaterial.SetMatrix("_PMatrix", p_Matrix);

        // Shader.SetGlobalColor("_shadowColor",shadowColor);
        // Shader.SetGlobalFloat("_alpahParams",alpahParams);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        SortingCriteria sortingCriteria = (renderQueueType == RenderQueueType.Transparent)
            ? SortingCriteria.CommonTransparent
            : renderingData.cameraData.defaultOpaqueSortFlags;

        DrawingSettings drawingSettings = CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, sortingCriteria);
        drawingSettings.overrideMaterial = overrideMaterial;
        drawingSettings.overrideMaterialPassIndex = overrideMaterialPassIndex;

        ref CameraData cameraData = ref renderingData.cameraData;
        Camera camera = cameraData.camera;
        
        
        CommandBuffer cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, m_ProfilingSampler))
        {
            // if (m_CameraSettings.overrideCamera)
            // {
            //     Matrix4x4 projectionMatrix = Matrix4x4.Perspective(m_CameraSettings.cameraFieldOfView, cameraAspect,
            //         camera.nearClipPlane, camera.farClipPlane);
            //     projectionMatrix =
            //         GL.GetGPUProjectionMatrix(projectionMatrix, cameraData.IsCameraProjectionMatrixFlipped());
            //
            //     Matrix4x4 viewMatrix = cameraData.GetViewMatrix();
            //     Vector4 cameraTranslation = viewMatrix.GetColumn(3);
            //     viewMatrix.SetColumn(3, cameraTranslation + m_CameraSettings.offset);
            //     
            //     RenderingUtils.SetViewAndProjectionMatrices(cmd, viewMatrix, projectionMatrix, false);
            // }

            RenderTargetIdentifier cameraRT =  cameraData.renderer.cameraColorTarget;
            RenderTargetHandle rt = new RenderTargetHandle();
            rt.Init("_MyCameraColor");
            RenderTextureDescriptor baseDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            baseDescriptor.useMipMap = false;
            baseDescriptor.autoGenerateMips = false;
            baseDescriptor.depthBufferBits = 0;
            baseDescriptor.msaaSamples = 1;
            cmd.GetTemporaryRT(rt.id,baseDescriptor , FilterMode.Bilinear);
            cmd.Blit(cameraRT,rt.Identifier());
            cmd.SetGlobalTexture("_CameraTex",rt.Identifier());
            //cmd.Blit(cameraRT, cameraRT, overrideMaterial);
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            
            context.DrawRenderers(renderingData.cullResults, ref drawingSettings, 
                ref m_FilteringSettings,
                ref m_RenderStateBlock);

            // if (m_CameraSettings.overrideCamera && m_CameraSettings.restoreCamera)
            // {
            //     RenderingUtils.SetViewAndProjectionMatrices(cmd, cameraData.GetViewMatrix(),
            //         cameraData.GetGPUProjectionMatrix(), false);
            // }
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
}