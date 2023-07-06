using System;
using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using UnityEngine.Experimental.GlobalIllumination;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Experimental.Rendering;


[ExecuteAlways]
public class DecalShadowManager : MonoBehaviour
{
    // Singleton
    private static DecalShadowManager _instance;

    public static DecalShadowManager Instance
    {
        get
        {
            if (_instance == null)
                _instance = (DecalShadowManager) FindObjectOfType(typeof(DecalShadowManager));
            return _instance;
        }
    }
    
    //属性变量
    public Color shadowColor = Color.white;
    [Range(0,1)]
    public float alpahParams = 1.0f;

    public float distance = 100f;
    public GameObject Cube;
    private static readonly int _VPMatrix_invers = Shader.PropertyToID("_VPMatrix_invers");
    public GameObject lightGameObj;
    
    private void OnEnable()
    {
        RenderPipelineManager.beginCameraRendering += UpdateParams;
    }
    
    /// <summary>
    /// 关闭激活时
    /// </summary>
    private void OnDisable()
    {
        RenderPipelineManager.beginCameraRendering -= UpdateParams;
    }

    // private void Start()
    // {
    //     throw new NotImplementedException();
    // }


    // private void Update()
    // {
    //     throw new NotImplementedException();
    // }

    private void UpdateParams(ScriptableRenderContext src, Camera cam)
    {


        Camera _cam = cam;
        Matrix4x4 vp_Matrix = cam.projectionMatrix * cam.worldToCameraMatrix;
        Shader.SetGlobalMatrix(_VPMatrix_invers, vp_Matrix.inverse);
        Matrix4x4 v_Matrix = cam.worldToCameraMatrix;
        Shader.SetGlobalMatrix("_VMatrix", v_Matrix);
        Matrix4x4 p_Matrix = cam.projectionMatrix;
        Shader.SetGlobalMatrix("_PMatrix", p_Matrix);
        
        Shader.SetGlobalColor("_shadowColor",shadowColor);
        Shader.SetGlobalFloat("_alpahParams",alpahParams);

        if (Cube == null)
            return;
        
        Light _directionalLight = GameObject.Find("Directional Light").GetComponent<Light>();
        Vector3 Light_dir = new Vector3(
            _directionalLight.transform.forward.x,
            0,
            _directionalLight.transform.forward.z
            ) ;
        Light_dir.Normalize();
        Vector3 newPos = Cube.transform.position + Light_dir * (-1.0f * distance);
        
        Vector3 up_dir = Vector3.up;
        up_dir.Normalize();
        Vector3 left_dir = Vector3.Cross(Light_dir,up_dir);
        left_dir.Normalize();
        if (lightGameObj == null)
        {
            lightGameObj = new GameObject("LightGameObj");
            
        }
        Debug.Log("distance: "+Vector2.Distance(
            new Vector2(newPos.x,newPos.z),
            new Vector2(Cube.transform.position.x,Cube.transform.position.z)));
        newPos.y = _directionalLight.transform.position.y;
        lightGameObj.transform.position = newPos;


        Matrix4x4 worldToLight = new Matrix4x4();
        // worldToLight.SetColumn(0,Light_dir);
        // worldToLight.SetColumn(1,up_dir);
        // worldToLight.SetColumn(2,left_dir);
        // worldToLight.SetColumn(3,new Vector4(0,0,0,1));
        worldToLight.SetRow(0,Light_dir);
        worldToLight.SetRow(1,up_dir);
        worldToLight.SetRow(2,left_dir);
        worldToLight.SetRow(3,new Vector4(1,1,1,1));
        
        //Vector3 newPos2 = 


        Shader.SetGlobalMatrix("_worldToLight",worldToLight);
        Shader.SetGlobalMatrix("_worldToLight_inv",worldToLight.inverse);
        Shader.SetGlobalVector("_LightPos",newPos);
        Shader.SetGlobalFloat("_distance",distance);
        
        

        //material.SetTexture(s_NoiseMapID, m_CurrentSettings.noiseMap);
    }
}