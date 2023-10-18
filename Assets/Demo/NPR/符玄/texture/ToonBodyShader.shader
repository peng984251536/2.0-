Shader "NPR/ToonBodyShader"
{
    Properties
    {
        _MainTex("MainTex",2D) = "while"{}
        _BaseColor("outline color",color) = (1,1,1,1)
        _IBLMap("_IBLMap",2D) = "while"{}

        _RampMap01("_RampMap01",2D) = "while"{}
        _RampMap02("_RampMap02",2D) = "while"{}
        _RampMap03("_RampMap03",2D) = "while"{}
        _MatCap("_MatCap",2D) = "while"{}

        _SpecularIns("_SpecularIns",float) = 1
        _SpecularWith("_SpecularWith",float) = 5
        
        _SepcularMatellicIns("_SepcularMatellicIns",float) = 1

        //----描边---------
        _EdgeWidth("_EdgeWidth",float) = 0.5
        _EdgeColor("_EdgeColor",color)= (1,1,1,1)

        [KeywordEnum(CoorHair,WarmHair,CoorBody,WarmBody)] _RAMP("_RampState", Float) = 0
        [Toggle(_HAIR)] _HAIR("_HAIR",Float)=0
        _DebugParams("_DebugParams",Vector) = (1,1,1,1)
    }
    Subshader
    {
        Tags
        {
            "RenderType" = "Opaque" "Queue" = "Geometry+5"
        }
        
        Pass
        {
            Tags
            {
                "LightMode" = "MyUniversalForward" "RenderType" = "Opaque" "Queue" = "Geometry+5"
            }

            Name "NPR_Pass"
            //Blend SrcAlpha OneMinusSrcAlpha
            ZTest On
            ZWrite On
            ZTest LEqual
            Cull Back



            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile_local _ _HAIR
            #pragma multi_compile_local _ _RAMP_COORHAIR _RAMP_WARMHAIR _RAMP_COORBODY _RAMP_WARMBODY
            //#pragma shader_feature _HAIR

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #define SKYBOX_RAMP_COORHAIR 0
            #define SKYBOX_RAMP_WARMHAIR 1
            #define SKYBOX_RAMP_COORBODY 2
            #define SKYBOX_RAMP_WARMBODY 3
            
            #ifndef SKYBOX_RAMP
            #if defined(_RAMP_COORHAIR)
                #define SKYBOX_RAMP SKYBOX_RAMP_COORHAIR
            #elif defined(_RAMP_WARMHAIR)
                #define SKYBOX_RAMP SKYBOX_RAMP_WARMHAIR
            #elif defined(_RAMP_COORBODY)
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
                float4 MatCapUV:TEXCOORD3;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;
            TEXTURE2D(_IBLMap);
            SAMPLER(sampler_IBLMap);
            TEXTURE2D(_RampMap01);
            SAMPLER(sampler_RampMap01);
            TEXTURE2D(_RampMap02);
            SAMPLER(sampler_RampMap02);
            TEXTURE2D(_RampMap03);
            SAMPLER(sampler_RampMap03);
            TEXTURE2D(_MatCap);
            SAMPLER(sampler_MatCap);

            half4 _BaseColor;
            half4 _DebugParams;
            float _SpecularIns;
            float _SpecularWith;
            float _SepcularMatellicIns;
            
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
                    dot(vTangent, o.normalWS)*1.75,
                    dot(vBinormal, o.normalWS)
                ) * 0.495 + 0.5;;

                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                float4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float4 iBLMap = SAMPLE_TEXTURE2D(_IBLMap, sampler_IBLMap, i.uv);

                i.normalWS = normalize(i.normalWS);
                float3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                float3 lightDir = normalize(_MainLightPosition.xyz);
                float3 halfDir = normalize(viewDirWS + lightDir);
                float NdotL = saturate(dot(i.normalWS, _MainLightPosition.xyz));
                float halfNdotL = NdotL * 0.5 + 0.5;
                float HdotN = saturate(dot(i.normalWS, halfDir));
                float VdotN = saturate(dot(viewDirWS, i.normalWS));
                //NdotL = smoothstep(0.5,0.6,NdotL);


                //--------基础色----------//
                float val1 = smoothstep(0, 0.08, NdotL);
                //float val2 = smoothstep(0,0.01,NdotL);
                float shadow = max(val1, 0.15);
                float2 uv = float2(shadow, iBLMap.a);
                //uv = float2(shadow,_DebugParams.w/10);
                float3 rampColor;
                #if SKYBOX_RAMP == SKYBOX_RAMP_COORHAIR
                    uv = float2(shadow, 0.75);
                    rampColor = SAMPLE_TEXTURE2D(_RampMap01, sampler_RampMap01, uv);
                #elif SKYBOX_RAMP == SKYBOX_RAMP_WARMHAIR
                    uv = float2(shadow, 0.25);
                    rampColor = SAMPLE_TEXTURE2D(_RampMap01, sampler_RampMap01, uv);
                #elif SKYBOX_RAMP == SKYBOX_RAMP_COORBODY
                    rampColor = SAMPLE_TEXTURE2D(_RampMap02, sampler_RampMap02, uv);
                #elif SKYBOX_RAMP == SKYBOX_RAMP_WARMBODY
                    rampColor = SAMPLE_TEXTURE2D(_RampMap03, sampler_RampMap03, uv);
                #endif
                float3 diffuseColor = baseMap.rgb * rampColor * _MainLightColor.rgb;
                float isAO = step(-0.1,iBLMap.r)-step(0.1,iBLMap.r);
                float isDiffuse = step(0.1,iBLMap.r)-step(1.1,iBLMap.r);
                diffuseColor = isAO * diffuseColor*diffuseColor + isDiffuse*diffuseColor ;
                //return float4(diffuseColor,1);

                //---------高光----------//
                float MatCap = SAMPLE_TEXTURE2D(_MatCap, sampler_MatCap,
                                                i.MatCapUV.xy).r;
                float sepcular;
                float sepcularMetallic;
                float2 _MatCapUV;
                #if defined(_HAIR)
                sepcular=iBLMap.g;
                sepcularMetallic = iBLMap.b;
                _MatCapUV = i.MatCapUV.zw;
                #else
                sepcular = iBLMap.g;
                sepcularMetallic = iBLMap.b;
                _MatCapUV = i.MatCapUV.zw;
                #endif

                
                //非金属的高光我可以尝试用BRDF代替
                float3 specularRamp;
                #if SKYBOX_RAMP == SKYBOX_RAMP_COORHAIR
                    specularRamp = SAMPLE_TEXTURE2D(_RampMap01, sampler_RampMap01, float2(0.1,iBLMap.a));
                #elif SKYBOX_RAMP == SKYBOX_RAMP_WARMHAIR
                    specularRamp = SAMPLE_TEXTURE2D(_RampMap01, sampler_RampMap01, float2(0.1,iBLMap.a));
                #elif SKYBOX_RAMP == SKYBOX_RAMP_COORBODY
                    specularRamp = SAMPLE_TEXTURE2D(_RampMap02, sampler_RampMap02, float2(0.1,iBLMap.a));
                #elif SKYBOX_RAMP == SKYBOX_RAMP_WARMBODY
                    specularRamp = SAMPLE_TEXTURE2D(_RampMap03, sampler_RampMap03, float2(0.1,iBLMap.a));
                #endif


                //-----菲涅尔----//
                float F0 = _DebugParams.x;
                float val2 = _DebugParams.y;
                float frenel = F0 +  (1-F0)*pow(1-VdotN,_SpecularWith);
                frenel = saturate(frenel);
                float3 frenelColor = specularRamp * frenel * sepcular;
                frenelColor = frenelColor*frenelColor*_SpecularIns;
                //return frenel;


                //---------金属效果----------//
                float MatCap2 = SAMPLE_TEXTURE2D(_MatCap, sampler_MatCap,_MatCapUV).r;
                specularRamp = SAMPLE_TEXTURE2D(_RampMap03, sampler_RampMap03, float2(0.2,0));
                half specularMatel = MatCap * pow(sepcularMetallic, 2) * shadow;
                //specularMatel = pow(HdotN, _SpecularWith);
                //specularMatel = step(_DebugParams.w,specularMatel) ;
                float3  specularMatelColor =MatCap2* _SepcularMatellicIns * specularRamp*sepcularMetallic*shadow*iBLMap.r;
                //return MatCap;
                //return float4(i.MatCapUV,0,1);

                
                //------最终颜色混合------//
                float3 finalColor = 0;
                if (_DebugLog == 0)
                {
                    finalColor = specularMatelColor;
                    //finalColor = diffuseColor;
                    finalColor = frenelColor*0.9+diffuseColor+specularMatelColor;
                    //finalColor = frenelColor;
                    //finalColor += diffuseColor+specularColor;
                    //finalColor = diffuseColor + specularMatelColor;
                    //finalColor = 0;
                }
                else if (_DebugLog == 1)
                {
                    finalColor = iBLMap.r;
                }
                else if (_DebugLog == 2)
                {
                    finalColor = iBLMap.g;
                }
                else if (_DebugLog == 3)
                {
                    finalColor = iBLMap.b;
                }
                else if (_DebugLog == 4)
                {
                    if (iBLMap.a > _DebugParams.x && iBLMap.a < _DebugParams.y)
                    {
                        finalColor = iBLMap.a;
                    }
                    else
                    {
                        finalColor = 0;
                    }
                    //finalColor = iBLMap.a;
                }

                return float4(finalColor.rgb, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Tags
            {
                "LightMode" = "SRPDefaultUnlit" "RenderType" = "Opaque+500" "Queue" = "Geometry"
            }

            Name "Outline_Pass"
            //Blend SrcAlpha OneMinusSrcAlpha
            ZTest On
            ZWrite Off
            ZTest LEqual
            Cull Front


            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float _EdgeWidth;
            float3 _EdgeColor;


            // UNITY_INSTANCING_BUFFER_START(Props)
            //     //props是buffer模块名称访问时用到
            //     UNITY_DEFINE_INSTANCED_PROP(Props,_DebugLog)
            // UNITY_INSTANCING_BUFFER_END(Props)
            float _DebugLog;

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                //v.vertex.xyz += _Width * normalize(v.vertex.xyz);

                // o.vertex = TransformObjectToHClip(v.vertex.xyz);
                // o.normalWS = TransformObjectToWorldNormal(v.normal);
                // o.posWS = TransformObjectToWorld(v.vertex);
                float3 newVertex = v.vertex + _EdgeWidth * v.normal * 0.01;
                o.vertex = TransformObjectToHClip(float4(newVertex, 1));
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float3 edgeColor = _EdgeColor;

                return float4(edgeColor.rgb, 1);
            }
            ENDHLSL
        }
    }

	Fallback "Hidden/InternalErrorShader"
}