Shader "4/4_Bloom"
{
    Properties
    {
        _MainTex("MainTex",2D) = "while"{}

    }
    HLSLINCLUDE
    #pragma exclude_renderers gles
    #pragma multi_compile_local _ _USE_RGBM
    #pragma multi_compile _ _USE_DRAW_PROCEDURAL

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

    TEXTURE2D_X(_SourceTex);
    float4 _SourceTex_TexelSize;
    TEXTURE2D_X(_DestTex);
    float4 _DestTex_TexelSize;
    TEXTURE2D_X(_MySourceTex);
    float4 _MySourceTex_TexelSize;
    TEXTURE2D_X(_MySourceTexLowMip);
    float4 _MySourceTexLowMip_TexelSize;
    TEXTURE2D_X(_BloomLowTex);

    float4 _MyBloomParams; // x: scatter, y: clamp, z: threshold (linear), w: threshold knee

    half4 EncodeHDR(half3 color)
    {
        //float3 newColor = color / (color + 0.01);
        return float4(color, 1);
    }

    half3 DecodeHDR(half4 color)
    {
        //float3 newColor = (color.rgb * 0.01) / (1 - color.rgb);

        return color.rgb;
    }

    half4 FragBlurH(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float texelSize = _MySourceTex_TexelSize.x*4.0 ;
        float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);

        // 9-tap gaussian blur on the downsampled source
        half3 c0 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp, uv - float2(texelSize * 4.0, 0.0)));
        half3 c1 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp, uv - float2(texelSize * 3.0, 0.0)));
        half3 c2 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp, uv - float2(texelSize * 2.0, 0.0)));
        half3 c3 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp, uv - float2(texelSize * 1.0, 0.0)));
        half3 c4 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp, uv));
        half3 c5 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp, uv + float2(texelSize * 1.0, 0.0)));
        half3 c6 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp, uv + float2(texelSize * 2.0, 0.0)));
        half3 c7 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp, uv + float2(texelSize * 3.0, 0.0)));
        half3 c8 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp, uv + float2(texelSize * 4.0, 0.0)));

        half3 color = c0 * 0.01621622 + c1 * 0.05405405 + c2 * 0.12162162 + c3 * 0.19459459
            + c4 * 0.22702703
            + c5 * 0.19459459 + c6 * 0.12162162 + c7 * 0.05405405 + c8 * 0.01621622;

        return EncodeHDR(color);
    }

    half4 FragBlurV(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float texelSize = _MySourceTex_TexelSize.y*2.0;
        float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);

        // Optimized bilinear 5-tap gaussian on the same-sized source (9-tap equivalent)
        half3 c0 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp,uv - float2(0.0, texelSize * 3.23076923)));
        half3 c1 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp,uv - float2(0.0, texelSize * 1.38461538)));
        half3 c2 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp, uv));
        half3 c3 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp, uv + float2(0.0, texelSize * 1.38461538)));
        half3 c4 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp,uv + float2(0.0, texelSize * 3.23076923)));

        half3 color = c0 * 0.07027027 + c1 * 0.31621622
            + c2 * 0.22702703
            + c3 * 0.31621622 + c4 * 0.07027027;

        return EncodeHDR(color);
    }

    half4 FragUpsample(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);
        half3 highMip = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp, uv));

        half3 lowMip = DecodeHDR(SAMPLE_TEXTURE2D_X(_BloomLowTex, sampler_LinearClamp, uv));

        half3 finalColor = max(highMip, lowMip);
        finalColor = lerp(highMip, lowMip, _MyBloomParams.w);
        return EncodeHDR(finalColor);
        //return float4(lerp(highMip, lowMip, _Params.w),1);
    }

    half4 FragBlend(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);
        half3 highMip = (SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp, uv));

        half3 lowMip = (SAMPLE_TEXTURE2D_X(_BloomLowTex, sampler_LinearClamp, uv));

        //return float4(lowMip.rgb,1);
        half3 finalColor = lowMip + pow(highMip, 1 / _MyBloomParams.z) * _MyBloomParams.y;

        //test
        //finalColor = lowMip + pow(highMip, 1 / _MyBloomParams.z) * _MyBloomParams.y;


        return float4(finalColor, 1);
    }
    ENDHLSL
    Subshader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }
        LOD 100
        ZTest Always
        ZWrite Off
        Cull Off

        Pass
        {
            Name "Bloom Blur Horizontal"

            HLSLPROGRAM
            #pragma vertex FullscreenVert
            #pragma fragment FragBlurH
            ENDHLSL
        }

        Pass
        {
            Name "Bloom Blur Vertical"

            HLSLPROGRAM
            #pragma vertex FullscreenVert
            #pragma fragment FragBlurV
            ENDHLSL
        }

        Pass
        {
            Name "Bloom Upsample"

            HLSLPROGRAM
            #pragma vertex FullscreenVert
            #pragma fragment FragUpsample
            #pragma multi_compile_local _ _BLOOM_HQ
            ENDHLSL
        }

        Pass
        {
            Name "Bloom Blend"

            HLSLPROGRAM
            #pragma vertex FullscreenVert
            #pragma fragment FragBlend
            #pragma multi_compile_local _ _BLOOM_HQ
            ENDHLSL
        }

        //颜色提取
        Pass
        {
            Name "GetBloomColor"

            HLSLPROGRAM
            #pragma vertex FullscreenVert
            #pragma fragment frag
            #pragma multi_compile_local _ _BLOOM_HQ

            float3 _ClampColor;

            float3 GetHeightColor(float3 color, float Threshold)
            {
                half brightness = color.r * 0.7154 + color.g * 0.2125 + color.b * 0.0721;
                half3 softness = clamp(brightness - Threshold, 0.0, 1.0);
                float3 finalColor = color * softness;
                //color *= (softness);
                //return brightness;

                //我的想法
                // Thresholding
                // brightness = color.r*0.7154+ color.g*0.2125+color.b*0.0721;
                // float3 clamp3 = float3(_ClampColor.r,_ClampColor.g,_ClampColor.b)
                //     /(_ClampColor.r+_ClampColor.g+_ClampColor.b);
                // softness = clamp(brightness - Threshold, 0.0, 1.0);
                // softness = softness*clamp3*3;
                // //softness = softness*float3(0.5154,0.2125,0.2721)*3;
                // finalColor = color*softness;

                //想法2
                //float3 Threshold3 = float3(0.2125, 0.7154, 0.0721);
                //Threshold3 = lerp(Threshold3,1,0.8)*Threshold;
                softness = clamp(color - Threshold, 0.0, 1.0);
                finalColor = softness;


                //finalColor = lerp()

                return finalColor;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half2 screenUV = (i.positionCS.xy / _DestTex_TexelSize.zw);
                //目标RT
                float4 SourceTex =
                    SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, screenUV);


                //unity的亮度提取公式
                float3 bloomColor = GetHeightColor(SourceTex.rgb, _MyBloomParams.x);
                return float4(bloomColor, SourceTex.a);
                return float4(bloomColor, SourceTex.a);
            }
            ENDHLSL
        }

    }
}