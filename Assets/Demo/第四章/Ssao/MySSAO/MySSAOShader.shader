Shader "4/MySSAOShader"
{

    Properties
    {
        _RangeStrength("RangeStrength",float) = 0
        _DepthBiasValue("DepthBiasValue",float) = 0
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    // float _BilaterFilterFactor; //法线判定的插值
    // float2 _BlurRadius; //滤波的采样范围
    float4 _bilateralParams;
    #define BilaterFilterFactor _bilateralParams.z


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
        UNITY_VERTEX_OUTPUT_STEREO
    };

    Varyings VertDefault(Attributes input)
    {
        Varyings output;
        UNITY_SETUP_INSTANCE_ID(input); //GPU实例
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        // Note: The pass is setup with a mesh already in CS
        // Therefore, we can just output vertex position
        //这个CS是屏幕空间的坐标
        output.positionCS = TransformObjectToHClip(input.position);

        //测试图形引擎的坐标
        #if UNITY_UV_STARTS_AT_TOP
        output.positionCS.y *= -1;
        #endif

        output.uv = input.uv;

        // Add a small epsilon to avoid artifacts when reconstructing the normals
        output.uv += 1.0e-6;

        return output;
    }
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            Name "MySSAO_Occlusion"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment SSAO
            #pragma multi_compile_local _SOURCE_DEPTH _SOURCE_DEPTH_NORMALS _SOURCE_GBUFFER
            #pragma multi_compile_local _RECONSTRUCT_NORMAL_LOW _RECONSTRUCT_NORMAL_MEDIUM _RECONSTRUCT_NORMAL_HIGH
            #pragma multi_compile_local _ _ORTHOGRAPHIC

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

            TEXTURE2D_X(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            // TEXTURE2D(_CameraNormalsTexture);
            // SAMPLER(sampler_CameraNormalsTexture);
            TEXTURE2D_X(_NoiseMap);
            SAMPLER(sampler_NoiseMap);

            // SSAO Settings
            float4 _SSAOParams; //x:INTENSITY ,y:RADIUS,z:DOWNSAMPLE,w:SAMPLECOUNT
            #define INTENSITY _SSAOParams.x
            #define RADIUS _SSAOParams.y
            #define RANGESTRENGTH _SSAOParams.z
            #define SAMPLECOUNT _SSAOParams.w
            float4 _SSAO_RandomVectors[60];
            //float _RangeStrength;
            float4x4 _VPMatrix_invers;
            float4x4 _VMatrix;
            float4x4 _PMatrix;

            float3 GetNormalDepth(float2 uv, out float depth)
            {
                depth = SAMPLE_TEXTURE2D_X(
                    _CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
                //depth_o = Linear01Depth(depth_o, _ZBufferParams);
                // float near = _ProjectionParams.y;
                // float far = _ProjectionParams.z;
                // depth = near / (depth * (far - near) + near);
                // float2 normalMap = SAMPLE_TEXTURE2D_X(
                //     _CameraNormalsTexture, sampler_CameraNormalsTexture, uv).xy;
                // float3 normal = UnpackNormalOctRectEncode(normalMap);
                float3 normal = SampleSceneNormals(uv);
                return normal;
            }


            float4 SSAO(Varyings i) : SV_Target
            {
                float ao = 0;

                //屏幕空间转uv坐标
                float2 screenUV = i.positionCS.xy / _ScreenParams.xy;

                float depth_o = 0;
                half3 norm_o = 0;
                norm_o = GetNormalDepth(screenUV, depth_o);
                float eyeDepth = LinearEyeDepth(depth_o, _ZBufferParams);

                //利用uv采样一张Noise贴图
                float2 noiseScale = _ScreenParams.xy / 4;
                float2 noiseUV = i.uv * noiseScale;
                float3 randvec = SAMPLE_TEXTURE2D_LOD(_NoiseMap, sampler_NoiseMap, noiseUV, 0).rgb;

                //---构建法向量正交基，用于把切线空间的随机向量转换到世界空间
                float3 tangent = normalize(randvec - norm_o * dot(randvec, norm_o)); //计算出一个和法线垂直的向量
                float3 bitangent = cross(norm_o, tangent);
                float3x3 TBN = float3x3(tangent, bitangent, norm_o);

                //把ndc坐标转换到世界空间
                float4 ndc = float4(screenUV * 2 - 1, (1 - depth_o) * 2 - 1, 1);
                float4 posWS = mul(_VPMatrix_invers, ndc);
                posWS /= posWS.w;
                float3 viewPos = mul(_VMatrix,posWS);
                //return float4(viewPos,1);

                float3 testColor = 0;
                for (int index = 0; index < SAMPLECOUNT; index++)
                {
                    //切线空间转回世界空间,有点类使用切线空间法线的用法
                    float3 randomVec = _SSAO_RandomVectors[index].xyz;
                    float3 randomVecWS = normalize(mul(randomVec, TBN));

                    float3 randomPos = posWS + randomVecWS * RADIUS * 0.1;
                    //转换到裁剪空间
                    float4 offPosV = mul(_VMatrix, float4(randomPos, 1));
                    float4 rclipPos = mul(_PMatrix, offPosV);

                    //return rclipPos.w/(_ProjectionParams.z);
                    float sampleZ = (rclipPos.w - _ProjectionParams.y) / (_ProjectionParams.z - _ProjectionParams.y);
                    sampleZ = rclipPos.w;
                    float2 rscreenPos = (rclipPos.xy / rclipPos.w) * 0.5 + 0.5;

                    //计算随机向量转化 至 屏幕空间后的深度值，并判断累加AO
                    float sampleDepth;
                    float3 randomNormal;
                    randomNormal = GetNormalDepth(rscreenPos, sampleDepth);
                    sampleDepth = LinearEyeDepth(sampleDepth, _ZBufferParams);

                    //判断是否为ao，ao计为1
                    float range = (sampleZ >= sampleDepth) ? 1 : 0;
                    //判断是否为假ao，为假ao，rangeCheck计为0
                    float rangeCheck = sampleDepth + RADIUS + RANGESTRENGTH < sampleZ ? 0.0 : 1.0;
                    //有些采样的ao会超过最大深度值会超过原来摄像机设置的最大深度值，做排除
                    float selfCheck = step(sampleZ, _ProjectionParams.z);
                    //离法线越近的随机向量（随机向量的xy模），比重越小
                    float weight = smoothstep(0.2, 0.8, length(randomVec.xy));
                    ao += range * weight * rangeCheck * selfCheck;
                }

                ao = saturate(ao / SAMPLECOUNT);

                return (1 - ao * INTENSITY);
            }
            ENDHLSL
        }

        Pass
        {
            //双边滤波_水平
            Name "Horizontal_BilaterFilter"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment frag_bilateralnormal
            #pragma multi_compile_local _SOURCE_DEPTH _SOURCE_DEPTH_NORMALS _SOURCE_GBUFFER
            #pragma multi_compile_local _RECONSTRUCT_NORMAL_LOW _RECONSTRUCT_NORMAL_MEDIUM _RECONSTRUCT_NORMAL_HIGH
            #pragma multi_compile_local _ _ORTHOGRAPHIC

            // TEXTURE2D(_MainTex);
            // SAMPLER(sampler_MainTex);
            // float2 _MainTex_TexelSize;

            TEXTURE2D_X(_MyAmbientOcclusionTex);
            SAMPLER(sampler_MyAmbientOcclusionTex);
            float2 _MyAmbientOcclusionTex_TexelSize;

            TEXTURE2D_X_FLOAT(_CameraNormalsTexture);
            SAMPLER(sampler_CameraNormalsTexture);

            float3 GetNormal(float2 uv)
            {
                float2 normalMap = SAMPLE_TEXTURE2D_X(
                    _CameraNormalsTexture, sampler_CameraNormalsTexture, uv).xy;
                float3 normal = UnpackNormalOctRectEncode(normalMap);
                return normal;
            }

            //对照两个法线
            float CompareNormal(float3 normal1, float3 normal2)
            {
                return smoothstep(BilaterFilterFactor, 1.0, dot(normal1, normal2));
            }

            float4 frag_bilateralnormal(Varyings i) : SV_Target
            {
                float2 delta = _MyAmbientOcclusionTex_TexelSize.xy * _bilateralParams.xy;

                i.uv = i.positionCS.xy / _ScreenParams.xy;

                float2 uv = i.uv;
                float2 uv0a = i.uv - float2(1.0, 0) * delta;
                float2 uv0b = i.uv + float2(1.0, 0) * delta;
                float2 uv1a = i.uv - float2(2.0, 0) * delta;
                float2 uv1b = i.uv + float2(2.0, 0) * delta;

                float3 normal0 = GetNormal(uv);
                float3 normal1 = GetNormal(uv0a);
                float3 normal2 = GetNormal(uv0b);
                float3 normal3 = GetNormal(uv1a);
                float3 normal4 = GetNormal(uv1b);

                float4 col = SAMPLE_TEXTURE2D(_MyAmbientOcclusionTex, sampler_MyAmbientOcclusionTex, uv);
                float4 col0a = SAMPLE_TEXTURE2D(_MyAmbientOcclusionTex, sampler_MyAmbientOcclusionTex, uv0a);
                float4 col0b = SAMPLE_TEXTURE2D(_MyAmbientOcclusionTex, sampler_MyAmbientOcclusionTex, uv0b);
                float4 col1a = SAMPLE_TEXTURE2D(_MyAmbientOcclusionTex, sampler_MyAmbientOcclusionTex, uv1a);
                float4 col1b = SAMPLE_TEXTURE2D(_MyAmbientOcclusionTex, sampler_MyAmbientOcclusionTex, uv1b);

                half w = 0.4026;
                half w0a = CompareNormal(normal0, normal1) * 0.0545;
                half w0b = CompareNormal(normal0, normal2) * 0.0545;
                half w1a = CompareNormal(normal0, normal3) * 0.2442;
                half w1b = CompareNormal(normal0, normal4) * 0.2442;


                half3 result;
                result = w * col.rgb;
                result += w0a * col0a.rgb;
                result += w0b * col0b.rgb;
                result += w1a * col1a.rgb;
                result += w1b * col1b.rgb;

                result = result / (w + w0a + w0b + w1a + w1b);
                return float4(result, 1.0);
            }
            ENDHLSL
        }

        // 2 - Vertical Blur
        Pass
        {
            Name "Vertical_BilaterFilter"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment frag_bilateralnormal
            #pragma multi_compile_local _SOURCE_DEPTH _SOURCE_DEPTH_NORMALS _SOURCE_GBUFFER
            #pragma multi_compile_local _RECONSTRUCT_NORMAL_LOW _RECONSTRUCT_NORMAL_MEDIUM _RECONSTRUCT_NORMAL_HIGH
            #pragma multi_compile_local _ _ORTHOGRAPHIC

            // TEXTURE2D(_MainTex);
            // SAMPLER(sampler_MainTex);
            // float2 _MainTex_TexelSize;

            TEXTURE2D_X(_MyAmbientOcclusionTex);
            SAMPLER(sampler_MyAmbientOcclusionTex);
            float2 _MyAmbientOcclusionTex_TexelSize;

            TEXTURE2D_X_FLOAT(_CameraNormalsTexture);
            SAMPLER(sampler_CameraNormalsTexture);

            float3 GetNormal(float2 uv)
            {
                float2 normalMap = SAMPLE_TEXTURE2D_X(
                    _CameraNormalsTexture, sampler_CameraNormalsTexture, uv).xy;
                float3 normal = UnpackNormalOctRectEncode(normalMap);
                return normal;
            }

            //对照两个法线
            float CompareNormal(float3 normal1, float3 normal2)
            {
                return smoothstep(BilaterFilterFactor, 1.0, dot(normal1, normal2));
            }

            float4 frag_bilateralnormal(Varyings i) : SV_Target
            {
                float2 delta = _MyAmbientOcclusionTex_TexelSize.xy * _bilateralParams.xy;

                i.uv = i.positionCS.xy / _ScreenParams.xy;

                float2 uv = i.uv;
                float2 uv0a = i.uv - float2(0, 1.0) * delta;
                float2 uv0b = i.uv + float2(0, 1.0) * delta;
                float2 uv1a = i.uv - float2(0, 2.0) * delta;
                float2 uv1b = i.uv + float2(0, 2.0) * delta;

                float3 normal0 = GetNormal(uv);
                float3 normal1 = GetNormal(uv0a);
                float3 normal2 = GetNormal(uv0b);
                float3 normal3 = GetNormal(uv1a);
                float3 normal4 = GetNormal(uv1b);

                float4 col = SAMPLE_TEXTURE2D(_MyAmbientOcclusionTex, sampler_MyAmbientOcclusionTex, uv);
                float4 col0a = SAMPLE_TEXTURE2D(_MyAmbientOcclusionTex, sampler_MyAmbientOcclusionTex, uv0a);
                float4 col0b = SAMPLE_TEXTURE2D(_MyAmbientOcclusionTex, sampler_MyAmbientOcclusionTex, uv0b);
                float4 col1a = SAMPLE_TEXTURE2D(_MyAmbientOcclusionTex, sampler_MyAmbientOcclusionTex, uv1a);
                float4 col1b = SAMPLE_TEXTURE2D(_MyAmbientOcclusionTex, sampler_MyAmbientOcclusionTex, uv1b);

                half w = 0.4026;
                half w0a = CompareNormal(normal0, normal1) * 0.0545;
                half w0b = CompareNormal(normal0, normal2) * 0.0545;
                half w1a = CompareNormal(normal0, normal3) * 0.2442;
                half w1b = CompareNormal(normal0, normal4) * 0.2442;


                half3 result;
                result = w * col.rgb;
                result += w0a * col0a.rgb;
                result += w0b * col0b.rgb;
                result += w1a * col1a.rgb;
                result += w1b * col1b.rgb;

                result = result / (w + w0a + w0b + w1a + w1b);
                return float4(result, 1.0);
            }
            ENDHLSL
        }

        // 3 - Final Blur
        Pass
        {
            Name "SSAO_FinalBlur"

            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment FinalFrag

            TEXTURE2D_X(_MyAmbientOcclusionTex);
            SAMPLER(sampler_MyAmbientOcclusionTex);
            TEXTURE2D_X(_MainTex);
            SAMPLER(sampler_MainTex);
            float _DirectLightingStrength;

            float4 FinalFrag(Varyings i) : SV_Target
            {
                i.uv = i.positionCS.xy / _ScreenParams.xy;

                float2 uv = i.uv;

                float ao = SAMPLE_TEXTURE2D(_MyAmbientOcclusionTex, sampler_MyAmbientOcclusionTex, uv).r;
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);

                ao = lerp(1, ao, _DirectLightingStrength);
                //return ao;
                float3 finalCol = ao * col.rgb;
                return float4(finalCol, 1.0);
            }
            ENDHLSL
        }
    }
}