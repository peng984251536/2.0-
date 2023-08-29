using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

[System.Serializable]
public class TemporalMgr
{
    private HaltonSequenceGenerator _haltonSequenceGenerator;
    [SerializeField]
    private Vector2[] haltons;
    RenderTexture[] historyBuffer;
    private int x=2;
    private int y=3;
    private int _FrameCount = 0;

    public RenderTextureDescriptor m_Descriptor;
    public float haltonScale = 1.0f;
    public float TScale = 1;
    [Range(0,1)]
    public float TResponse = 0.875f;
    public bool IsUpdate = false;


    // private Matrix4x4 _PrevViewProjectionMatrix;
    // private Matrix4x4 _ViewProjectionMatrix;
    
    public TemporalMgr()
    {
        _haltonSequenceGenerator = new HaltonSequenceGenerator();
        ResetHalton(x,y);
    }

    public void ResetHalton(int x ,int y)
    {
        haltons = _haltonSequenceGenerator.GenerateHaltonSequence(64, x, y);
    }

    // public void SetMatrix(Camera camera)
    // {
    //     _PrevViewProjectionMatrix = _ViewProjectionMatrix;
    //     _ViewProjectionMatrix = camera.projectionMatrix * camera.worldToCameraMatrix;
    //     
    //     // Debug.LogFormat("PreVP1:{0}",
    //     //     _PrevViewProjectionMatrix);
    //     // Debug.LogFormat("PreVP2:{0}",
    //     //     camera.previousViewProjectionMatrix);
    // }

    /// <summary>
    /// 
    /// </summary>
    /// <param name="cmd"></param>
    /// <param name="renderingData"></param>
    public void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData,RenderTextureDescriptor descriptor)
    {
        if (IsUpdate)
        {
            haltons = _haltonSequenceGenerator.GenerateHaltonSequence(64, 2, 3);
            IsUpdate = false;
        }

        m_Descriptor = descriptor;
        //设置扰动因子
        Vector2 halton = GetHaltonVector2();
        //Debug.Log(halton);
        cmd.SetGlobalVector("_haltonVector2",halton);
        cmd.SetGlobalFloat("_haltonScale",haltonScale);
        cmd.SetGlobalFloat("_TScale",TScale);
        cmd.SetGlobalFloat("_TResponse",TResponse);
    }

    public Vector2 GetHaltonVector2()
    {
        Vector2 halton = haltons[Time.frameCount % 64];
        halton = (halton - new Vector2(0.5f,0.5f))*2;
        return halton;
    }
    
    public RenderTargetIdentifier Execute(CommandBuffer cmd,RenderTargetIdentifier curRT,
        Material material,int PassID)
    {
        //历史帧
        EnsureArray(ref historyBuffer, 2);
        EnsureRenderTarget(ref historyBuffer[0], m_Descriptor.width, m_Descriptor.height, m_Descriptor.colorFormat, FilterMode.Bilinear);
        EnsureRenderTarget(ref historyBuffer[1], m_Descriptor.width, m_Descriptor.height, m_Descriptor.colorFormat, FilterMode.Bilinear);
        
        int indexRead = indexWrite;
        indexWrite = (++indexWrite) % 2;
        
        cmd.SetGlobalTexture("_CurTexture",curRT);
        cmd.SetGlobalTexture("_PreTexture",historyBuffer[indexRead]);
        cmd.Blit(curRT,historyBuffer[indexWrite],material,PassID);
        //cmd.Blit(m_VolumeFogRT,m_PreTexture);//拷贝
        //cmd.Blit(m_PreTexture,camerRT);//测试

        return historyBuffer[indexWrite];
    }
    
    #region Temporal扰动相关代码
    
    static int indexWrite = 0;
    
    internal void Clear()
    {
        if(historyBuffer!=null)
        {
            ClearRT(ref historyBuffer[0]);
            ClearRT(ref historyBuffer[1]);
            historyBuffer = null;
        }
    }
    
    void ClearRT(ref RenderTexture rt)
    {
        if(rt!= null)
        {
            RenderTexture.ReleaseTemporary(rt);
            rt = null;
        }
    }
    
    void EnsureArray<T>(ref T[] array, int size, T initialValue = default(T))
    {
        if (array == null || array.Length != size)
        {
            array = new T[size];
            for (int i = 0; i != size; i++)
                array[i] = initialValue;
        }
    }
    
    bool EnsureRenderTarget(ref RenderTexture rt, int width, int height, RenderTextureFormat format, FilterMode filterMode, int depthBits = 0, int antiAliasing = 1)
    {
        if (rt != null && (rt.width != width || rt.height != height || rt.format != format || rt.filterMode != filterMode || rt.antiAliasing != antiAliasing))
        {
            RenderTexture.ReleaseTemporary(rt);
            rt = null;
        }
        if (rt == null)
        {
            rt = RenderTexture.GetTemporary(width, height, depthBits, format, RenderTextureReadWrite.Default, antiAliasing);
            rt.filterMode = filterMode;
            rt.wrapMode = TextureWrapMode.Clamp;
            rt.name = "_History" + indexWrite;
            return true;// new target
        }
        return false;// same target
    }

    #endregion
}