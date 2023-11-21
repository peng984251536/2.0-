using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GradientGenerator : MonoBehaviour
{
    public Gradient grad;
    public Texture2D tex;

    private void OnValidate()
    {
        //创建一张纹理图
        tex = new Texture2D(128, 1);
        tex.wrapMode = TextureWrapMode.Clamp;
        tex.filterMode = FilterMode.Bilinear;
        int count = tex.width * tex.height;
        Color[] cols = new Color[count];
        for (int i = 0; i < count; i++)
        {
            cols[i] = grad.Evaluate((float)i / count);
        }
        
        //把颜色应用到纹理上
        tex.SetPixels(cols);
        tex.Apply();
        //全局赋值
        Shader.SetGlobalTexture("_GradientTex",tex);
    }

}
