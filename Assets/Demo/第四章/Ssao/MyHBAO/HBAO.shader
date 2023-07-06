Shader "HBAO"
{
    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    // float _BilaterFilterFactor; //法线判定的插值
    // float2 _BlurRadius; //滤波的采样范围
    float4 _bilateralParams; //x:BlurRadius.x||y:BlurRadius.y||z:BilaterFilterFactor
    #define BilaterFilterFactor _bilateralParams.z
    #define DirectLightingStrength _bilateralParams.w


    struct a2v
    {
        uint vertexID :SV_VertexID;
    };

    struct v2f
    {
        float4 pos:SV_Position;
        float2 uv:TEXCOORD0;
    };

    v2f vert(a2v IN)
    {
        v2f o;
        o.pos = GetFullScreenTriangleVertexPosition(IN.vertexID);
        o.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
        return o;
    }
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {

            Name "HBAO"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_local _ _TESTVIEWPOS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"


            #define DIRECTIONS 8
            #define STEPS 6
            StructuredBuffer<float2> _NoiseCB;
            float4 _NoiseCB2[16];
            float _Intensity;
            float _Radius;
            float _MaxRadiusPixels;
            float _AngleBias;
            float _DistanceFalloff;
            float _NegInvRadius2;
            float2 _CameraDepthTexture_TexelSize;

            float4x4 _PMatrix_invers;
            float4x4 _VMatrix_invers;
            float4x4 _VMatrix;
            float4x4 _PMatrix;

            //获取摄像机空间坐标
            float3 GetViewPos(float2 uv)
            {
                //采样到的depth，0代表最远处，1代表最近处
                float depth = SampleSceneDepth(uv);
                float2 newUV = float2(uv.x, uv.y);
                newUV = newUV * 2 - 1;

                #if defined(_TESTVIEWPOS)
                    depth = 1-depth;
                    float4 viewPos = mul(_PMatrix_invers, float4(newUV, depth*2-1, 1));
                    viewPos /= viewPos.w;
                    viewPos.z = -viewPos.z;
                    //return viewPos.xyz;
                #else
                float4 viewPos = mul(UNITY_MATRIX_I_P, float4(newUV, depth, 1));
                viewPos /= viewPos.w;
                viewPos.z = -viewPos.z;
                #endif

                return viewPos.xyz;
            }

            //获取摄像机空间的法线
            float3 FetchViewNormals(float2 uv)
            {
                float3 N = SampleSceneNormals(uv);
                N = normalize(mul(_VMatrix, N));
                // //为啥要反转yz
                // N.y = -N.y;
                N.z = -N.z;

                return N;
            }

            //做AO衰减
            float Falloff(float distanceSquare, float radius)
            {
                //v的模越大，则认为衰减越多
                return 1 + distanceSquare * _NegInvRadius2;
                return 1 - distanceSquare / (radius * radius);
            }

            //通过对比
            float ComputeAO(float3 p, float3 n, float3 s, float radius)
            {
                //得到原始坐标到偏移坐标的向量
                float3 v = s - p;
                //计算这个向量的模
                float VoV = dot(v, v);
                // 计算这个向量 映射到法线向量的值，如果这个值大于某一范围，就认为产生了ao
                // Nov越大，则认为N 与 V 的距离越小，认为产生的ao越大（nv夹角越小，ao越明显）
                // rsqrt = 开平方 + 倒数
                float NoV = dot(n, v) * rsqrt(VoV);
                float weight = saturate(Falloff(VoV, radius)); //根据距离衰减
                //return weight;
                return saturate(NoV - _AngleBias) * weight;
            }


            half4 frag(v2f IN) : SV_Target
            {
                float2 uv = IN.uv;

                float3 viewPos = GetViewPos(uv);
                //return float4(viewPos.xyz, 1);
                //如果当前像素的深度值超过最大深度就无AO
                if (viewPos.z >= _ProjectionParams.z * 0.99)
                {
                    return 1;
                }

                float3 nor = FetchViewNormals(uv);
                //return float4(nor,1);

                //获取随机的坐标
                int noiseX = (uv.x * _ScreenParams.x) % 4;
                int noiseY = (uv.y * _ScreenParams.y) % 4;
                int noiseIndex = 4 * noiseY + noiseX;
                float2 rand = _NoiseCB[noiseIndex];
                //return float4(rand, 0, 1);

                //射线的半径
                //深度值越大stepSize越小。【0-50】/7
                float stepSize = min(_Radius / viewPos.z, _MaxRadiusPixels) / (STEPS + 1.0);
                //stepSize = min(_Radius, _MaxRadiusPixels) / (STEPS + 1.0);;
                float stepAng = TWO_PI / DIRECTIONS;

                float ao = 0;
                UNITY_UNROLL
                for (int d = 0; d < DIRECTIONS; ++d)
                {
                    //计算出随机的角度，由于把其分成了8个线段
                    //所以计算8个随机角度
                    float angle = stepAng * (float(d) + rand.x);

                    float cosAng, sinAng;
                    sincos(angle, sinAng, cosAng);
                    float2 direction = float2(cosAng, sinAng);


                    //随机射线长度，需要进行6次采样，所以其值为
                    // [0-7] * [0-1] +1
                    float rayPixels = frac(rand.y) * stepSize + 1.0;
                    //rayPixels = _MaxRadiusPixels;

                    float radius = stepSize * (STEPS + 1);
                    float pixelAO = 0;
                    UNITY_UNROLL
                    for (int s = 0; s < STEPS; ++s)
                    {
                        //根据射线和旋转的方向得出新的位置（newPos），进行uv偏移
                        float2 snappedUV = round(rayPixels * direction) *
                            float2(1 / _ScreenParams.x, 1 / _ScreenParams.y) + uv;
                        //利用偏移的uv得出新的屏幕空间坐标
                        float3 tempViewPos = GetViewPos(snappedUV);
                        float tempAO = ComputeAO(viewPos, nor, tempViewPos, _Radius);
                        rayPixels += stepSize;
                        pixelAO += tempAO;
                    }

                    ao += (pixelAO / STEPS);
                }
                ao /= DIRECTIONS;

                return 1 - ao * _Intensity;
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
            #pragma vertex vert
            #pragma fragment frag_bilateralnormal
            #pragma multi_compile_local _SOURCE_DEPTH _SOURCE_DEPTH_NORMALS _SOURCE_GBUFFER
            #pragma multi_compile_local _RECONSTRUCT_NORMAL_LOW _RECONSTRUCT_NORMAL_MEDIUM _RECONSTRUCT_NORMAL_HIGH
            #pragma multi_compile_local _ORTHOGRAPHIC

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

            float4 frag_bilateralnormal(v2f i) : SV_Target
            {
                float2 delta = _MyAmbientOcclusionTex_TexelSize.xy * _bilateralParams.xy;

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
            #pragma vertex vert
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

            float4 frag_bilateralnormal(v2f i) : SV_Target
            {
                float2 delta = _MyAmbientOcclusionTex_TexelSize.xy * _bilateralParams.xy;

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
            #pragma vertex vert
            #pragma fragment FinalFrag

            TEXTURE2D_X(_MyAmbientOcclusionTex);
            SAMPLER(sampler_MyAmbientOcclusionTex);
            TEXTURE2D_X(_MainTex);
            SAMPLER(sampler_MainTex);

            float4 FinalFrag(v2f i) : SV_Target
            {
                float2 uv = i.uv;

                float ao = SAMPLE_TEXTURE2D(_MyAmbientOcclusionTex, sampler_MyAmbientOcclusionTex, uv).r;
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);

                ao = lerp(1, ao, DirectLightingStrength);
                //return ao;
                float3 finalCol = ao * col.rgb;
                return float4(finalCol, 1.0);
            }
            ENDHLSL
        }
    }
}