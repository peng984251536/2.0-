using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class ToneRenderSetting : MonoBehaviour
{
    [Serializable]
    public enum DebugLog
    {
        IBL_R,
        IBL_G,
        IBL_B,
        IBL_A,
        BaseColor,
    }

    public DebugLog debugLogState = DebugLog.IBL_A;
    public MeshRenderer debugMesh;

    // Start is called before the first frame update
    void Start()
    {
    }

    // Update is called once per frame
    void Update()
    {
        DebugMeshFunction();
    }

    private MaterialPropertyBlock _block;
    public void DebugMeshFunction()
    {
        if (_block == null)
        {
            _block = new MaterialPropertyBlock();
        }
        if (debugMesh == null)
            return;
        switch (debugLogState)
        {
            case DebugLog.IBL_A:
                _block.SetFloat("_DebugLog",4);
                break;
            case DebugLog.IBL_R:
                _block.SetFloat("_DebugLog",1);
                break;
            case DebugLog.IBL_G:
                _block.SetFloat("_DebugLog",2);
                break;
            case DebugLog.IBL_B:
                _block.SetFloat("_DebugLog",3);
                break;
            default:
                _block.SetFloat("_DebugLog",0);
                break;
        }
        _block.SetFloat("_EdgeWidth",0);
        debugMesh.SetPropertyBlock(_block);
    }
}