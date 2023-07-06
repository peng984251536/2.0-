


using UnityEngine;

[System.Serializable]
public partial class SurfaceRenderSetting
{
    //含有所需SpriteRenderer的prefab
    public SpriteRenderer RendererPrefab;
    private SpriteRenderer _rendererInstance;
    public SpriteRenderer RendererInstance
    {
        get
        {
            if (!_rendererInstance)
            {
                if (RendererPrefab)
                {
                    _rendererInstance = Object.Instantiate(RendererPrefab);
                }
            }
            return _rendererInstance;
        }
    }
    //旋转偏移
    private Vector3 _rotationOffset = Vector3.right * 90;
    //渲染的Transform
    public Vector3 Position;
    public Quaternion Rotation;
    public Vector3 Size;
    public Vector3 Offset = Vector3.zero;
    public void SetDataFromTransform(Transform transform)
    {
        Position = transform.position;
        Rotation = transform.rotation;
        Quaternion quaternion = Quaternion.Euler(_rotationOffset);
        //Rotation *= Quaternion.Inverse(Rotation) * quaternion * this.Rotation;
        Rotation *= quaternion;
        var scale = transform.lossyScale;
        Size = scale;
        Size.y = 0;
    }
}