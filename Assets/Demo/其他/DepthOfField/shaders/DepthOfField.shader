Shader "PostProcessing/DepthOfField"
{

    Properties
    {
        _DecalTex("_DecalTex",2D) = "while"{}
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    TEXTURE2D_X(_CameraDepthTexture);
    SAMPLER(sampler_CameraDepthTexture);
    float4 _CameraDepthTexture_TexelSize;
    TEXTURE2D(_CameraTexture);
    SAMPLER(sampler_CameraTexture);
    float4 _CameraTexture_TexelSize;
    TEXTURE2D(_DOFTexture);
    SAMPLER(sampler_DOFTexture);
    float4 _DOFTexture_TexelSize;
    TEXTURE2D(_cocTexture);
    SAMPLER(sampler_cocTexture);
    float4 _cocTexture_TexelSize;

    //---------滤波用-------//
    TEXTURE2D(_filterTexture);
    SAMPLER(sampler_filterTexture);
    float4 _filterTexture_TexelSize;

    float _FocusDistance;
    float _FocusRange;
    float _FocusRadius;
    float _FocusIntensity;

    //预计算的圆盘范围
    static const int kernelSampleCount = 16;
    static const float2 kernel[kernelSampleCount] = {
        float2(0, 0),
        float2(0.54545456, 0),
        float2(0.16855472, 0.5187581),
        float2(-0.44128203, 0.3206101),
        float2(-0.44128197, -0.3206102),
        float2(0.1685548, -0.5187581),
        float2(1, 0),
        float2(0.809017, 0.58778524),
        float2(0.30901697, 0.95105654),
        float2(-0.30901703, 0.9510565),
        float2(-0.80901706, 0.5877852),
        float2(-1, 0),
        float2(-0.80901694, -0.58778536),
        float2(-0.30901664, -0.9510566),
        float2(0.30901712, -0.9510565),
        float2(0.80901694, -0.5877853),
    };

    struct Attributes
    {
        float4 position : POSITION;
        float2 uv : TEXCOORD0;
        //UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        float2 uv : TEXCOORD0;
        float4 color : TEXCOORD1;
        float4 parmas : TEXCOORD2;
        //UNITY_VERTEX_OUTPUT_STEREO
    };

    Varyings VertDefault(Attributes input)
    {
        Varyings output;

        //这个CS是屏幕空间的坐标
        output.positionCS = TransformWorldToHClip(input.position);
        output.uv = input.uv;


        return output;
    }

    float4 dofFunction(float Radius, float u, float2 screenUV,inout float3 color,inout float Weight)
    {
        [loop]
        //[unroll(20)]
        for (int v = -Radius; v <= Radius; v++)
        {
            float2 o = float2(u, v);
            if (length(o) <= Radius)
            {
                o *= _CameraDepthTexture_TexelSize.xy * _FocusIntensity;
                color.xyz += _CameraTexture.Sample(sampler_CameraTexture, screenUV + o).rgb;
                Weight += 1;
            }
        }
        float4 colorAndWeight = float4(color.rgb,Weight);
        return colorAndWeight;
    }

    half4 FragmentProgram(Varyings i) : SV_Target
    {
        float2 screenUV = i.positionCS.xy /
            float2(_CameraDepthTexture_TexelSize.z, _CameraDepthTexture_TexelSize.w);
        float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
        float cocMask = SAMPLE_TEXTURE2D_X(_cocTexture, sampler_cocTexture, screenUV).r;


        //return _radius;
        float Radius = _FocusRadius * cocMask;
        half3 color = 0;
        float weight = 0;

        //----------------圆形算法1-------------------//
        // [loop]
        //  for (int u = -Radius; u <= Radius; u++)
        //  {
        //     [loop]
        //     for (int v = -Radius; v <= Radius; v++)
        //     {
        //         float2 o = float2(u, v);
        //         if (length(o) <= Radius)
        //         {
        //             o *= _CameraDepthTexture_TexelSize.xy * _FocusIntensity;
        //             {
        //                 color.xyz += _CameraTexture.Sample(sampler_CameraTexture, screenUV + o).rgb;
        //                 weight += 1;
        //             }
        //         }
        //     }
        //  }

        //----------------圆形算法2-------------------//
        [loop]
        for (int k = 0;k<kernelSampleCount;k++)
        {
            float2 o = kernel[k];
            o *= _CameraDepthTexture_TexelSize.xy * _FocusRadius*cocMask*_FocusIntensity;
            color += _CameraTexture.Sample(sampler_CameraTexture, screenUV + o).rgb;
            weight+=1;
        }
        
         color *= 1.0 / weight;
         return half4(color, 1);

        
		// for (int u = -4; u <= 4; u++) {
		// 	for (int v = -4; v <= 4; v++) {
		// 					float2 o = float2(u, v) * _MainTex_TexelSize.xy * 2;
		// 		float2 o = float2(u, v);
		// 		if (length(o) <= 4) {
		// 			o *= _CameraTexture_TexelSize.xy * _FocusIntensity;
		// 			color += _CameraTexture.Sample(sampler_CameraTexture, screenUV + o).rgb;
		// 			weight += 1;
		// 		}
		// 	}
		// }
		// color *= 1.0 / weight;
		// return half4(color, 1);
        
    }

    half4 FilterFragment(Varyings i) : SV_Target
    {
        float2 screenUV = i.positionCS.xy /_DOFTexture_TexelSize.zw;
        //float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
        float cocMask = SAMPLE_TEXTURE2D_X(_cocTexture, sampler_cocTexture, screenUV).r;
        float4 baseColor = _CameraTexture.Sample(sampler_CameraTexture, screenUV);
        
        float4 o = _DOFTexture_TexelSize.xyxy * float2(-1,1).xxyy*0.5;

        half3 c1 = _DOFTexture.Sample(sampler_DOFTexture, screenUV + o.xy).rgb;
        half3 c2 = _DOFTexture.Sample(sampler_DOFTexture, screenUV + o.zy).rgb;
        half3 c3 = _DOFTexture.Sample(sampler_DOFTexture, screenUV + o.xw).rgb;
        half3 c4 = _DOFTexture.Sample(sampler_DOFTexture, screenUV + o.zw).rgb;

        half3 allColor = (c1+c2+c3+c4)/4;

        float3 finalColor = lerp(baseColor.rgb,allColor,cocMask);
        return float4(allColor,baseColor.a);
        
    }

    //水平
   half4 FragBlurH(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);
        float cocMask = SAMPLE_TEXTURE2D_X(_cocTexture, sampler_cocTexture, uv).r;
        float texelSize = _filterTexture_TexelSize.x*2.0*cocMask;
        

        // 9-tap gaussian blur on the downsampled source
        half3 c0 = (SAMPLE_TEXTURE2D_X(_filterTexture, sampler_filterTexture, uv - float2(texelSize * 4.0, 0.0)));
        half3 c1 = (SAMPLE_TEXTURE2D_X(_filterTexture, sampler_filterTexture, uv - float2(texelSize * 3.0, 0.0)));
        half3 c2 = (SAMPLE_TEXTURE2D_X(_filterTexture, sampler_filterTexture, uv - float2(texelSize * 2.0, 0.0)));
        half3 c3 = (SAMPLE_TEXTURE2D_X(_filterTexture, sampler_filterTexture, uv - float2(texelSize * 1.0, 0.0)));
        half3 c4 = (SAMPLE_TEXTURE2D_X(_filterTexture, sampler_filterTexture, uv));
        half3 c5 = (SAMPLE_TEXTURE2D_X(_filterTexture, sampler_filterTexture, uv + float2(texelSize * 1.0, 0.0)));
        half3 c6 = (SAMPLE_TEXTURE2D_X(_filterTexture, sampler_filterTexture, uv + float2(texelSize * 2.0, 0.0)));
        half3 c7 = (SAMPLE_TEXTURE2D_X(_filterTexture, sampler_filterTexture, uv + float2(texelSize * 3.0, 0.0)));
        half3 c8 = (SAMPLE_TEXTURE2D_X(_filterTexture, sampler_filterTexture, uv + float2(texelSize * 4.0, 0.0)));

        half3 color = c0 * 0.01621622 + c1 * 0.05405405 + c2 * 0.12162162 + c3 * 0.19459459
            + c4 * 0.22702703
            + c5 * 0.19459459 + c6 * 0.12162162 + c7 * 0.05405405 + c8 * 0.01621622;

        return float4(color,1);
    }

    //垂直
    half4 FragBlurV(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);
        float cocMask = SAMPLE_TEXTURE2D_X(_cocTexture, sampler_cocTexture, uv).r;
        float texelSize = _filterTexture_TexelSize.y*2.0*cocMask;
        

        // Optimized bilinear 5-tap gaussian on the same-sized source (9-tap equivalent)
        half3 c0 = (SAMPLE_TEXTURE2D_X(_filterTexture, sampler_filterTexture,uv - float2(0.0, texelSize * 3.23076923)));
        half3 c1 = (SAMPLE_TEXTURE2D_X(_filterTexture, sampler_filterTexture,uv - float2(0.0, texelSize * 1.38461538)));
        half3 c2 = (SAMPLE_TEXTURE2D_X(_filterTexture, sampler_filterTexture, uv));
        half3 c3 = (SAMPLE_TEXTURE2D_X(_filterTexture, sampler_filterTexture, uv + float2(0.0, texelSize * 1.38461538)));
        half3 c4 = (SAMPLE_TEXTURE2D_X(_filterTexture, sampler_filterTexture,uv + float2(0.0, texelSize * 3.23076923)));

        half3 color = c0 * 0.07027027 + c1 * 0.31621622
            + c2 * 0.22702703
            + c3 * 0.31621622 + c4 * 0.07027027;

        return float4(color,1);
    }
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }

        //0
        Pass
        {
            Name "circleOfConfusionPass"
            ZTest On
            ZWrite Off
            ZTest LEqual
            Cull Off

            //Blend SrcAlpha OneMinusSrcAlpha
            //Blend Zero SrcColor

            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment cocFrag

            float _distance;


            float4 cocFrag(Varyings i) : SV_Target
            {
                float2 screenUV = i.positionCS.xy /_CameraDepthTexture_TexelSize.zw;
                float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
                ///return depth;
                depth = LinearEyeDepth(depth, _ZBufferParams);

                //记录当前像素的coc值
                float d = (abs(depth - _FocusDistance));
                float coc = max(d-_FocusRange,0) / _FocusRadius;
                coc = clamp(coc, -1, 1);
                //coc = abs(coc);
                //					if (coc < 0) {
                //						return coc * -half4(1, 0, 0, 1);
                //					}
                return coc;
            }
            ENDHLSL
        }

        //1
        Pass
        {
            Name "dofPass"
            ZTest On
            ZWrite Off
            ZTest LEqual
            Cull Off

            //Blend SrcAlpha OneMinusSrcAlpha
            //Blend Zero SrcColor

            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment FragmentProgram
            ENDHLSL
        }
        
        //2
        Pass
        {
            Name "filterHPass"
            ZTest On
            ZWrite Off
            ZTest Always
            Cull Off

            //Blend SrcAlpha OneMinusSrcAlpha
            //Blend Zero SrcColor

            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment FragBlurH
            ENDHLSL
        }
        
        
        //2
        Pass
        {
            Name "filterVPass"
            ZTest On
            ZWrite Off
            ZTest Always
            Cull Off

            //Blend SrcAlpha OneMinusSrcAlpha
            //Blend Zero SrcColor

            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment FragBlurV
            ENDHLSL
        }

    }
}