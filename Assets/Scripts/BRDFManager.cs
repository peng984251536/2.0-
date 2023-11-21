using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class BRDFManager : MonoBehaviour
{
    [SerializeField]
    private Texture2D ibl_brdf_lut;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (ibl_brdf_lut != null)
        {
            Shader.SetGlobalTexture("_LUTTex",ibl_brdf_lut);
        }
    }
}
