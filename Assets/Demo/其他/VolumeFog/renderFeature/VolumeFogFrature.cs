using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Scripting.APIUpdating;
using UnityEngine.Serialization;


[ExcludeFromPreset]
[MovedFrom("UnityEngine.Experimental.Rendering.LWRP")]
public class VolumeFogFrature : ScriptableRendererFeature
{
    [System.Serializable]
    public class lightMarchSettings
    {
        //lightMarchSettings
        public int _numStepsLight = 10;
        [Range(-2,2)]
        public float _lightAbsorptionTowardSun = 1.0f;
        [Range(-2,2)]
        public float _darknessThreshold = 1.0f;
        [Range(-2,2)]
        public float _lightMarchScale = 1.0f;

        public float _lightMarchStep = 2.0f;
        public Vector4 _phaseParams = new Vector4(1,1,1,1);
    }
    
    [System.Serializable]
    public class Shape2Settings
    {
        //shapeParams
        public Texture2D _shape2NoiseTex;
        public Vector3 _shape2Scale = new Vector3(1,1,1);
        public Vector3 _shape2Offset = new Vector3(0, 0, 0);
        
        [Range(-2,2)]
        public float _smoothMin2 = 0.0f;
        [Range(-2,2)]
        public float _smoothMax2 = 1.0f;
    }
    
    [System.Serializable]
    public class ShapeSettings
    {
        //shapeParams
        public Vector3 _shapeScale = new Vector3(1,1,1);
        public Vector3 _shapeOffset = new Vector3(0, 0, 0);
        public Vector4 _shapeNoiseWeights = new Vector4(5, 5, 5, 5);
    }
    
    [System.Serializable]
    public class DetailSettings
    {
        //detalParams
        public Texture3D _DetailNoiseTex;
        public Vector3 _detailNoiseScale = new Vector3(1,1,1);
        public Vector3 _detailOffset = new Vector3(0, 0, 0);
        public float _detailSpeed = 0.0f;
        public Vector2 _smoothVal = new Vector2(0,1);
    }

    [System.Serializable]
    public class NoiseSettings
    {
        public Shader VolemeFog_Shader;
        public Texture3D noiseTex;
        public Texture2D blueNoiseTex;
        public float blueSize;
        public float rayOffsetStrength = 1.0f;
        public Transform bounds;

        [FormerlySerializedAs("_timeScale")] [Header("--------------")] 
        //[Range(0,100)]
        public float _RayStepScale = 1.0f;
        [Range(0,10)]
        public float _baseSpeed = 1.33f;
        
        [Header("--------------")] 
        [Range(-2,2)]
        public float _smoothMin = 0.0f;
        [Range(-2,2)]
        public float _smoothMax = 1.0f;
        public Vector2 _noiseModelVal = new Vector2(0,1);
    }
    private VolumeFogPass pass;
    public Material volemeFog;
    [Range(1,10)]
    public float downsampleDivider = 0.8f;
    [Header("--------------")] 
    public ShapeSettings _shapeSettings = new ShapeSettings();
    public NoiseSettings _noiseSettings = new NoiseSettings();
    public DetailSettings _DetailSettings = new DetailSettings();
    public Shape2Settings _Shape2Settings = new Shape2Settings();
    public lightMarchSettings _LightMarchSettings = new lightMarchSettings();

    [Header("------bilateralParams--------")]
    public Vector4 _bilateralParams = new Vector4(1, 1, 1, 1);

    [Header("------windSetting--------")] 
    public Vector3 windDir = new Vector3(0, 0, 0);

    public Vector3 windSpeed = new Vector3(1.0f,1,1);
    public float _timeScale = 0.1f;
    

