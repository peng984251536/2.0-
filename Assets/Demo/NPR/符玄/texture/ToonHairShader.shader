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

        //[KeywordEnum(Low,Medium,High,Best)] _Q("Quality mode", Float) = 0
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
            "RenderType" = "Opaque" "Queue" = "Geometry+5"
        }
        Pass
        {
            Tags
            {
                "LightMode" = "MyUniversalForward" "RenderType" = "Opaque" "Queue" = "Geometry"
            }

            Name "NPR_Pass"
            //Blend SrcAlpha OneMinusSrcAlpha
            ZTest On
            ZWrite On
            ZTest LEqual
            Cull Back

            Stencil
            {
                Ref[_SRef]
                Comp[_SComp]
                Pass keep
                Fail keep
                ZFail keep
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile_local _ _HAIR
            //#pragma shader_feature _HAIR

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
                float2 MatCapUV:TEXCOORD3;
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

                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                o.posWS = TransformObjectToWorld(v.vertex);

                float NdotV_x = dot(normalize(UNITY_MATRIX_V[0].xyz), o.normalWS);
                float NdotV_y = dot(normalize(UNITY_MATRIX_V[1].xyz), o.normalWS);
                float2 NdotV = float2(NdotV_x * 1.8, NdotV_y) * 0.5 + 0.5;
                //---
                float normalVS = TransformWorldToViewDir(o.normalWS);
                float3 viewDir = normalize(o.posWS - _WorldSpaceCameraPos.xyz);
                float3 vTangent =  normalize( cross(viewDir, float3(0, 1, 0)));
                float3 vBinormal = normalize( cross(viewDir, vTangent)      );
                float2 matCapUV = float2(
                    dot(vTangent, o.normalWS),
                    dot(vBinormal, o.normalWS)
                ) * 0.495 + 0.5;
                matCapUV.x*=2.0;
                o.MatCapUV = matCapUV;


                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                float4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float4 iBLMap = SAMPLE_TEXTURE2D(_IBLMap, sampler_IBLMap, i.uv);


                float3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                float3 lightDir = normalize(_MainLightPosition.xyz);
                float3 halfDir = normalize(viewDirWS + lightDir);
                float NdotL = saturate(dot(i.normalWS, _MainLightPosition.xyz));
                float halfNdotL = NdotL * 0.5 + 0.5;
                float HdotN = saturate(dot(i.normalWS, halfDir));
                float VdotN = saturate(dot(viewDirWS, i.normalWS));
                //NdotL = smoothstep(0.5,0.6,NdotL);


                //--------基础色----------//
                float val1 = smoothstep(0, 0.03, NdotL);
                //float val2 = smoothstep(0,0.01,NdotL);
                float shadow = max(val1 * iBLMap.r, 0.15);
                float2 uv = float2(shadow, iBLMap.a);
                //uv = float2(shadow,_DebugParams.w/10);
                float3 rampColor;
                if (_DebugParams.z == 1)
                {
                    uv = float2(shadow, 0.75);
                    rampColor = SAMPLE_TEXTURE2D(_RampMap01, sampler_RampMap01, uv);
                }
                else if (_DebugParams.z == 2)
                {
                    rampColor = SAMPLE_TEXTURE2D(_RampMap02, sampler_RampMap02, uv);
                }
                else if (_DebugParams.z == 3)
                {
                    rampColor = SAMPLE_TEXTURE2D(_RampMap03, sampler_RampMap03, uv);
                }


                float3 diffuseColor = baseMap.rgb * rampColor * _MainLightColor.rgb; //*NdotL;
                //return val1;
                //return float4(RampMap02,1);

                //---------高光----------//
                float MatCap = SAMPLE_TEXTURE2D(_MatCap, sampler_MatCap,
                                                i.MatCapUV).r;
                float sepcular;
                float sepcularMetallic;
                #if defined(_HAIR)
                sepcular=0;
                sepcularMetallic = iBLMap.b;
                #else
                sepcular=iBLMap.g;
                sepcularMetallic = iBLMap.b;
                #endif
                //非金属的高光我可以尝试用BRDF代替
                float3 specularRamp;
                if (_DebugParams.z == 1)
                {
                    specularRamp = SAMPLE_TEXTURE2D(_RampMap01, sampler_RampMap01, float2(0.1,iBLMap.a));
                }
                else if (_DebugParams.z == 2)
                {
                    specularRamp = SAMPLE_TEXTURE2D(_RampMap02, sampler_RampMap02, float2(0.1,1-iBLMap.a));
                }
                else if (_DebugParams.z == 3)
                {
                    specularRamp = SAMPLE_TEXTURE2D(_RampMap03, sampler_RampMap03, float2(0.1,1-iBLMap.a));
                }
                //sepcular = pow(HdotN, _SpecularWith) * iBLMap.g;
                //float fresel = 
                float3 specularColor =sepcular * MatCap * _SpecularIns * specularRamp;

                
                //---------金属效果----------//
                specularRamp = SAMPLE_TEXTURE2D(_RampMap03, sampler_RampMap03, float2(0.1,0));
                half specularMatel = MatCap*pow(sepcularMetallic,2) * shadow;
                //specularMatel = pow(HdotN, _SpecularWith)*sepcularMetallic;
                //specularMatel = step(_DebugParams.w,specularMatel) ;
                float3 specularMatelColor = specularMatel * _SepcularMatellicIns * specularRamp;
                //return MatCap;
                //return float4(i.MatCapUV,0,1);

                float3 finalColor = 0;
                if (_DebugLog == 0)
                {
                    finalColor = diffuseColor + specularColor;
                    finalColor = diffuseColor;
                    //finalColor = specularMatelColor;
                    finalColor = diffuseColor+specularColor+specularMatelColor;
                    //finalColor = diffuseColor + specularMatelColor;
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
                "LightMode" = "SRPDefaultUnlit" "RenderType" = "Opaque" "Queue" = "Geometry"
            }

            
            Name "Outline"
            //Blend SrcAlpha OneMinusSrcAlpha
            ZTest On
            ZWrite Off
            ZTest LEqual
            Cull Front

//            Stencil
//            {
//                Ref[_SRef]
//                Comp[_SComp]
//                Pass keep
//                Fail keep
//                ZFail [_SComp]
//            }

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
}