using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

public enum ScreenPiex
{
    Number2048 = 2048,
    Number1024 = 1024,
    Number512 = 512
}

[ExecuteAlways]
public class CharShadowManager : MonoBehaviour
{
    public class CharInfo
    {
        public SkinnedMeshRenderer mesh;
        public MaterialPropertyBlock mat;
        public Matrix4x4 _LightMatrix;
        public Vector3 lightPos;
    }
    
    
    [Range(0,10)]
    public float _ShadowRampVal = 0.5f;
    public float _ShadowRampWith = 4.0f;
    public Vector3 _Offset = new Vector3(0, 0.72f, 0);
    public float _ShadowDistance = 3.0f;
    public ScreenPiex screenPiex = ScreenPiex.Number1024;
    //public Texture2D _GradientTex;
    public Light mainDirectionalLight;
    public List<SkinnedMeshRenderer> _CharacterList = new List<SkinnedMeshRenderer>(4);
    
    [HideInInspector]
    public List<CharInfo> _CharInfoList;
    //这个类如何多次创建的话会报错
    [HideInInspector]
    public static CharShadowManager Instance = null;

    [FormerlySerializedAs("_DebugParams")] public Vector4 _ShadowDebugParams;
    private void Awake()
    {
    }

    private void Start()
    {
        Instance = this;
    }

    //生命周期分帧渲染
    private void Update()
    {
        if (Instance == null)
            Instance = this;
        Shader.SetGlobalVector(nameof(_ShadowDebugParams),_ShadowDebugParams);
        if (_CharacterList == null)
            return;
        UpdateList();
        for (int i = 0; i < _CharacterList.Count; i++)
        {
            //给角色的MaterialPropertyBlock设置参数
            SkinnedMeshRenderer mesh = _CharacterList[i];
            Vector3 pos = mesh.transform.position;
            Vector3 lightPos;
            Matrix4x4 m = UpdateMainLight(pos+_Offset, _ShadowDistance, out lightPos);
            _CharInfoList[i]._LightMatrix = m;
            _CharInfoList[i].lightPos = lightPos;
            MaterialPropertyBlock mat = _CharInfoList[i].mat;
            mat.SetMatrix("_LightPro_Matrix", m);
            
            mesh.SetPropertyBlock(mat);
        }

        Shader.SetGlobalFloat(nameof(_ShadowDistance), _ShadowDistance);
        Shader.SetGlobalVector("_MainLightDir", -mainDirectionalLight.transform.forward);
        
        Shader.SetGlobalMatrix("_LightPro_Matrix",_CharInfoList[0]._LightMatrix);
        Shader.SetGlobalMatrix("_LightPro_Matrix_invers",_CharInfoList[0]._LightMatrix.inverse);
        Shader.SetGlobalVector("_LightPosWS", _CharInfoList[0].lightPos);

        Shader.SetGlobalFloat(nameof(_ShadowRampVal),_ShadowRampVal);
        //Shader.SetGlobalTexture(nameof(_GradientTex),_GradientTex);
    }

    private Matrix4x4 UpdateMainLight(Vector3 pos, float dis,out Vector3 lightPos)
    {
        Vector3 dir_z = -mainDirectionalLight.transform.forward;
        Vector3 dir_y = mainDirectionalLight.transform.up;
        Vector3 dir_x = mainDirectionalLight.transform.right;

        //位置
        Matrix4x4 lightMatrixMove = new Matrix4x4();
        lightMatrixMove.SetRow(0, new Vector4(1, 0, 0, -dir_z.x * dis - pos.x));
        lightMatrixMove.SetRow(1, new Vector4(0, 1, 0, -dir_z.y * dis - pos.y));
        lightMatrixMove.SetRow(2, new Vector4(0, 0, 1, -dir_z.z * dis - pos.z));
        lightMatrixMove.SetRow(3, new Vector4(0, 0, 0, 1));
        lightPos = new Vector3(lightMatrixMove.m03,lightMatrixMove.m13,lightMatrixMove.m23);
        // float4x4 matrix_move = float4x4
        // (
        //     1, 0, 0, -newPosWS.x + lightDir.x * _ShadowDistance,
        //     0, 1, 0, -newPosWS.y + lightDir.y * _ShadowDistance,
        //     0, 0, 1, -newPosWS.z + lightDir.z * _ShadowDistance,
        //     0, 0, 0, 1
        // );
        //光线方向
        Matrix4x4 lightMatrixRotate = new Matrix4x4();
        lightMatrixRotate.SetRow(0, TransV4(dir_x));
        lightMatrixRotate.SetRow(1, TransV4(dir_y));
        lightMatrixRotate.SetRow(2, TransV4(dir_z));
        lightMatrixRotate.SetRow(3, new Vector4(0, 0, 0, 1));
        //Shader.SetGlobalMatrix("_LightRotateMatrix", lightMatrix);
        //正交投影
        float aspect = ((float)Screen.width / (float)Screen.height);
        aspect = 1;
        float size = 2.7f;
        float near = 0.1f;
        float far = 20.0f;
        Matrix4x4 lightMatrixClip = new Matrix4x4();
        lightMatrixClip.SetRow(0, new Vector4(1 / (aspect * size), 0, 0, 0));
        lightMatrixClip.SetRow(1, new Vector4(0, -1 / size, 0, 0));
        lightMatrixClip.SetRow(2, new Vector4(0, 0, 2 / (far - near), (far + near) / (far - near)));
        lightMatrixClip.SetRow(3, new Vector4(0, 0, 0, 1));
        //Shader.SetGlobalMatrix("_LightClipMatrix", lightMatrix2);

        return lightMatrixClip * lightMatrixRotate * lightMatrixMove;
    }

    public Vector4 TransV4(Vector3 v3)
    {
        return new Vector4(v3.x, v3.y, v3.z, 0);
    }

    public void UpdateList()
    {
        if (_CharInfoList == null)
            _CharInfoList = new List<CharInfo>(4);
        
        if (_CharacterList.Count == _CharInfoList.Count)
            return;
        _CharInfoList.Clear();
        for (int i = 0; i < _CharacterList.Count; i++)
        {
            CharInfo info = new CharInfo();
            info.mat = new MaterialPropertyBlock();
            info.mesh = _CharacterList[i];
            info._LightMatrix = new Matrix4x4();
            _CharInfoList.Add(info);
        }
    }
}