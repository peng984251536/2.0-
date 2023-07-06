Shader "5/URPShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _seaColor("SeaColor",Color) = (0,0,0,0)
        _reflectionColor("ReflectionColor",Color) = (0,0,0,0)
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
            ZTest On
            ZWrite On
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(Sampler_CameraOpaqueTexture);
            TEXTURE2D(_PlanarReflectionTexture);
            SAMPLER(sampler_PlanarReflectionTexture);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 screenPos : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _seaColor;
            float4 _reflectionColor;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.screenPos = ComputeScreenPos(o.vertex);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                // sample the texture
                float3 col = SAMPLE_TEXTURE2D(_PlanarReflectionTexture, sampler_PlanarReflectionTexture,
                                             i.screenPos.xy / i.screenPos.w).rgb;
                float3 finalColor = lerp(col, _reflectionColor, col.r);
                return float4(finalColor,1);
            }
            ENDHLSL
        }
    }
}