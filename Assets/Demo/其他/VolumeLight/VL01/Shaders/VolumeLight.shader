Shader "Unlit/VolumeLight"
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

    TEXTURE2D(_DecalTex);
    SAMPLER(sampler_DecalTex);
    float4 _DecalTex_ST;

    struct Attributes
    {
        float4 position : POSITION;
        float2 uv : TEXCOORD0;
        float4 normal : NORMAL;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        float2 uv : TEXCOORD0;
        float4 color : TEXCOORD1;
        float3 posWS : TEXCOORD2;
        float3 normalWS : TEXCOORD3;
        UNITY_VERTEX_OUTPUT_STEREO
    };

    float dot2(float3 v)
    {
        return dot(v, v);
    }

    float4 coneIntersect(in float3 ro, in float3 rd, in float3 pa, in float3 pb, in float ra, in float rb,
                         out float3 dis)
    {
        dis = float3(0, 0, 0);
        float3 ba = pb - pa;
        float3 oa = ro - pa;
        float3 ob = ro - pb;
        float m0 = dot(ba, ba);
        float m1 = dot(oa, ba);
        float m2 = dot(rd, ba);
        float m3 = dot(rd, oa);
        float m5 = dot(oa, oa);
        float m9 = dot(ob, ba);

        //
        // caps
        if (m1 < 0.0)
        {
            if (dot2(oa * m2 - rd * m1) < (ra * ra * m2 * m2)) // delayed division
            {
                dis.z = -m1 / m2;
                //return float4(-m1 / m2, -ba * sqrt(m0));
            }
        }
        else if (m9 > 0.0)
        {
            float t = -m9 / m2; // NOT delayed division
            if (dot2(ob + rd * t) < (rb * rb))
                dis.z = -m1 / m2;
            //return float4(t, ba * sqrt(m0));
        }

        // body
        float rr = ra - rb;
        float hy = m0 + rr * rr;
        float k2 = m0 * m0 - m2 * m2 * hy;
        float k1 = m0 * m0 * m3 - m1 * m2 * hy + m0 * ra * (rr * m2 * 1.0);
        float k0 = m0 * m0 * m5 - m1 * m1 * hy + m0 * ra * (rr * m1 * 2.0 - m0 * ra);
        float h = k1 * k1 - k2 * k0;
        if (h < 0.0) return -1.0; //no intersection
        float t = (-k1 - sqrt(h)) / k2;
        float y = m1 + t * m2;
        if (y < 0.0 || y > m0)
            return -1.0; //no intersection
        if (y > 0.0 && y < m0)
        {
            dis.x = t;
        }
        float t1 = t;
        t = (sqrt(h) - k1) / k2;
        y = m1 - ra * rr + t * m2;
        if (y > 0.0 && y < m0)
        {
            dis.y = t;
        }
        float t2 = t;
        dis = float3(t1, t2, dis.z);
        return float4(t, normalize(m0 * (m0 * (oa + t * rd) + rr * ba * ra) - ba * hy * y));
    }


    // 计算射线和圆锥求交
    float2 RayConeIntersection(float3 rayOrigin, float3 rayDirection, float3 coneOrigin, float3 coneDirection,
                               float coneAngle, float coneHeight)
    {
        float3 oc = rayOrigin - coneOrigin;

        float cosTheta = cos(coneAngle);
        float sinTheta = sin(coneAngle);

        // 计算与圆锥底部的交点
        float tBase = dot(coneDirection, coneOrigin - rayOrigin) / dot(coneDirection, rayDirection);

        // 计算与圆锥侧面的交点
        float a = dot(rayDirection, rayDirection) - (cosTheta * cosTheta) * dot(rayDirection, coneDirection) * dot(
            rayDirection, coneDirection);
        float b = 2.0 * (dot(rayDirection, oc) - (cosTheta * cosTheta) * dot(rayDirection, coneDirection) * dot(
            oc, coneDirection));
        float c = dot(oc, oc) - (cosTheta * cosTheta) * dot(oc, coneDirection) * dot(oc, coneDirection);

        float discriminant = b * b - 4.0 * a * c;

        float2 tValues;

        if (discriminant < 0.0)
        {
            // 没有与侧面相交的交点
            tValues.x = -1.0;
            tValues.y = -1.0;
        }
        else if (discriminant == 0.0)
        {
            // 射线与侧面相切
            float t = -b / (2.0 * a);
            if (t >= 0.0)
            {
                // 返回较近的交点
                tValues.x = t;
                tValues.y = -1.0;
            }
            else
            {
                tValues.x = -1.0;
                tValues.y = -1.0;
            }
        }
        else
        {
            // 射线与侧面相交于两个交点
            float t1 = (-b + sqrt(discriminant)) / (2.0 * a);
            float t2 = (-b - sqrt(discriminant)) / (2.0 * a);

            if (t1 >= 0.0 && t2 >= 0.0)
            {
                // 返回两个交点
                tValues.x = min(t1, t2);
                tValues.y = max(t1, t2);
            }
            else if (t1 >= 0.0)
            {
                tValues.x = t1;
                tValues.y = -1.0;
            }
            else if (t2 >= 0.0)
            {
                tValues.x = t2;
                tValues.y = -1.0;
            }
            else
            {
                tValues.x = -1.0;
                tValues.y = -1.0;
            }
        }

        // 检查与圆锥底部的交点是否更近
        if (tBase >= 0.0 && (tValues.x < 0.0 || tBase < tValues.x))
        {
            tValues.x = tBase;
        }

        return tValues;
    }


    //start：开始的距离
    //rd：视线向量
    //lightPos：灯光位置
    //两个交点的距离
    float InScatter(float3 start, float3 rd, float3 lightPos, float d)
    {
        float3 q = start - lightPos;
        float b = dot(rd, q);
        float c = dot(q, q);
        float iv = 1.0f / sqrt(c - b * b);
        float l = iv * (atan((d + b) * iv) - atan(b * iv));

        return l;
    }

    float GetAtten(float angle01, float angle02, float attenInt)
    {
        float n = 0; // step(angle01, angle02);
        float a = lerp((1 - angle01), (1 - angle02), n);
        float b = lerp((1 - angle02), (1 - angle01), n);
        float atten = 1 - saturate(a / b - attenInt);
        return atten;
    }

    float GetAtten2(float3 lightDr, float3 rd, float g)
    {
        float cosTheta = dot(lightDr, -rd);
        float result = 1 / (4 * 3.14) * (1 - pow(g, 2)) / pow(1 + pow(g, 2) - 2 * g * cosTheta, 1.5);
        return result;
    }
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline"
        }
        //        Cull Off 
        //        ZWrite Off 
        //        ZTest LEqual

        Pass
        {
            Name "MyVolumeLight"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            ZTest LEqual
            ZWrite Off
            Cull Off

            //Blend SrcAlpha OneMinusSrcAlpha
            //Blend Zero SrcColor

            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment Frag
            #pragma multi_compile_local _SOURCE_DEPTH _SOURCE_DEPTH_NORMALS _SOURCE_GBUFFER
            #pragma multi_compile_local _RECONSTRUCT_NORMAL_LOW _RECONSTRUCT_NORMAL_MEDIUM _RECONSTRUCT_NORMAL_HIGH
            #pragma multi_compile_local _ _ORTHOGRAPHIC

            TEXTURE2D_X(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);

            //float _RangeStrength;
            float4x4 _VPMatrix_invers;
            float4x4 _VMatrix;
            float4x4 _PMatrix;

            float4 _VolumeLightColor;
            float _alpahParams;
            float3 _LightPos;
            float _distance;

            float4 _ConeAParams; //pa、ra、pb、rb
            float4 _ConeBParams; //pa、ra、pb、rb
            float4 _VolumeLightParams;
            float3 _VolumeLightDir;

            float3 GetPosWS(float2 screenUV)
            {
                float depth_o = SAMPLE_TEXTURE2D_X(
                    _CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;;
                float eyeDepth = LinearEyeDepth(depth_o, _ZBufferParams);


                //把ndc坐标转换到世界空间
                float4 ndc = float4(screenUV * 2 - 1, (1 - depth_o) * 2 - 1, 1);
                float4 posWS = mul(_VPMatrix_invers, ndc);
                posWS /= posWS.w;

                return posWS.xyz;
            }

            inline float random(float2 uv)
            {
                return frac(sin(dot(uv.xy, float2(12.9898, 78.233))) * 43758.5453123);
            }

            Varyings VertDefault(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input); //GPU实例
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float3 posOS = input.position;
                //posOS.xz=posOS.xz*pow(_ConeBParams,posOS.y);
                posOS.xz = posOS.xz * (posOS.y * 0.5 + 0.5);

                //这个CS是屏幕空间的坐标
                output.color.rgb = posOS.xyz;
                output.positionCS = TransformObjectToHClip(posOS);
                output.uv = input.uv;
                output.posWS = TransformObjectToWorld(posOS);
                return output;
            }


            float4 Frag(Varyings i) : SV_Target
            {
                //return i.color.g;
                float4 color = 0;
                float2 screenUV = i.positionCS.xy / (_ScaledScreenParams.xy);
                
                float3 baseColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture,
                                                    sampler_CameraOpaqueTexture, screenUV).rgb;
                

                float3 endPosWS = i.posWS; //GetPosWS(screenUV);
                float3 curPos = _WorldSpaceCameraPos.xyz;
                float maxLen = min(length(endPosWS - curPos), 20);
                float3 dir = normalize(endPosWS - curPos);

                uint maxStep = 300;
                float stepDt = 0.025;
                float intensityPerStep = 0.015f;
                float3 dt = 0;
                float3 dis = float3(0, 0, 0);
                float outerAngle = cos(_VolumeLightParams.y);

                float4 n = coneIntersect(curPos, dir, _ConeAParams.xyz, _ConeBParams.xyz,
                                         _ConeAParams.w, _ConeBParams.w, dis);
                //float2 dis2 = RayConeIntersection(curPos,)
                //return abs(dis.y);

                float3 startPos;
                float3 startPos2;
                startPos = curPos + dir * (dis.x);
                startPos2 = curPos + dir * (dis.y);
                // if (dis.z == 0)
                // {
                //      startPos = curPos + dir * (dis.x);
                //      startPos2 = curPos + dir * (dis.y);
                // }
                // else if (dis.y == 0)
                // {
                //      startPos = curPos + dir * (dis.x);
                //      startPos2 = curPos + dir * (dis.z);
                // }
                // else
                // {
                //      startPos = curPos + dir * (dis.z);
                //      startPos2 = curPos + dir * (dis.x);
                // }

                float3 startPosMin = (startPos + startPos2) / 2;
                float3 startDir = normalize(startPosMin - _ConeAParams.xyz);
                float startDirDotLightDir = dot(startDir, _VolumeLightDir);
                //需要光的方向
                //垂直衰减
                float scale = InScatter(startPos, dir, _ConeAParams.xyz, abs(dis.x - dis.y) * _VolumeLightParams.z);
                scale = smoothstep(0.02, 1.0, scale);
                float atten = GetAtten(startDirDotLightDir, outerAngle,
                                       _VolumeLightParams.w);
                //水平衰减
                atten = pow((startDirDotLightDir - outerAngle), _VolumeLightParams.w) * 15;
                atten = saturate(atten);

                // float2 decalUV = normalize(_VolumeLightDir.xz);
                // decalUV = decalUV*0.5+0.5;
                // decalUV = TRANSFORM_TEX(decalUV,_DecalTex);
                // float detalColor = SAMPLE_TEXTURE2D(_DecalTex,
                //                                     sampler_DecalTex, decalUV).r;
                // return detalColor;

                //atten = GetAtten2(startDirDotLightDir,dir,_VolumeLightParams.w);

                //return scale;
                return float4(lerp(baseColor.rgb, _VolumeLightColor.rgb, atten * scale), 1);
                //return float4(lerp(baseColor.rgb, _VolumeLightColor.rgb, scale * atten), 1);
            }
            ENDHLSL
        }
    }
}