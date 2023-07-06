Shader "URP/URPShader"
{
    Properties
    {
        _MainTex("MainTex",2D) = "while"{}
        _BaseColor("BaseColor",color) = (1,1,1,1)
        [HDR]_BloomColor("BloomColor",color) = (1,1,1,1)
        _BloomAO("BloomAO",2D) = "while"{}
        _NormalMap("NormalMap",2D) = "while"{}
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

    TEXTURE2D(_MainTex);
    SAMPLER(sampler_MainTex);
    TEXTURE2D(_NormalMap);
    SAMPLER(sampler_NormalMap);
    TEXTURE2D_X(_BloomAO);
    SAMPLER(sampler_BloomAO);
    TEXTURE2D(_MyCameraBloomTexture);
    SAMPLER(sampler_MyCameraBloomTexture);
    float4 _MainTex_ST;
    half4 _BaseColor;
    half4 _BloomColor;
    uniform float4 _MyBloomParams;

    struct appdata
    {
        float4 vertex: POSITION;
        float3 normal:NORMAL;
        float2 uv :TEXCOORD0;
        float4 tangent:TANGENT;
    };

    struct v2f
    {
        float4 vertex: SV_POSITION;
        float2 uv:TEXCOORD0;
        float2 uv1:TEXCOORD1;

        float3 TDirWS : TEXCOORD2;
        float3 BDirWS : TEXCOORD3;
        float3 NDirWS : TEXCOORD4;
    };

    // half4 EncodeHDR(half3 color)
    // {
    //     half4 outColor = EncodeRGBM(color);
    //
    //     outColor = half4(color, 1.0);
    //
    //
    //     return half4(sqrt(outColor.xyz), outColor.w); // linear to γ
    // }

    half luminance(half3 color)
    {
        return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
    }

    float3 GetHeightColor(float3 color, float Threshold)
    {
        half ThresholdKnee = Threshold * 0.5;
        // Thresholding
        half brightness = Max3(color.r, color.g, color.b);
        half softness = clamp(brightness - Threshold + ThresholdKnee, 0.0, 2.0 * ThresholdKnee);
        softness = (softness * softness) / (4.0 * ThresholdKnee + 1e-4);
        half multiplier = max(brightness - Threshold, softness) / max(brightness, 1e-4);
        color *= multiplier;

        return color;
    }

    v2f vert(appdata v)
    {
        v2f o;
        //v.vertex.xyz += _Width * normalize(v.vertex.xyz);

        o.vertex = TransformObjectToHClip(v.vertex.xyz);
        o.uv = TRANSFORM_TEX(v.uv, _MainTex);


        o.NDirWS = TransformObjectToWorldNormal(v.normal.xyz);
        o.TDirWS = normalize(TransformObjectToWorldDir(v.tangent.xyz));
        o.BDirWS = normalize(cross(o.NDirWS, o.TDirWS) * v.tangent.w);

        return o;
    }
    ENDHLSL

    Subshader
    {
        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward" "RenderType" = "Opaque" "Queue" = "Geometry"
            }

            Name "Defaule"
            //Blend SrcAlpha OneMinusSrcAlpha
            ZTest On
            ZWrite On
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            half4 frag(v2f i) : SV_Target
            {
                half2 screenUV = (i.vertex.xy / _ScreenParams.xy);
                float3 baseMap = float3(1, 1, 1);
                //SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb;
                float3 bloomMap =
                    SAMPLE_TEXTURE2D(_MyCameraBloomTexture, sampler_MyCameraBloomTexture, screenUV).rgb;
                //return float4(bloomMap.rgb, 1);
                float bloomAO =
                    SAMPLE_TEXTURE2D(_BloomAO, sampler_BloomAO, i.uv).r;

                float3 finalColor = float3(1, 1, 1);
                finalColor = lerp(baseMap.rgb, bloomMap.rgb, 0.01);
                finalColor = lerp(finalColor * _BaseColor.rgb,
                                  finalColor * _BloomColor.rgb,
                                  bloomAO);

                return float4(finalColor, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Tags
            {
                "LightMode" = "BloomOnly" "RenderType" = "Opaque" "Queue" = "Geometry"
            }

            Name "BloomOnly"
            //Blend SrcAlpha OneMinusSrcAlpha
            ZTest Off
            ZWrite Off
            ZTest Always
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            half4 frag(v2f i) : SV_Target
            {
                half2 screenUV = (i.vertex.xy / _ScreenParams.xy);
                float3 baseMap = float3(1, 1, 1);
                //SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb;
                float3 bloomMap =
                    SAMPLE_TEXTURE2D(_MyCameraBloomTexture, sampler_MyCameraBloomTexture, screenUV);

                float bloomAO =
                    SAMPLE_TEXTURE2D(_BloomAO, sampler_BloomAO, i.uv).r;

                float3 finalColor = float3(1, 1, 1);
                finalColor = lerp(baseMap.rgb, bloomMap.rgb, 0.01);
                finalColor = lerp(finalColor * _BaseColor.rgb,
                                  finalColor * _BloomColor.rgb,
                                  bloomAO);

                // clamp 约束到 0 - 1 区间
                //原版的亮度提取公式
                // half val = clamp(luminance(finalColor) - _MyBloomParams.x, 0.0, 1.0);
                // float3 bloomColor = finalColor * val;


                //unity的亮度提取公式
                float3 bloomColor = GetHeightColor(finalColor, _MyBloomParams.x);

                return float4(bloomColor, 1);
                //
                //
                // return float4(finalColor, 1);
            }
            ENDHLSL
        }

//        Pass
//        {
//            Name "DepthOnly"
//            Tags
//            {
//                "LightMode" = "DepthOnly"
//            }
//
//            ZWrite On
//            ColorMask 0
//
//            HLSLPROGRAM
//            #pragma only_renderers gles gles3 glcore d3d11
//            #pragma target 2.0
//
//            //--------------------------------------
//            // GPU Instancing
//            #pragma multi_compile_instancing
//
//            #pragma vertex DepthOnlyVertex
//            #pragma fragment DepthOnlyFragment
//
//            // -------------------------------------
//            // Material Keywords
//            #pragma shader_feature_local_fragment _ALPHATEST_ON
//            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
//
//            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
//            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
//            ENDHLSL
//        }
    }
}