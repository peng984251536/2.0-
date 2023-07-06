using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;

[ExecuteInEditMode]
public class ClickObjectBloom : MonoBehaviour, IPointerDownHandler, IPointerUpHandler
{
    private int _defalutLayer;
    
    //初始的渲染层级
    private uint _DefalutRenderLayer;

    //点击时变化的层级
    public uint _renderLayer;
    
    
    void Start()
    {
        _DefalutRenderLayer = GetComponent<Renderer>().renderingLayerMask;
        Debug.Log("default layer:"+_DefalutRenderLayer);
    }

    public void OnPointerDown(PointerEventData eventData)
    {
        GetComponent<Renderer>().renderingLayerMask = ((uint) ( _renderLayer));
        Debug.Log("change layer:"+_renderLayer);
    }

    public void OnPointerUp(PointerEventData eventData)
    {
        GetComponent<Renderer>().renderingLayerMask = _DefalutRenderLayer;
        Debug.Log("back layer:"+_DefalutRenderLayer);
    }
}