    public override void Create()
    {
        // if (_noiseSettings.VolemeFog_Shader != null&&volemeFog != null)
        //     volemeFog = new Material(_noiseSettings.VolemeFog_Shader);

        if (volemeFog != null&&pass==null)
        {
            pass = new VolumeFogPass(name, _shapeSettings, _noiseSettings, volemeFog);
        }
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (_noiseSettings.bounds == null)
        {
            _noiseSettings.bounds = GameObject.Find("CloudBounds").transform;
            if (_noiseSettings.bounds == null)
                return;
        }

        if (_noiseSettings.noiseTex == null)
            return;

        pass.downsampleDivider = this.downsampleDivider;
        Shader.SetGlobalTexture("_NoiseTex", _noiseSettings.noiseTex);
        Shader.SetGlobalTexture("_blueNoiseTex", _noiseSettings.blueNoiseTex);
        Shader.SetGlobalFloat("_blueSize", _noiseSettings.blueSize);

        Vector3 pos = _noiseSettings.bounds.gameObject.transform.position;
        Vector3 boundMin = pos - _noiseSettings.bounds.gameObject.transform.localScale * 0.5f;
        Vector3 boundMax = pos + _noiseSettings.bounds.gameObject.transform.localScale * 0.5f;

        Shader.SetGlobalVector("_boundsMin", boundMin);
        Shader.SetGlobalVector("_boundsMax", boundMax);
        Shader.SetGlobalFloat("_rayOffsetStrength", _noiseSettings.rayOffsetStrength);

        //--------------shape--------------//
        Shader.SetGlobalVector("_shapeScale", _shapeSettings._shapeScale);
        Shader.SetGlobalVector("_shapeOffset", _shapeSettings._shapeOffset);
        Shader.SetGlobalVector("_shapeNoiseWeights", _shapeSettings._shapeNoiseWeights);

        //--------------noise--------------//
        Shader.SetGlobalFloat("_RayStepScale", _noiseSettings._RayStepScale);
        Shader.SetGlobalFloat("_baseSpeed", _noiseSettings._baseSpeed);
        Shader.SetGlobalFloat("_smoothMin", _noiseSettings._smoothMin);
        Shader.SetGlobalFloat("_smoothMax", _noiseSettings._smoothMax);
        Shader.SetGlobalVector("_noiseModelVal", _noiseSettings._noiseModelVal);
        
        //--------------shape2--------------//
        Shader.SetGlobalTexture("_shape2NoiseTex", _Shape2Settings._shape2NoiseTex);
        Shader.SetGlobalVector("_shape2Scale", _Shape2Settings._shape2Scale);
        Shader.SetGlobalVector("_shape2Offset", _Shape2Settings._shape2Offset);
        Shader.SetGlobalFloat("_smoothMin2", _Shape2Settings._smoothMin2);
        Shader.SetGlobalFloat("_smoothMax2", _Shape2Settings._smoothMax2);
        
        //----------detail--------------//
        Shader.SetGlobalTexture("_DetailNoiseTex",_DetailSettings._DetailNoiseTex);
        Shader.SetGlobalVector("_detailNoiseScale", _DetailSettings._detailNoiseScale);
        Shader.SetGlobalVector("_detailOffset", _DetailSettings._detailOffset);
        Shader.SetGlobalFloat("_detailSpeed", _DetailSettings._detailSpeed);
        Shader.SetGlobalVector("_smoothVal", _DetailSettings._smoothVal);

        //-------lightMarch------------//
        Vector4 lightMarchParams = new Vector4
            (
                _LightMarchSettings._numStepsLight,
                _LightMarchSettings._lightAbsorptionTowardSun,
                _LightMarchSettings._darknessThreshold,
                _LightMarchSettings._lightMarchScale
                );
        Shader.SetGlobalVector("_lightMarchParams", lightMarchParams);
        Shader.SetGlobalFloat("_lightMarchStep", _LightMarchSettings._lightMarchStep);
        Shader.SetGlobalVector("_phaseParams", _LightMarchSettings._phaseParams);
        Shader.SetGlobalVector("_bilateralParams",_bilateralParams);
        
        //----wind-----//
        Shader.SetGlobalVector("_windDir", windDir.normalized);
        Shader.SetGlobalVector("_windSpeed", windSpeed);
        Shader.SetGlobalFloat("_timeScale", _timeScale);

        if (pass != null)
            renderer.EnqueuePass(pass);
    }
}