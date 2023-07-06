Shader "URP/CopyOpauqeShader"
{
    Properties
    {
        _SourceTex("SourceTex",2D) = "while"{}
    }

    Subshader
    {
        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward" "RenderType" = "Opaque" "Queue" = "Geometry"
            }

            //Blend SrcAlpha OneMinusSrcAlpha
            ZTest Off
            ZWrite Off
            ZTest LEqual
            Cull Back

//            Stencil
//            {
//                Ref[_SRef]
//                Comp[_SComp]
//                Pass[_SOp]
//                Fail keep
//                ZFail keep
//            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex: POSITION;
                float3 normal:NORMAL;
                float2 uv :TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex: SV_POSITION;
                float2 uv:TEXCOORD0;
            };

            TEXTURE2D(_SourceTex);
            SAMPLER(sampler_SourceTex);
            float4 _SourceTex_ST;

            v2f vert(appdata v)
            {
                v2f o;
                //v.vertex.xyz += _Width * normalize(v.vertex.xyz);

                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _SourceTex);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                float4 tex = SAMPLE_TEXTURE2D(_SourceTex, sampler_SourceTex, i.uv);

                return float4(tex.rgb, 1);
            }
            ENDHLSL
        }
    }
}