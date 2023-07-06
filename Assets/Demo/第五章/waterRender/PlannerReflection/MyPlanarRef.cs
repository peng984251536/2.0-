using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

[ExecuteAlways]
public class MyPlanarRef : MonoBehaviour
{
    [Serializable]
    public enum ResolutionMulltiplier
    {
        Full,
        Half,
        Third,
        Quarter
    }
    
    //关于平面反射的设置
    [Serializable]
    public class PlanarReflectionSettings
    {
        public ResolutionMulltiplier m_ResolutionMultiplier = ResolutionMulltiplier.Third;
        public float m_planeOffset;
        public float m_planeNearOffset;
        public float m_ClipPlaneOffset = 0.1f;
        //public LayerMask m_ReflectLayers = -1;
        public bool m_Shadows;
    }

    
    private static Camera _reflectionCamera;
    private RenderTexture _reflectionTexture;
    private readonly int _planarReflectionTextureId = Shader.PropertyToID("_PlanarReflectionTexture");

    public PlanarReflectionSettings settings = new PlanarReflectionSettings();
    public GameObject planer;

    private void OnEnable()
    {
        RenderPipelineManager.beginCameraRendering += ExecutePlanarReflections;
    }
    
    private void OnDisable()
    {
        Cleanup();
    }

    private void OnDestroy()
    {
        Cleanup();
    }
    
    private void Cleanup()
    {
        RenderPipelineManager.beginCameraRendering -= ExecutePlanarReflections;

        if (_reflectionCamera)
        {
            _reflectionCamera.targetTexture = null;
            if (Application.isEditor)
            {
                DestroyImmediate(_reflectionCamera.gameObject);
            }
            else
            {
                Destroy(_reflectionCamera.gameObject);
            }
        }

        if (_reflectionTexture)
        {
            RenderTexture.ReleaseTemporary(_reflectionTexture);
        }
    }

    private void ExecutePlanarReflections(ScriptableRenderContext context, Camera camera)
    {
        UpdateReflectionCamera(camera);
        
        //优化方案 - 降低系统的渲染质量，渲染完图片后再恢复原来的渲染设置
         var data =
             new PlanarReflectionSettingData();
         data.Set(); // set quality settings

         //启动关键字？
        Shader.EnableKeyword("_PLANAR_REFLECTION_CAMERA");
        // render planar reflections
        UniversalRenderPipeline.RenderSingleCamera(context, _reflectionCamera);
        
        data.Restore(); // restore the quality settings
        
        Shader.SetGlobalTexture(_planarReflectionTextureId, _reflectionTexture); // Assign texture to water shader
        Shader.DisableKeyword("_PLANAR_REFLECTION_CAMERA");
    }


    /// <summary>
    /// 更新反射贴图的摄像机
    /// 输入的是真实的摄像机
    /// </summary>
    /// <param name="realCamera"></param>
    private void UpdateReflectionCamera(Camera realCamera)
    {
        if (_reflectionCamera == null)
            _reflectionCamera = CreateMirrorObjects(realCamera);
        
        UpdateCamera(realCamera, _reflectionCamera);

        //创建平面反射矩阵
        Vector3 normal = planer.transform.up;
        Vector3 pos = planer.transform.position+normal*settings.m_planeOffset;
        var d = -Vector3.Dot(normal, pos)
                - settings.m_planeNearOffset;
        var reflectionPlane = new Vector4(normal.x, normal.y, normal.z, d);
        Matrix4x4 reflection = CalculateReflectionMatrix(reflectionPlane);
        var oldPosition = realCamera.transform.position - new Vector3(0, pos.y * 2, 0);
        var newPosition = new Vector3(oldPosition.x, -oldPosition.y, oldPosition.z);
        _reflectionCamera.transform.forward = Vector3.Scale(realCamera.transform.forward, new Vector3(1, -1, 1));
        _reflectionCamera.worldToCameraMatrix = realCamera.worldToCameraMatrix * reflection;
        //_reflectionCamera.transform.position = newPosition;
        
        
        //设置裁剪平面
        //为了反射相机近裁剪平面紧贴我们的反射平面，防止错误渲染
        //我们需要重新计算反射相机的投影矩阵，斜裁剪矩阵(ObliqueMatrix)
        Vector4 viewPlane = CameraSpacePlane(realCamera.worldToCameraMatrix,
            planer.transform.position, -planer.transform.up,settings.m_ClipPlaneOffset);
        _reflectionCamera.projectionMatrix = _reflectionCamera.CalculateObliqueMatrix(viewPlane);
        
        //设置渲染RT
        if (_reflectionTexture == null)
        {
            //渲染精度
            float scale = UniversalRenderPipeline.asset.renderScale;
            var width = (int) (realCamera.pixelWidth * scale * GetScaleValue());
            var height = (int) (realCamera.pixelHeight * scale * GetScaleValue());
            bool useHdr10 = RenderingUtils.SupportsRenderTextureFormat(RenderTextureFormat.RGB111110Float);
            RenderTextureFormat hdrFormat =
                useHdr10 ? RenderTextureFormat.RGB111110Float : RenderTextureFormat.DefaultHDR;
            _reflectionTexture = RenderTexture.GetTemporary(width, height, 16,
                GraphicsFormatUtility.GetGraphicsFormat(hdrFormat, true));
        }
        _reflectionCamera.targetTexture = _reflectionTexture;

    }
    
