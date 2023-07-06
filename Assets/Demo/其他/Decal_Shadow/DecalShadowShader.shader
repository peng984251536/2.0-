Shader "Unlit/DecalShadowShader"
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


    struct Attributes
    {
        float4 position : POSITION;
        float2 uv : TEXCOORD0;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        float2 uv : TEXCOORD0;
        float4 color : TEXCOORD1;
        float4 parmas : TEXCOORD2;
        UNITY_VERTEX_OUTPUT_STEREO
    };
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }
        //        Cull Off 
        //        ZWrite Off 
        //        ZTest LEqual

        Pass
        {
            Name "MyDecal_shadow"
            ZTest On
            ZWrite Off
            ZTest LEqual
            Cull Off

            Blend SrcAlpha OneMinusSrcAlpha
            //Blend Zero SrcColor

            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment Frag
            #pragma multi_compile_local _SOURCE_DEPTH _SOURCE_DEPTH_NORMALS _SOURCE_GBUFFER
            #pragma multi_compile_local _RECONSTRUCT_NORMAL_LOW _RECONSTRUCT_NORMAL_MEDIUM _RECONSTRUCT_NORMAL_HIGH
            #pragma multi_compile_local _ _ORTHOGRAPHIC

            TEXTURE2D_X(_DecalTex);
            SAMPLER(sampler_DecalTex);
            TEXTURE2D_X(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D_X(_NoiseMap);
            SAMPLER(sampler_NoiseMap);

            //float _RangeStrength;
            float4x4 _VPMatrix_invers;
            float4x4 _VMatrix;
            float4x4 _PMatrix;
            float4x4 _worldToLight;
            float4x4 _worldToLight_inv;

            float4 _shadowColor;
            float _alpahParams;
            float3 _LightPos;
            float _distance;


            inline float random(float2 uv)
            {
                return frac(sin(dot(uv.xy, float2(12.9898, 78.233))) * 43758.5453123);
            }

            Varyings VertDefault(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input); //GPU实例
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                // float3 posWS = TransformObjectToWorld(input.position);
                //
                // float dis_posToLight = distance(posWS.xz,_LightPos.xz);
                //
                // float3 posLS = mul(_worldToLight,posWS);
                // float3 light_posLS = mul(_worldToLight,_LightPos);
                //
                // float val =  dis_posToLight/_distance;
                // output.color.rgba =val;
                // output.parmas = val;
                // //posLS.z*=val;
                // //posLS.x*=0.2;
                //
                // float3 newPosWS = mul(_worldToLight_inv,posLS);
                
                input.position.xz*=5;
                //这个CS是屏幕空间的坐标
                output.positionCS = TransformWorldToHClip(input.position);


                output.uv = input.uv;

                // Add a small epsilon to avoid artifacts when reconstructing the normals
                //output.uv += 1.0e-6;

                return output;
            }


            float4 Frag(Varyings i) : SV_Target
            {
                //return float4(i.color.rgb,1);
                
                //屏幕空间转uv坐标
                //顶点着色输出的positionCS是裁剪空间坐标
                //片元着色输入的是屏幕空间坐标
                float2 screenUV = i.positionCS.xy / _ScreenParams.xy;

                float depth_o = SAMPLE_TEXTURE2D_X(
                    _CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;;
                float eyeDepth = LinearEyeDepth(depth_o, _ZBufferParams);

                //利用uv采样一张Noise贴图
                float2 noiseScale = _ScreenParams.xy / 4;
                float2 noiseUV = i.uv * noiseScale;
                float3 randvec = SAMPLE_TEXTURE2D_LOD(
                    _NoiseMap, sampler_NoiseMap, noiseUV, 0).rgb;

                //把ndc坐标转换到世界空间
                float4 ndc = float4(screenUV * 2 - 1, (1 - depth_o) * 2 - 1, 1);
                float4 posWS = mul(_VPMatrix_invers, ndc);
                posWS /= posWS.w;

                float dis_posToLight = distance(posWS.xz,_LightPos.xz);
                float val =  dis_posToLight/_distance;
                

                float3 proPosOS = TransformWorldToObject(posWS);
                proPosOS.xz/=val;
                clip(2 - abs(proPosOS.x));
                clip(2 - abs(proPosOS.z));
                //proPosOS.xz*=i.color.a;
                float2 uv = proPosOS.xz + 0.5;
                float3 finalColor = SAMPLE_TEXTURE2D_X(
                    _DecalTex, sampler_DecalTex, saturate(uv)).rgb;
                //clip(finalColor.r - 0.5);


                //return i.color.r;
                return float4(_shadowColor.rgb, _alpahParams*finalColor.r);
            }
            ENDHLSL
        }
    }
}