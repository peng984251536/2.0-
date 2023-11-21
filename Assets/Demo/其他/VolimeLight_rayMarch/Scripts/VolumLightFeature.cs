using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using ProfilingScope = UnityEngine.Rendering.ProfilingScope;

public class VolumLightFeature : ScriptableRendererFeature
{
    // 用于后处理计算的Shader
    public Shader shader;                                          
    public RenderPassEvent _RenderPassEvent = RenderPassEvent.AfterRenderingTransparents;
    // 后处理计算的Pass
    VolumLightPass postPass;                
    // 根据Shader生成的材质
    public Material _Material = null;                                     


    public override void Create()
    {
        // 外部显示的名字
        this.name = "VolLight";         
        // 初始化Pass
        postPass = new VolumLightPass();    
        // 渲染层级 = 透明物体渲染后
        postPass.renderPassEvent = _RenderPassEvent;              
    }
    
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // 检测Shader是否存在
        if (shader == null)                                                
            return;
        //创建材质
        if (_Material == null) 
            return;
            //_Material = CoreUtils.CreateEngineMaterial(shader);
        if(!VolumeManager.instance.stack.GetComponent<VolumetricVolume>().enableEffect.value)
            return;

        // 获取当前渲染的结果
        var cameraColorTarget = renderer.cameraColorTarget;            
        // 设置调用后 处理Pass，初始化参数
        postPass.Setup(cameraColorTarget, _Material);                    
        renderer.EnqueuePass(postPass);
    }
}

public class VolumLightPass : ScriptableRenderPass
{
    // 标签名字
    const string CommandBufferTag = "AdditionalPostProcessing Pass";      

    // 后处理材质
    public Material m_Material;                        
    // 属性参数组件
    VolumetricVolume m_VolumetricVolume;     
    // 渲染输入的原图
    RenderTargetIdentifier m_ColorAttachment;           
    // 临时渲染结果(临时RT)
    RenderTargetHandle m_TemporaryColorTexture01;     
    RenderTargetHandle m_VolumeLightTexture;   
    
    //创建该shader中各个pass的ShaderTagId
    private List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>()
    {
        new ShaderTagId("MyVolumeLightPass"),
    };