    /// <summary>
    /// 计算视图空间的平面
    /// </summary>
    /// <param name="worldToCameraMatrix"></param>
    /// <param name="pos"></param>
    /// <param name="normal"></param>
    /// <returns></returns>
    private Vector4 CameraSpacePlane(Matrix4x4 worldToCameraMatrix, Vector3 pos, Vector3 normal,float clipOffset)
    {
        //把法线和pos转换到摄像机空间
        Vector3 viewPos = worldToCameraMatrix.MultiplyPoint3x4(pos+normal*clipOffset);
        Vector3 viewNormal = worldToCameraMatrix.MultiplyVector(normal).normalized;
        float w = -Vector3.Dot(viewPos, viewNormal);
        return new Vector4(viewNormal.x, viewNormal.y, viewNormal.z, w);
    }


    /// <summary>
    /// 创建虚拟摄像机
    /// </summary>
    /// <returns></returns>
    private Camera CreateMirrorObjects(Camera realCamera)
    {
        var go = new GameObject("Planar Reflections", typeof(Camera));
        var cameraData = go.AddComponent(typeof(UniversalAdditionalCameraData)) as UniversalAdditionalCameraData;

        cameraData.requiresColorOption = CameraOverrideOption.Off;
        cameraData.requiresDepthOption = CameraOverrideOption.Off;
        // var asset = UniversalRenderPipeline.asset;
        // var render = UniversalRenderPipeline.asset.scriptableRenderer;
        //设置这个URP相机的渲染层级
        cameraData.SetRenderer(3);

        var t = transform;
        var reflectionCamera = go.GetComponent<Camera>();
        reflectionCamera.transform.SetPositionAndRotation
            (transform.position, transform.rotation);
        reflectionCamera.depth = -10;
        reflectionCamera.enabled = false;
        go.hideFlags = HideFlags.DontSave;

        return reflectionCamera;
    }

    /// <summary>
    /// 更新摄像机
    /// </summary>
    /// <param name="src"></param>
    /// <param name="dest"></param>
    private void UpdateCamera(Camera src, Camera dest)
    {
        if (dest == null) return;

        dest.CopyFrom(src);
        dest.useOcclusionCulling = false;
        if (dest.gameObject.TryGetComponent(out UniversalAdditionalCameraData camData))
        {
            // turn off shadows for the reflection camera
            camData.renderShadows = settings.m_Shadows;
        }
    }

    /// <summary>
    /// 创建反射矩阵
    /// </summary>
    /// <param name="reflectionMat"></param>
    /// <param name="plane"></param>
    private Matrix4x4 CalculateReflectionMatrix(Vector4 plane)
    {
        Matrix4x4 reflectionMat = Matrix4x4.identity;

        reflectionMat.m00 = (1F - 2F * plane[0] * plane[0]);
        reflectionMat.m01 = (-2F * plane[0] * plane[1]);
        reflectionMat.m02 = (-2F * plane[0] * plane[2]);
        reflectionMat.m03 = (-2F * plane[3] * plane[0]);

        reflectionMat.m10 = (-2F * plane[1] * plane[0]);
        reflectionMat.m11 = (1F - 2F * plane[1] * plane[1]);
        reflectionMat.m12 = (-2F * plane[1] * plane[2]);
        reflectionMat.m13 = (-2F * plane[3] * plane[1]);

        reflectionMat.m20 = (-2F * plane[2] * plane[0]);
        reflectionMat.m21 = (-2F * plane[2] * plane[1]);
        reflectionMat.m22 = (1F - 2F * plane[2] * plane[2]);
        reflectionMat.m23 = (-2F * plane[3] * plane[2]);

        reflectionMat.m30 = 0F;
        reflectionMat.m31 = 0F;
        reflectionMat.m32 = 0F;
        reflectionMat.m33 = 1F;

        return reflectionMat;
    }
    
    private float GetScaleValue()
    {
        switch (settings.m_ResolutionMultiplier)
        {
            case ResolutionMulltiplier.Full:
                return 1f;
            case ResolutionMulltiplier.Half:
                return 0.5f;
            case ResolutionMulltiplier.Third:
                return 0.33f;
            case ResolutionMulltiplier.Quarter:
                return 0.25f;
            default:
                return 0.5f; // default to half res
        }
    }
    
    class PlanarReflectionSettingData
    {
        private readonly bool _fog;
        private readonly int _maxLod;
        private readonly float _lodBias;

        public PlanarReflectionSettingData()
        {
            _fog = RenderSettings.fog;
            _maxLod = QualitySettings.maximumLODLevel;
            _lodBias = QualitySettings.lodBias;
        }

        public void Set()
        {
            //进行反转剔除
            GL.invertCulling = true;
            RenderSettings.fog = false; // disable fog for now as it's incorrect with projection
            QualitySettings.maximumLODLevel = 1;
            QualitySettings.lodBias = _lodBias * 0.5f;
        }

        public void Restore()
        {
            GL.invertCulling = false;
            RenderSettings.fog = _fog;
            QualitySettings.maximumLODLevel = _maxLod;
            QualitySettings.lodBias = _lodBias;
        }
    }
}