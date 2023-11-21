Shader "NPR/ToonBodyShader"
{
    Properties
    {
        _MainTex("MainTex",2D) = "while"{}
        _BaseColor("outline color",color) = (1,1,1,1)
        _IBLMap("_IBLMap",2D) = "while"{}
        _StencilMaskMap("_StencilMaskMap",2D) = "while"{}

        _RampMap01("_RampMap01",2D) = "while"{}
        _RampMap02("_RampMap02",2D) = "while"{}
        _RampMap03("_RampMap03",2D) = "while"{}
        _MatCap("_MatCap",2D) = "while"{}

        _FrenelVal("_FrenelVal",float) = 0.14
        _SpecularIns("_FrenelIns",float) = 1
        _SpecularWith("_FrenelWith",float) = 5

        _SepcularMatellicIns("_SepcularMatellicIns",float) = 1

        //----描边---------
        _EdgeWidth("_EdgeWidth",float) = 0.5
        _EdgeColor("_EdgeColor",color)= (1,1,1,1)
        _EdgeViewScale("_EdgeViewScale",range(0.01,20))= 5
    	_EdgeOutLineOffset("_EdgeOutLineOffset",Vector) = (0,0,0,0)
        [Toggle(_SoomthNormal)] _SoomthNormal("_SoomthNormal",Float)=0

        [KeywordEnum(CoorHair,WarmHair,CoorBody,WarmBody)] _RAMP("_RampState", Float) = 0
        [Toggle(_HAIR)] _HAIR("_HAIR",Float)=0
        _DebugParams("_DebugParams",Vector) = (1,1,1,1)

        //溶解效果
        
        _SRef("Stencil Ref", Float) = 20
        [Enum(UnityEngine.Rendering.CompareFunction)] _SComp("Stencil Comp", Float) = 6
        [Enum(UnityEngine.Rendering.StencilOp)] _SOp("Stencil Op", Float) = 3
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
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS _ADDITIONAL_OFF
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_instancing
            #pragma multi_compile_local _ _HAIR
            //#pragma shader_feature _HAIR


            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "NPRFunction.hlsl"

            //ShadowCaster

            half4 _BaseColor;
            half4 _DebugParams;
            float _SpecularIns;
            float _SpecularWith;
            float _SepcularMatellicIns;
            float _FrenelVal;
            

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

                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);
                Light lightMain = GetMainLight(shadowCoord);
                
                float3 NPR_Color = NPR_body(i, lightMain, _FrenelVal, _SpecularWith, _SpecularIns,
                                            _SepcularMatellicIns, _DebugParams, _DebugLog);

                #ifdef _ADDITIONAL_LIGHTS
                float3 All_Add_Color = 0;
				int transPixelLightCount = GetAdditionalLightsCount();
				for (int j = 0; j < transPixelLightCount; ++j)
				{
					Light light = GetAdditionalLight(j, i.posWS);
					//light.shadowAttenuation *= light.distanceAttenuation;

				    float3 NPR_Add_Color = NPR_Add_body(i, light, _FrenelVal, _SpecularWith, _SpecularIns,
                                            _SepcularMatellicIns, _DebugParams, _DebugLog);
				    All_Add_Color+=NPR_Add_Color;
				}
            	//return float4(All_Add_Color, 1);
                //return float4(NPR_Color, 1);
                return float4(All_Add_Color+NPR_Color, 1);
                #endif

                return float4(NPR_Color, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Tags
            {
                "LightMode" = "MySRPDefaultUnlit" "RenderType" = "Opaque+500" "Queue" = "Geometry"
            }

            Name "Outline_Pass"
            //Blend SrcAlpha OneMinusSrcAlpha
            ZTest On
            ZWrite On
            ZTest LEqual
            Cull Front


            HLSLPROGRAM
            #pragma vertex OutLineVert
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "NPRFunction.hlsl"

            //float3 _EdgeColor;

            half4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float3 edgeColor = _EdgeColor;

                return float4(edgeColor.rgb, 1);
            }
            ENDHLSL
        }

        Pass
        {

            Tags
            {
                "LightMode" = "StencilMaskRead" "RenderType" = "Opaque" "Queue" = "Geometry"
            }

            Name "Body_StencilMaskRead"
            //Blend One Zero, One Zero
            Blend SrcAlpha OneMinusSrcAlpha
            ZTest On
            ZWrite Off
            ZTest LEqual
            Cull Back

            Stencil
            {
                Ref[_SRef]
                Comp[_SComp]
                Pass[_SOp]
                Fail keep
                ZFail keep
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_StencilMaskMap);
            SAMPLER(sampler_StencilMaskMap);

            float4 _StencilMaskMap_ST;
            float _DebugLog;

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

            // UNITY_INSTANCING_BUFFER_START(Props)
            //     //props是buffer模块名称访问时用到
            //     UNITY_DEFINE_INSTANCED_PROP(Props,_DebugLog)
            // UNITY_INSTANCING_BUFFER_END(Props)


            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _StencilMaskMap);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float4 lightingMap = SAMPLE_TEXTURE2D(_StencilMaskMap, sampler_StencilMaskMap, i.uv);

                //return lightingMap.r;
                if (lightingMap.r < 0.5)
                {
                    discard;
                }

                return 0;
            }
            ENDHLSL
        }

        Pass
        {

            Tags
            {
                "LightMode" = "CharacterShadow" "RenderType" = "Opaque" "Queue" = "Geometry"
            }

            Name "Body_NPRCharShadow"
            //Blend One Zero, One Zero
            ZTest On
            ZWrite On
            ZTest LEqual
            Cull Back


            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Assets/Demo/CharacterShadow/Shaders/NPR_Shadow.hlsl"
            
            #pragma vertex CharShadowVert
            #pragma fragment ShadowPassFragment
            //#pragma fragment ShadowRampFragment
            #pragma multi_compile_instancing



            TEXTURE2D(_StencilMaskMap);
            SAMPLER(sampler_StencilMaskMap);

            float4 _StencilMaskMap_ST;
            float _DebugLog;


            // UNITY_INSTANCING_BUFFER_START(Props)
            //     //props是buffer模块名称访问时用到
            //     UNITY_DEFINE_INSTANCED_PROP(Props,_DebugLog)
            // UNITY_INSTANCING_BUFFER_END(Props)
            ENDHLSL
        }
        
        Pass
        {
			
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormalsOnly" }

			ZTest LEqual
			ZWrite On

        
			HLSLPROGRAM
			
			#pragma multi_compile_instancing
			#define ASE_SRP_VERSION 999999

			
			#pragma only_renderers d3d11 glcore gles gles3 
			#pragma multi_compile_fog
			#pragma instancing_options renderinglayer
			#pragma vertex vert
			#pragma fragment frag

        
			#define ATTRIBUTES_NEED_NORMAL
			#define ATTRIBUTES_NEED_TANGENT
			#define VARYINGS_NEED_NORMAL_WS

			#define SHADERPASS SHADERPASS_DEPTHNORMALSONLY

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
        
			

			struct VertexInput
			{
				float4 vertex : POSITION;
				float3 ase_normal : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutput
			{
				float4 clipPos : SV_POSITION;
				float3 normalWS : TEXCOORD0;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};
        
			CBUFFER_START(UnityPerMaterial)
			float4 _baseColor;
			float _Metallic;
			float _Smoothness;
			#ifdef TESSELLATION_ON
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END
			

			      
			struct SurfaceDescription
			{
				float Alpha;
				float AlphaClipThreshold;
			};
        
			VertexOutput VertexFunction(VertexInput v  )
			{
				VertexOutput o;
				ZERO_INITIALIZE(VertexOutput, o);

				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				
				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif
				float3 vertexValue = defaultVertexValue;
				#ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
				#else
					v.vertex.xyz += vertexValue;
				#endif
				v.ase_normal = v.ase_normal;

				float3 positionWS = TransformObjectToWorld( v.vertex.xyz );
				float3 normalWS = TransformObjectToWorldNormal(v.ase_normal);

				o.clipPos = TransformWorldToHClip(positionWS);
				o.normalWS.xyz =  normalWS;

				return o;
			}

			#if defined(TESSELLATION_ON)
			struct VertexControl
			{
				float4 vertex : INTERNALTESSPOS;
				float3 ase_normal : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( VertexInput v )
			{
				VertexControl o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				o.vertex = v.vertex;
				o.ase_normal = v.ase_normal;
				
				return o;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> v)
			{
				TessellationFactors o;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				o.edge[0] = tf.x; o.edge[1] = tf.y; o.edge[2] = tf.z; o.inside = tf.w;
				return o;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
			   return patch[id];
			}

			[domain("tri")]
			VertexOutput DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				VertexInput o = (VertexInput) 0;
				o.vertex = patch[0].vertex * bary.x + patch[1].vertex * bary.y + patch[2].vertex * bary.z;
				o.ase_normal = patch[0].ase_normal * bary.x + patch[1].ase_normal * bary.y + patch[2].ase_normal * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = o.vertex.xyz - patch[i].ase_normal * (dot(o.vertex.xyz, patch[i].ase_normal) - dot(patch[i].vertex.xyz, patch[i].ase_normal));
				float phongStrength = _TessPhongStrength;
				o.vertex.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * o.vertex.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], o);
				return VertexFunction(o);
			}
			#else
			VertexOutput vert ( VertexInput v )
			{
				return VertexFunction( v );
			}
			#endif

			half4 frag(VertexOutput IN ) : SV_TARGET
			{
				SurfaceDescription surfaceDescription = (SurfaceDescription)0;
				
				surfaceDescription.Alpha = 1;
				surfaceDescription.AlphaClipThreshold = 0.5;

				#if _ALPHATEST_ON
					clip(surfaceDescription.Alpha - surfaceDescription.AlphaClipThreshold);
				#endif

				#ifdef LOD_FADE_CROSSFADE
					LODDitheringTransition( IN.clipPos.xyz, unity_LODFade.x );
				#endif

				float3 normalWS = IN.normalWS;
				return half4(NormalizeNormalPerPixel(normalWS), 0.0);

			}
        
			ENDHLSL
        }
    }

    Fallback "Hidden/InternalErrorShader"
}