    public VolumLightPass()
    {
        profilingSampler = new ProfilingSampler(nameof(VolumLightPass));
    }
    
    
    public void Setup(RenderTargetIdentifier _ColorAttachment, Material material)
    {
        // 初始化输入纹理
        this.m_ColorAttachment = _ColorAttachment;           
        // 初始化材质
        m_Material = material;                                                   
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        if(m_Material==null)
            return;
        // 获取所有继承Volume框架的脚本。
        var stack = VolumeManager.instance.stack;                   
        // 查找对应的属性参数组件
        m_VolumetricVolume = stack.GetComponent<VolumetricVolume>(); 
        
        base.OnCameraSetup(cmd, ref renderingData);
        //用于矩阵转换的参数
        Camera cam = renderingData.cameraData.camera;
        Matrix4x4 p_Matrix = cam.projectionMatrix;
        Matrix4x4 v_Matrix = cam.worldToCameraMatrix;
        Matrix4x4 vp_Matrix = cam.projectionMatrix * cam.worldToCameraMatrix;
        m_Material.SetMatrix("_VPMatrix_invers", vp_Matrix.inverse);
        m_Material.SetMatrix("_PMatrix_invers", p_Matrix.inverse);
        m_Material.SetMatrix("_VMatrix_invers", v_Matrix.inverse);
        m_Material.SetMatrix("_VMatrix", v_Matrix);
        m_Material.SetMatrix("_PMatrix", p_Matrix);
        
        // 写入参数 获取Shader的数据和Vol组件的绑定
        m_Material.SetFloat("_StepSize", m_VolumetricVolume._StepSize.value);
        m_Material.SetInt("_MaxStep", m_VolumetricVolume._MaxStep.value);
        m_Material.SetFloat("_LightIntensity", m_VolumetricVolume._LightIntensity.value);
        m_Material.SetColor("_LightColor", m_VolumetricVolume._LightColor.value);
        
        m_TemporaryColorTexture01.Init("_TemporaryColorTexture01");
        m_VolumeLightTexture.Init("_VolumeLightTexture");
        RenderTextureDescriptor baseDescriptor = renderingData.cameraData.cameraTargetDescriptor;
        // 设置深度缓存区，就深度缓冲区的精度为0，
        baseDescriptor.depthBufferBits = 0;
        baseDescriptor.msaaSamples = 1;
        //baseDescriptor.colorFormat = RenderTextureFormat.DefaultHDR;
        // 通过目标相机的渲染信息创建临时缓冲区
        cmd.GetTemporaryRT(m_TemporaryColorTexture01.id,baseDescriptor , FilterMode.Bilinear);//
        baseDescriptor.width = baseDescriptor.width >> m_VolumetricVolume.downsampleDivider.value;
        baseDescriptor.height = baseDescriptor.height >> m_VolumetricVolume.downsampleDivider.value;
        cmd.GetTemporaryRT(m_VolumeLightTexture.id,baseDescriptor , FilterMode.Bilinear);//

        // RenderTargetIdentifier[] ids = new RenderTargetIdentifier[] 
        // {
        //     m_CharShadowRT.Identifier()//,m_CharShadowRampRT.Identifier()
        // };
        // ConfigureTarget(ids);
        ConfigureClear(ClearFlag.All, Color.black);
        ConfigureTarget(m_VolumeLightTexture.Identifier());
    }

    
    
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        // 从命令缓冲区池中获取一个带标签的命令缓冲区，该标签名可以在后续帧调试器中见到
        CommandBuffer cmd = CommandBufferPool.Get();                                

        using (new ProfilingScope(cmd, profilingSampler))
        {
            RenderByScreenSpace(context,cmd, ref renderingData); // 调用渲染函数

        }

