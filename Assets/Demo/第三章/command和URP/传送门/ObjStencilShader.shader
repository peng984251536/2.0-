Shader "3/ObjStencilShader"
{
    Properties
    {

        _SRef("Stencil Ref", Float) = 3
        [Enum(UnityEngine.Rendering.CompareFunction)] _SComp("Stencil Comp", Float) = 6
        [Enum(UnityEngine.Rendering.StencilOp)] _SOp("Stencil Op", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZComp("Depth Comp", Float) = 6
    }

    Subshader
    {
//        Pass
//        {
//            Tags
//            {
//                "LightMode" = "SRPDefaultUnlit"
//                "RenderType" = "Geometry"
//            }
//            ZTest LEqual
//            ZWrite On
//            ColorMask 0
//            Cull Back
//        }
        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
                "RenderType" = "Geometry"
            }

            ColorMask 0
            //Blend SrcAlpha OneMinusSrcAlpha
            //Blend SrcColor Zero
            ZTest On
            ZWrite Off
            ZTest [_ZComp]
            Cull Back

            Stencil
            {
                Ref[_SRef]
                Comp[_SComp]
                Pass[_SOp]
                Fail keep
                ZFail keep
            }

//            HLSLPROGRAM
//            #pragma vertex vert
//            #pragma fragment frag
//
//            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
//
//            TEXTURE2D(_MyOpauqeTexture);
//            SAMPLER(sampler_MyOpauqeTexture);
//
//            struct appdata
//            {
//                float4 vertex: POSITION;
//                float3 normal:NORMAL;
//            };
//
//            struct v2f
//            {
//                float4 vertex: SV_POSITION;
//            };
//
//            v2f vert(appdata v)
//            {
//                v2f o;
//                o.vertex = TransformObjectToHClip(v.vertex.xyz);
//                return o;
//            }
//
//            half4 frag(v2f i) : SV_Target
//            {
//                //half2 screenUV = (i.vertex.xy / _ScreenParams.xy);
//                //float3 sum = SAMPLE_TEXTURE2D(_MyOpauqeTexture, sampler_MyOpauqeTexture, screenUV).rgb;
//                //return float4(sum,1);
//                return 1;
//            }
//            ENDHLSL
        }
    }
}