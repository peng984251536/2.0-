using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[System.Serializable]
public class HBAORenderSettings
{
    //ao强度
    [Range(0.0f, 5.0f)] public float intensity = 1.0f;
    //射线半径
    [Range(0.25f, 5.0f)] public float radius = 1.2f;
    //最大半径的像素数量
    [Range(0f, 255)] public float maxRadiusPixels = 50;
    //角度阈值
    [Range(0.0f, 0.5f)] public float angleBias = 0.05f;
    // //AO衰减距离
     [Min(0)] public float distanceFalloff = 50.0f;
    //模糊深度权重
    [Range(0.0f,16.0f)] public float sharpness = 8.0f;
    
    //测试用
    public bool isMyMatrixParmas = false;
}