

using System;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class GenshipSkyBoxMgr : MonoBehaviour
{
    [Header("_IrradianceMapR Rayleigh Scatter")]
    public Color _upPartSunColor = new Color(0.1000239f, 0.1459537f, 0.3625664f);
    public Color _upPartSkyColor = new Color(0.1041798f, 0.105746f, 0.1888139f);
    public Color _downPartSunColor = new Color(0.8657666f, 0.1706658f, 0.01984066f);
    public Color _downPartSkyColor = new Color(0.4774929f, 0.3099873f, 0.2036164f);
    public Color _upMoonColor = new Color(0.1000239f, 0.1459537f, 0.3625664f);
    [Range(0, 1)]
    public float _IrradianceMapR_maxAngleRange = 0.4586129f;
    
    [Header("_IrradianceMapG Mie Scatter")]
    public Color _SunAdditionColor = new Color(0.975133f, 0.7354551f, 0.3996257f);
    [Range(0, 3)]
    public float _SunAdditionIntensity = 1.206624f;
    [Range(0, 1)]
    public float _IrradianceMapG_maxAngleRange = 0.6607388f;
    [Range(0, 1)]
    public float _mainColorSunGatherFactor = 0.3044474f;
    
    [Header("Sun Disk")] 
    [Range(0, 1000)]
    public float _sun_disk_power_999 = 351.1657f;
    public Color _sun_color = new Color(0.891852f, 0.4535326f, 0.1378029f);
    [Range(0, 10)]
    public float _sun_color_intensity = 1.163067f;
    public Vector2 _sun_atten = new Vector2(0,-0.8f);
    
    [Header("Star")]
    public Color _star_color = new Color(0.891852f, 0.4535326f, 0.1378029f);
    [Range(0, 50)]
    public float _star_color_intensity = 1.163067f;
    public Vector2 _star_mask = new Vector2(0.75f,0.01f);
    public Vector2 _star_mask2 = new Vector2(0,1);
    public Vector3 _star_offset = new Vector3(0,0,0);
    public float _star_scale = 5.0f;

    [Header("cloud setting")]
    [Range(0.05f,1.5f)]
    public float _Cloud_SDF_TSb = 1.0f;

    public float _EdgeIntensity = 1.0f;


    public Material _skyboxMat;
    public Transform _sunTransform;
    public Transform _moonTransform;
    
    //私有变量
    public Vector3 _sun_dir;
    public Vector3 _moon_dir;
    
    private void SetCommonProperties(Material mpb)
    {
        //_IrradianceMapR Rayleigh Scatter
        mpb.SetColor(nameof(_upPartSunColor), _upPartSunColor);
        mpb.SetColor(nameof(_upPartSkyColor), _upPartSkyColor);
        mpb.SetColor(nameof(_downPartSunColor), _downPartSunColor);
        mpb.SetColor(nameof(_downPartSkyColor), _downPartSkyColor);
        mpb.SetColor(nameof(_upMoonColor), _upMoonColor);
        mpb.SetFloat(nameof(_IrradianceMapR_maxAngleRange), _IrradianceMapR_maxAngleRange);
        
        //addLight
        mpb.SetColor(nameof(_SunAdditionColor), _SunAdditionColor);
        mpb.SetFloat(nameof(_SunAdditionIntensity), _SunAdditionIntensity);
        mpb.SetFloat(nameof(_IrradianceMapG_maxAngleRange), _IrradianceMapG_maxAngleRange);
        //sunColorFactor
        mpb.SetFloat(nameof(_mainColorSunGatherFactor), _mainColorSunGatherFactor);
        
        //sun Disk
        mpb.SetFloat(nameof(_sun_disk_power_999), _sun_disk_power_999);
        mpb.SetColor(nameof(_sun_color), _sun_color);
        mpb.SetFloat(nameof(_sun_color_intensity), _sun_color_intensity);
        mpb.SetVector(nameof(_sun_atten), 
            _sun_atten);
        
        //star
        mpb.SetColor(nameof(_star_color), _star_color);
        mpb.SetFloat(nameof(_star_color_intensity), _star_color_intensity);
        mpb.SetVector(nameof(_star_mask), _star_mask);
        mpb.SetVector(nameof(_star_mask2), _star_mask2);
        mpb.SetVector(nameof(_star_offset),_star_offset);
        mpb.SetFloat(nameof(_star_scale),_star_scale);
        
        //moon Disk
        // mpb.SetFloat(nameof(_moon_intensity), _moon_intensity);
        // mpb.SetFloat(nameof(_moon_size), _moon_size);
        // mpb.SetFloat(nameof(_moon_bloom), _moon_bloom);
        // mpb.SetColor(nameof(_moon_color), _moon_color);
        // mpb.SetVector(nameof(_moon_atten), 
        //     _moon_atten);

        mpb.SetVector(nameof(_sun_dir), _sun_dir);
        mpb.SetVector(nameof(_moon_dir), _moon_dir);
    }
    
    
    private void SetCloudProperties(MaterialPropertyBlock mpb)
    {
        mpb.SetFloat(nameof(_Cloud_SDF_TSb), _Cloud_SDF_TSb);
        mpb.SetFloat(nameof(_EdgeIntensity),_EdgeIntensity);
    }

    private void Update()
    {
        Vector3 pos = transform.position;
        if (_sunTransform != null)
        {
            Vector3 sun_dir = (_sunTransform.position - pos).normalized;
            _sun_dir = sun_dir;
        }

        if (_moonTransform != null)
        {
            Vector3 moon_dir = (_moonTransform.position - pos).normalized;
            _moon_dir = moon_dir;
        }
        
        //批量给天空盒提供参数
        if(_skyboxMat!=null)
        {
            SetCommonProperties(_skyboxMat);
        }
    }


}