        // 执行命令缓冲区
        context.ExecuteCommandBuffer(cmd);                 
        // 输出临时RT
        cmd.ReleaseTemporaryRT(m_TemporaryColorTexture01.id);  
        cmd.ReleaseTemporaryRT(m_VolumeLightTexture.id);
        // 释放缓存区
        CommandBufferPool.Release(cmd);                                                          
        
    }

    void RenderByScreenSpace(ScriptableRenderContext context, CommandBuffer cmd, ref RenderingData renderingData)
    {
        ref CameraData cameraData = ref renderingData.cameraData;
        Camera camera = cameraData.camera;
        RenderTargetIdentifier camerRT = renderingData.cameraData.renderer.cameraColorTarget;
        
        
        // 判断组件是否开启，且非Scene视图摄像机
        //if(m_VolumetricVolume.IsActive() && !renderingData.cameraData.isSceneViewCamera)
        {
             // 写入参数 获取Shader的数据和Vol组件的绑定
            m_Material.SetFloat("_StepSize", m_VolumetricVolume._StepSize.value);
            m_Material.SetInt("_MaxStep", m_VolumetricVolume._MaxStep.value);
            m_Material.SetFloat("_LightIntensity", m_VolumetricVolume._LightIntensity.value);
            m_Material.SetColor("_LightColor", m_VolumetricVolume._LightColor.value);
            m_Material.SetFloat("_LightAttenIntensity",m_VolumetricVolume._LightAttenIntensity.value);
            m_Material.SetFloat("_LightAttenSmooth",m_VolumetricVolume._LightAttenSmooth.value);

            // 创建RT
            //搞不懂摄像机的id为啥非得拷贝一份才有用
            RenderTargetHandle rt = new RenderTargetHandle();
            rt.Init("_MainTex");
            RenderTextureDescriptor baseDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            baseDescriptor.useMipMap = true;
            baseDescriptor.autoGenerateMips = true;
            baseDescriptor.enableRandomWrite = true;
            // 设置深度缓存区，就深度缓冲区的精度为0，
            baseDescriptor.depthBufferBits = 0;
            baseDescriptor.msaaSamples = 1;
            //baseDescriptor.colorFormat = RenderTextureFormat.DefaultHDR;
            // 通过目标相机的渲染信息创建临时缓冲区
            cmd.GetTemporaryRT(rt.id,baseDescriptor , FilterMode.Bilinear);//拷贝摄像机的
            cmd.Blit(camerRT,rt.Identifier());//拷贝camRT
            
            // 输入纹理经过材质计算输出到缓冲区
            cmd.SetGlobalTexture("_MainTex",rt.Identifier());
            cmd.Blit(rt.Identifier(), m_VolumeLightTexture.Identifier(), m_Material,0);    
            cmd.Blit(rt.Identifier(), m_TemporaryColorTexture01.Identifier(), m_Material,1); 
            // 再从临时缓冲区存入主纹理
            cmd.Blit(m_TemporaryColorTexture01.Identifier(), camerRT);                               
        }
    }
    
    void RenderByMesh(ScriptableRenderContext context, CommandBuffer cmd, ref RenderingData renderingData)
    {
        ref CameraData cameraData = ref renderingData.cameraData;
        Camera camera = cameraData.camera;
        RenderTargetIdentifier camerRT = renderingData.cameraData.renderer.cameraColorTarget;
        
        
        // 判断组件是否开启，且非Scene视图摄像机
        //if(m_VolumetricVolume.IsActive() && !renderingData.cameraData.isSceneViewCamera)
        {
            m_Material.SetFloat("_StepSize", m_VolumetricVolume._StepSize.value);
            m_Material.SetInt("_MaxStep", m_VolumetricVolume._MaxStep.value);
            m_Material.SetFloat("_LightIntensity", m_VolumetricVolume._LightIntensity.value);
            m_Material.SetColor("_LightColor", m_VolumetricVolume._LightColor.value);

            //渲染设置
            SortingCriteria sortingCriteria = renderingData.cameraData.defaultOpaqueSortFlags;
            SortingCriteria sorting = SortingCriteria.RenderQueue;
            DrawingSettings drawingSettings;
            //设置 渲染设置
            drawingSettings = CreateDrawingSettings(
                m_ShaderTagIdList, ref renderingData, sorting);
            drawingSettings.overrideMaterial = m_Material;
            drawingSettings.overrideMaterialPassIndex = 0;
            //不透明
            RenderQueueRange renderQueueRange = RenderQueueRange.opaque;
            FilteringSettings m_FilteringSettings = new FilteringSettings(renderQueueRange, -1);
            context.DrawRenderers(renderingData.cullResults, 
                ref drawingSettings, 
                ref m_FilteringSettings);     
            
            // 创建RT
            //搞不懂摄像机的id为啥非得拷贝一份才有用
            RenderTargetHandle rt = new RenderTargetHandle();
            rt.Init("_MainTex");
            RenderTextureDescriptor baseDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            baseDescriptor.useMipMap = true;
            baseDescriptor.autoGenerateMips = true;
            baseDescriptor.enableRandomWrite = true;
            // 设置深度缓存区，就深度缓冲区的精度为0，
            baseDescriptor.depthBufferBits = 0;
            baseDescriptor.msaaSamples = 1;
            //baseDescriptor.colorFormat = RenderTextureFormat.DefaultHDR;
            // 通过目标相机的渲染信息创建临时缓冲区
            cmd.GetTemporaryRT(rt.id,baseDescriptor , FilterMode.Bilinear);//拷贝摄像机的
            cmd.Blit(camerRT,rt.Identifier());//拷贝camRT

            
            cmd.Blit(rt.Identifier(),
                m_TemporaryColorTexture01.Identifier(),m_Material,1);
            cmd.Blit(m_TemporaryColorTexture01.Identifier(),camerRT);
        }
    }
}
