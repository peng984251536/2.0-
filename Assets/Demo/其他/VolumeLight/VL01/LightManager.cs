using System;
using System.Collections;
using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Experimental.GlobalIllumination;
using LightType = UnityEngine.LightType;

[ExecuteInEditMode]
public class LightManager : MonoBehaviour
{
    [Range(0, 2)] public float attenIntH = 0.5f;
    [Range(1, 5)] public float attenIntV = 1.0f;
    public GameObject maskMesh;

    public Light spotlight;
    private bool IsOpen = false;
    private GameObject mask_go;

    public GameObject Test01;
    public GameObject Test02;

    public Vector2 val = Vector2.one;

    // Start is called before the first frame update
    void Start()
    {
        if (spotlight == null || spotlight.type != LightType.Spot)
        {
            Light[] lights = GetComponents<Light>();
            for (int i = 0; i < lights.Length; i++)
            {
                if (lights[i].type == LightType.Spot)
                {
                    spotlight = lights[i];
                    break;
                }
            }
        }

        IsOpen = false;
    }

    // Update is called once per frame
    void Update()
    {
        if(spotlight==null)
            return;
        GetSpotParams();
    }

    private void GetSpotParams()
    {
        // 获取聚光灯组件
        // 获取聚光灯的位置
        Vector3 position = spotlight.transform.position;
        // 获取聚光灯的方向
        Vector3 direction = spotlight.transform.forward.normalized;
        // 获取聚光灯的内锥角和外锥角
        float innerAngle = spotlight.innerSpotAngle;
        float outerAngle = spotlight.spotAngle;
        // 获取聚光灯的范围
        float range = spotlight.range * 1.0f;
        // 获取聚光灯的强度
        float intensity = spotlight.intensity;
        //远端半径
        float rb = Mathf.Tan(outerAngle * 0.5f * Mathf.Deg2Rad) * range;
        //远端位置
        Vector3 position2 = position + direction * (range);
        

        //PrintLine(position,position2);

        if (Test01 != null)
            Test01.transform.position = position;
        if (Test02 != null)
            Test02.transform.position = position2;
        if (mask_go == null)
            mask_go = Instantiate(maskMesh, spotlight.transform, true);
        mask_go.transform.up = direction;
        mask_go.transform.localScale = new Vector3(rb * 2, range / 2, rb * 2);
        mask_go.transform.position = (position + position2) / 2;

        Matrix4x4 scaleMatrix = Matrix4x4.Scale(new Vector3(1, 0.5f, 1));
        Matrix4x4 moveMatrix = Matrix4x4.Translate(new Vector3(0, 0.5f, 0));


        Shader.SetGlobalVector("_ConeAParams", new Vector4(position.x, position.y, position.z, 0));
        Shader.SetGlobalVector("_ConeBParams", new Vector4(position2.x, position2.y, position2.z, rb));
        Shader.SetGlobalColor("_VolumeLightColor", spotlight.color);
        Shader.SetGlobalVector("_VolumeLightParams",
            new Vector4(
                math.radians(innerAngle * 0.5f),
                math.radians(outerAngle * 0.5f),
                attenIntV,
                attenIntH
            )
        );
        Shader.SetGlobalVector("_VolumeLightDir",
            new Vector4(
                direction.x,
                direction.y,
                direction.z,
                0
            ));

        // 打印聚光灯参数
        //Debug.Log("Rb: " + rb);RenderObject
        // Debug.Log("Direction: " + direction);
        // Debug.Log("Inner Angle: " + innerAngle);
        //Debug.Log("Outer Angle: " + outerAngle);
        // Debug.Log("Range: " + range);
        // Debug.Log("Intensity: " + intensity);
    }

    public void PrintLine(Vector3 position,Vector3 position2)
    {
        //绘制箭头
        DirTest dirTest = this.gameObject.GetComponent<DirTest>();
        if (dirTest == null)
        {
            dirTest = this.gameObject.AddComponent<DirTest>();
        }
        dirTest.SetDrawLine(position, position2);
    }
    
    
}