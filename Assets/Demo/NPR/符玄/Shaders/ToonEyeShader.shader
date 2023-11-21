Shader "NPR/ToonEyeShader"
{
    Properties
    {
        _MainTex("MainTex",2D) = "while"{}
        _BaseColor("outline color",color) = (1,1,1,1)
        _LightingMap("_LightingMap",2D) = "while"{}
        _ShadowOffset("_ShadowOffset",Range(-0.5,0.5)) = -0.1

        _RampMap02("_RampMap02",2D) = "while"{}
        _RampMap03("_RampMap03",2D) = "while"{}

        _SpecularIns("_SpecularIns",float) = 1
        _SpecularWith("_SpecularWith",float) = 5

        //----描边---------
        _EdgeWidth("_EdgeWidth",float) = 0.5
        _EdgeColor("_EdgeColor",color)= (1,1,1,1)

        [KeywordEnum(CoorBody,WarmBody)] _RAMP("_RampState", Float) = 0
        [Toggle(_HAIR)] _HAIR("_HAIR",Float)=0
        _DebugParams("_DebugParams",Vector) = (1,1,1,1)

        _SRef("Stencil Ref", Float) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _SComp("Stencil Comp", Float) = 8
        [Enum(UnityEngine.Rendering.StencilOp)] _SOp("Stencil Op", Float) = 1
    }
    Subshader
    {
        Tags
        {
            "Queue" = "Geometry+5"
        }

        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward" "RenderType" = "Opaque" "Queue" = "Geometry"
            }

            Name "Eye_NPR_Pass"
            //Blend SrcAlpha OneMinusSrcAlpha
            ZTest On
            ZWrite On
            ZTest LEqual
            Cull Back

            Stencil
            {
                Ref[_SRef]
                Comp[_SComp]
                Pass[_SOp]
                Fail keep
                ZFail [_SOp]
            }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile_local _ _HAIR
            #pragma multi_compile_local _ _RAMP_COORBODY _RAMP_WARMBODY
            //#pragma shader_feature _HAIR

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            #define SKYBOX_RAMP_COORBODY 0
            #define SKYBOX_RAMP_WARMBODY 1

            #ifndef SKYBOX_RAMP
            #if defined(_RAMP_COORBODY)
                #define SKYBOX_RAMP SKYBOX_RAMP_COORBODY
            #elif defined(_RAMP_WARMBODY)
                #define SKYBOX_RAMP SKYBOX_RAMP_WARMBODY
            #else
            #define SKYBOX_RAMP SKYBOX_RAMP_WarmBody
            #endif
            #endif

            struct appdata
            {
                float4 vertex: POSITION;
                float3 normal:NORMAL;
                float2 uv :TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex: SV_POSITION;
                float2 uv:TEXCOORD0;
                float3 normalWS:TEXCOORD1;
                float3 posWS:TEXCOORD2;
                float3 faceDorWS:TEXCOORD4;
                float4 MatCapUV:TEXCOORD3;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;
            TEXTURE2D(_LightingMap);
            SAMPLER(sampler_LightingMap);
            TEXTURE2D(_RampMap02);
            SAMPLER(sampler_RampMap02);
            TEXTURE2D(_RampMap03);
            SAMPLER(sampler_RampMap03);

            half4 _BaseColor;
            half4 _DebugParams;
            float _SpecularIns;
            float _SpecularWith;
            float _ShadowOffset;

            float _DebugLog;

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                //v.vertex.xyz += _Width * normalize(v.vertex.xyz);

                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                o.posWS = TransformObjectToWorld(v.vertex);

                float NdotV_x = dot(normalize(UNITY_MATRIX_V[0].xyz), o.normalWS);
                float NdotV_y = dot(normalize(UNITY_MATRIX_V[1].xyz), o.normalWS);
                float2 NdotV = float2(NdotV_x * 1.8, NdotV_y) * 0.5 + 0.5;
                //---
                float normalVS = TransformWorldToViewDir(o.normalWS);
                float3 viewDir = normalize(o.posWS - _WorldSpaceCameraPos.xyz);
                float3 vTangent = normalize(cross(viewDir, float3(0, 1, 0)));
                float3 vBinormal = normalize(cross(viewDir, vTangent));
                float2 matCapUV = float2(
                    dot(vTangent, o.normalWS),
                    dot(vBinormal, o.normalWS)
                ) * 0.495 + 0.5;
                o.MatCapUV.xy = matCapUV;
                o.MatCapUV.zw = float2(
                    dot(vTangent, o.normalWS) * 1.75,
                    dot(vBinormal, o.normalWS)
                ) * 0.495 + 0.5;;

                float3 faceDirOS = float3(0, 0, 1);
                o.faceDorWS = TransformObjectToWorld(faceDirOS);

                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                float4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                i.normalWS = normalize(i.normalWS);
                i.faceDorWS = normalize(i.faceDorWS);
                float3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                float3 lightDir = normalize(_MainLightPosition.xyz);
                float3 halfDir = normalize(viewDirWS + lightDir);
                float NdotL = saturate(dot(i.normalWS, _MainLightPosition.xyz));
                float halfNdotL = NdotL * 0.5 + 0.5;
                float HdotN = saturate(dot(i.normalWS, halfDir));
                float VdotN = saturate(dot(viewDirWS, i.normalWS));
                //NdotL = smoothstep(0.5,0.6,NdotL);


                //---------脸部SDF----------//
                half3 F = SafeNormalize(half3(i.faceDorWS.x, 0.0, i.faceDorWS.z));
                half3 L = SafeNormalize(half3(lightDir.x, 0.0, lightDir.z));
                half FDotL = dot(F, L);
                half FCrossL = cross(F, L).y;
                float2 shadowUV = i.uv;
                //判断方向
                shadowUV.x = lerp(shadowUV.x, 1.0 - shadowUV.x, step(0.0, FCrossL));
                float4 lightingMap = SAMPLE_TEXTURE2D(_LightingMap, sampler_LightingMap, shadowUV);
                half faceShadow = step(-0.5 * FDotL + 0.5 + _ShadowOffset, lightingMap.a);
                faceShadow = smoothstep
                (
                    -0.5 * FDotL + 0.5 + _ShadowOffset,
                    -0.5 * FDotL + 0.5 + _ShadowOffset + 0.01,
                    lightingMap.a
                );
                //return faceShadow;

                //--------基础色----------//
                float3 rampColor;
                float2 uv = float2(faceShadow + _DebugParams.w, 0.1);
                #if SKYBOX_RAMP == SKYBOX_RAMP_COORBODY
                //return 0.55;
                rampColor = SAMPLE_TEXTURE2D(_RampMap02, sampler_RampMap02, uv);
                #elif SKYBOX_RAMP == SKYBOX_RAMP_WARMBODY
                    //return 1;
                    rampColor = SAMPLE_TEXTURE2D(_RampMap03, sampler_RampMap03, uv);
                #endif
                float3 diffuseColor = baseMap.rgb * rampColor;
                //return float4(diffuseColor,1);
                //return lightingMap.g;

                //-----菲涅尔----//
                float F0 = _DebugParams.x;
                float val2 = _DebugParams.y;
                float frenel = F0 * pow(1 - VdotN, _SpecularWith);
                frenel = saturate(frenel);
                float3 frenelColor = rampColor * frenel * _SpecularIns;
                //return frenel;
                //return float4(frenelColor,1);


                float3 finalColor = 0;
                finalColor = frenelColor;
                //finalColor = diffuseColor;
                finalColor = frenelColor * 0.9 + diffuseColor;
                //finalColor = specularMatelColor;
                //finalColor += diffuseColor+specularColor;
                finalColor = diffuseColor + frenelColor;

                return float4(finalColor.rgb, 1);
            }
            ENDHLSL
        }


