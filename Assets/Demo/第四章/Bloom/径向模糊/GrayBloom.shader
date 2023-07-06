Shader "4/GrayBloom"
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
    TEXTURE2D_X(_MySourceTex);
    float4 _MySourceTex_TexelSize;
    TEXTURE2D_X(_MySourceTexLowMip);
    float4 _MySourceTexLowMip_TexelSize;
    TEXTURE2D_X(_BloomLowTex);

    float4 _MyBloomParams; // (threshold, intensity, width, scatter)
    float3 _MyGodGrayParams; //(dirX,dirY)

    half4 EncodeHDR(half3 color)
    {
        // half4 outColor = EncodeRGBM(color);
        //
        // outColor = half4(color, 1.0);
        //
        // return half4(sqrt(outColor.xyz), outColor.w); // linear to γ

        return float4(color, 1);
    }

    half3 DecodeHDR(half4 color)
    {
        // #if UNITY_COLORSPACE_GAMMA
        //     color.xyz *= color.xyz; // γ to linear
        // #endif
        //
        // #if _USE_RGBM
        //     return DecodeRGBM(color);
        // #else
        // return color.xyz;
        // #endif
        return color.rgb;
    }

    float2 GetDirX(float2 uv)
    {
        //uv = floor(uv);
        float2 dir = (float2(_MyGodGrayParams.x, _MyGodGrayParams.y) - uv)
            * _MyGodGrayParams.z;
        //return uv;
        return normalize(dir);
    }

    float2 GetDirY(float2 uv)
    {
        //uv = floor(uv);
        float2 dir = (float2(_MyGodGrayParams.x, _MyGodGrayParams.y) - uv)
            * _MyGodGrayParams.z;
        //return uv;
        return normalize(dir);
    }

    half4 FragBlurH(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float texelSize = _MySourceTex_TexelSize.x;
        float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);
        float2 dir = GetDirX(uv);

        // 9-tap gaussian blur on the downsampled source
        half3 c0 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp,
                                                uv +dir* float2(texelSize * 4.0, 0.0)));
        half3 c1 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp,
                                                uv + dir* float2(texelSize * 3.0, 0.0)));
        half3 c2 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp,
                                                uv + dir* float2(texelSize * 2.0, 0.0)));
        half3 c3 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp,
                                                uv + dir* float2(texelSize * 1.0, 0.0)));
        half3 c4 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp, uv));

        float3 color = c0 * 0.0261 +
            c1 * 0.0882 +
            c2 * 0.1977 +
            c3 * 0.3170 +
            c4 * 0.3709;

        return EncodeHDR(color);
    }

    half4 FragBlurV(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float texelSize = _MySourceTex_TexelSize.x;
        float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);
        float2 dir = GetDirY(uv);

        // 9-tap gaussian blur on the downsampled source
        half3 c0 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp,
                                                uv + dir* float2(0.0,texelSize * 4.0 )));
        half3 c1 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp,
                                                uv + dir* float2(0.0,texelSize * 3.0)));
        half3 c2 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp,
                                                uv + dir* float2(0.0,texelSize * 2.0)));
        half3 c3 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp,
                                                uv + dir* float2(0.0,texelSize * 1.0)));
        half3 c4 = DecodeHDR(SAMPLE_TEXTURE2D_X(_MySourceTex, sampler_LinearClamp, uv));

        float3 color = c0 * 0.0261 +
            c1 * 0.0882 +
            c2 * 0.1977 +
            c3 * 0.3170 +
            c4 * 0.3709;

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

    }
}