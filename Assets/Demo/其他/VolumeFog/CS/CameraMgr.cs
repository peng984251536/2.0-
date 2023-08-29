using System;
using UnityEngine;

public class CameraMgr : MonoBehaviour
{
    public float speed = 100.0f;
    
    private float initialRotationY=-1;
    private Camera _camera;
    private Matrix4x4 _PrevViewProjectionMatrix;
    private Matrix4x4 _ViewProjectionMatrix;

    private void OnEnable()
    {
        _camera = this.gameObject.GetComponent<Camera>();
    }

    private void FixedUpdate()
    {
        if(_camera==null)
            return;
        
        if(initialRotationY==-1)
            initialRotationY =  _camera.transform.rotation.eulerAngles.y;
        
        //测试
        // 计算旋转角度
        float targetRotationY = initialRotationY + 
                                30f * Mathf.Sin(Time.time * speed * Mathf.Deg2Rad);
        // 应用旋转
        _camera.transform.rotation = Quaternion.Euler
            (_camera.transform.rotation.eulerAngles.x, targetRotationY, 
                _camera.transform.rotation.eulerAngles.z);

        
        _PrevViewProjectionMatrix = _ViewProjectionMatrix;
        _ViewProjectionMatrix = _camera.projectionMatrix * _camera.worldToCameraMatrix;
        
        Debug.LogFormat("PreVP1:{0}",
            _PrevViewProjectionMatrix);
        Debug.LogFormat("PreVP2:{0}",
            _camera.previousViewProjectionMatrix);
    }
}