//        Pass
//        {
//
//            Tags
//            {
//                "LightMode" = "StencilMaskRead" "RenderType" = "Opaque" "Queue" = "Geometry"
//            }
//
//            Name "Eye_StencilMaskRead"
//            //Blend One Zero, One Zero
//            //Blend SrcAlpha OneMinusSrcAlpha
//            ZTest On
//            ZWrite Off
//            ZTest LEqual
//            Cull Back
//
//            Stencil
//            {
//                Ref[_SRef]
//                Comp[_SComp]
//                Pass[_SOp]
//                Fail keep
//                ZFail [_SOp]
//            }
//
//            HLSLPROGRAM
//            #pragma vertex vert
//            #pragma fragment frag
//            #pragma multi_compile_instancing
//
//            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
//
//            TEXTURE2D(_LightingMap);
//            SAMPLER(sampler_LightingMap);
//
//            float4 _LightingMap_ST;
//            float _DebugLog;
//
//            struct appdata
//            {
//                float4 vertex: POSITION;
//                float3 normal:NORMAL;
//                float2 uv :TEXCOORD0;
//                UNITY_VERTEX_INPUT_INSTANCE_ID
//            };
//
//            struct v2f
//            {
//                float4 vertex: SV_POSITION;
//                float2 uv:TEXCOORD0;
//                float3 normalWS:TEXCOORD1;
//                float3 posWS:TEXCOORD2;
//
//                UNITY_VERTEX_INPUT_INSTANCE_ID
//                UNITY_VERTEX_OUTPUT_STEREO
//            };
//
//            // UNITY_INSTANCING_BUFFER_START(Props)
//            //     //props是buffer模块名称访问时用到
//            //     UNITY_DEFINE_INSTANCED_PROP(Props,_DebugLog)
//            // UNITY_INSTANCING_BUFFER_END(Props)
//
//
//            v2f vert(appdata v)
//            {
//                v2f o;
//                UNITY_SETUP_INSTANCE_ID(v);
//                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
//                UNITY_TRANSFER_INSTANCE_ID(v, o);
//                o.vertex = TransformObjectToHClip(v.vertex);
//                o.uv = TRANSFORM_TEX(v.uv, _LightingMap);
//                return o;
//            }
//
//            half4 frag(v2f i) : SV_Target
//            {
//                UNITY_SETUP_INSTANCE_ID(i);
//                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
//
//                float4 lightingMap = SAMPLE_TEXTURE2D(_LightingMap, sampler_LightingMap, i.uv);
//
//                //return lightingMap.g;
//                if (lightingMap.g < 0.5)
//                {
//                    discard;
//                }
//
//                return 0;
//            }
//            ENDHLSL
//        }
    }
    
    Fallback "Hidden/InternalErrorShader"
}