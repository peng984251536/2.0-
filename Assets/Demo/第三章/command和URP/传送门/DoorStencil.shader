Shader "3/DoorStencil"
{
    Properties
    {
        _MainTex("MainTex",2D) = "while"{}
        _BaseColor("outline color",color) = (1,1,1,1)
        _Alpha("_Alpha",float) = 1

        _SRef("Stencil Ref", Float) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _SComp("Stencil Comp", Float) = 8
        [Enum(UnityEngine.Rendering.StencilOp)] _SOp("Stencil Op", Float) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZComp("Depth Comp", Float) = 6
    }

    Subshader
    {
        Tags
        {
            "Queue" = "Geometry"
        }
        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
                "RenderType" = "Geometry"
            }

            //Blend SrcAlpha OneMinusSrcAlpha
            //Blend DstColor Zero
            ColorMask 0 
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

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;
            half4 _BaseColor;
            float _Alpha;

            v2f vert(appdata v)
            {
                v2f o;
                //v.vertex.xyz += _Width * normalize(v.vertex.xyz);

                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                float4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                return float4(tex.rgb * _BaseColor.rgb, _Alpha);
            }
            ENDHLSL
        }
    }
}