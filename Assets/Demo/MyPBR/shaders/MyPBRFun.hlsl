
#define _NORMAL_DROPOFF_TS 1
#pragma multi_compile_instancing
#pragma multi_compile _ LOD_FADE_CROSSFADE
#pragma multi_compile_fog
#define ASE_FOG 1
#define ASE_SRP_VERSION 999999


#pragma multi_compile _ _SCREEN_SPACE_OCCLUSION
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS _ADDITIONAL_OFF
#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
#pragma multi_compile _ _SHADOWS_SOFT
#pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
#pragma multi_compile _ SHADOWS_SHADOWMASK

#pragma multi_compile _ DIRLIGHTMAP_COMBINED
#pragma multi_compile _ LIGHTMAP_ON
#pragma multi_compile _ DYNAMICLIGHTMAP_ON

#pragma multi_compile _ _REFLECTION_PROBE_BLENDING
#pragma multi_compile _ _REFLECTION_PROBE_BOX_PROJECTION
#pragma multi_compile _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
#pragma multi_compile _ _LIGHT_LAYERS

#pragma multi_compile _ _LIGHT_COOKIES
#pragma multi_compile _ _CLUSTERED_RENDERING

#define SHADERPASS SHADERPASS_FORWARD

#include "Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

#if defined(UNITY_INSTANCING_ENABLED) && defined(_TERRAIN_INSTANCED_PERPIXEL_NORMAL)
	#define ENABLE_TERRAIN_PERPIXEL_NORMAL
#endif



float3 GetPBRColor(float3 baseColor,float metallic,float smoothness,
	float2 ScreenSpaceUV,float3 posWS,float3 viewDirWS,float3 normalWS,
	float4 posCS)
{
	
	float4 ShadowCoords = float4( 0, 0, 0, 0 );
	#if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
	#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
	ShadowCoords = IN.shadowCoord;
	#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
	ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
	#endif
	#endif

	
    float3 Albedo = baseColor.rgb;
    float3 Normal = float3(0, 0, 1);
    float3 Emission = 0;
    float3 Specular = 0.5;
    float Metallic = metallic;
    float Smoothness = smoothness;
    float Occlusion = 1;
    float Alpha = 1;
    float AlphaClipThreshold = 0.5;
    float AlphaClipThresholdShadow = 0.5;
    float3 BakedGI = 0;
    float3 RefractionColor = 1;
    float RefractionIndex = 1;
    float3 Transmission = 1;
    float3 Translucency = 1;
	

	
	//clip(Alpha - AlphaClipThreshold);

    InputData inputData = (InputData)0;
    inputData.positionWS = posWS;
    inputData.viewDirectionWS = viewDirWS;
	inputData.positionCS = float4(posCS);
	
    inputData.normalWS = normalize(normalWS.xyz);
	inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);




    //球协环境光（环境光漫反射）
	float3 SH = SampleSH(inputData.normalWS.xyz);
    inputData.bakedGI = SAMPLE_GI(IN.lightmapUVOrVertexSH.xy, SH, inputData.normalWS);
    inputData.normalizedScreenSpaceUV = ScreenSpaceUV;
    inputData.shadowMask = SAMPLE_SHADOWMASK(IN.lightmapUVOrVertexSH.xy);

    #if defined(DEBUG_DISPLAY)
    #if defined(DYNAMICLIGHTMAP_ON)
						inputData.dynamicLightmapUV = IN.dynamicLightmapUV.xy;
    #endif

    #if defined(LIGHTMAP_ON)
						inputData.staticLightmapUV = IN.lightmapUVOrVertexSH.xy;
    #else
						inputData.vertexSH = SH;
    #endif
    #endif

    SurfaceData surfaceData;
    surfaceData.albedo = Albedo;
    surfaceData.metallic = saturate(Metallic);
    surfaceData.specular = Specular;
    surfaceData.smoothness = saturate(Smoothness),
        surfaceData.occlusion = Occlusion,
        surfaceData.emission = Emission,
        surfaceData.alpha = saturate(Alpha);
    surfaceData.normalTS = Normal;
    surfaceData.clearCoatMask = 0;
    surfaceData.clearCoatSmoothness = 1;
	
	

    half4 color = MyUniversalFragmentPBR(inputData, surfaceData);

    #ifdef _TRANSMISSION_ASE
				{
				float shadow = _TransmissionShadow;
				//shadow = 1;

				Light mainLight = GetMainLight( inputData.shadowCoord );
				float3 mainAtten = mainLight.color * mainLight.distanceAttenuation;
				mainAtten = lerp( mainAtten, mainAtten * mainLight.shadowAttenuation, shadow );
				half3 mainTransmission = max(0 , -dot(inputData.normalWS, mainLight.direction)) * mainAtten * Transmission;
				//color.rgb += Albedo * mainTransmission;
				color.rgb += Albedo ;

    #ifdef _ADDITIONAL_LIGHTS
						int transPixelLightCount = GetAdditionalLightsCount();
						for (int i = 0; i < transPixelLightCount; ++i)
						{
							Light light = GetAdditionalLight(i, inputData.positionWS);
							float3 atten = light.color * light.distanceAttenuation;
							atten = lerp( atten, atten * light.shadowAttenuation, shadow );

							half3 transmission = max(0 , -dot(inputData.normalWS, light.direction)) * atten * Transmission;
							//color.rgb += Albedo * transmission;
							color.rgb += Albedo ;
						}
    #endif
				}
    #endif

    #ifdef _TRANSLUCENCY_ASE
				{
					float shadow = _TransShadow;
					float normal = _TransNormal;
					float scattering = _TransScattering;
					float direct = _TransDirect;
					float ambient = _TransAmbient;
					float strength = _TransStrength;

					Light mainLight = GetMainLight( inputData.shadowCoord );
					float3 mainAtten = mainLight.color * mainLight.distanceAttenuation;
					mainAtten = lerp( mainAtten, mainAtten * mainLight.shadowAttenuation, shadow );

					half3 mainLightDir = mainLight.direction + inputData.normalWS * normal;
					half mainVdotL = pow( saturate( dot( inputData.viewDirectionWS, -mainLightDir ) ), scattering );
					half3 mainTranslucency = mainAtten * ( mainVdotL * direct + inputData.bakedGI * ambient ) * Translucency;
					//color.rgb += Albedo * mainTranslucency * strength;
					color.rgb += Albedo;

    #ifdef _ADDITIONAL_LIGHTS
						int transPixelLightCount = GetAdditionalLightsCount();
						for (int i = 0; i < transPixelLightCount; ++i)
						{
							Light light = GetAdditionalLight(i, inputData.positionWS);
							float3 atten = light.color * light.distanceAttenuation;
							atten = lerp( atten, atten * light.shadowAttenuation, shadow );

							half3 lightDir = light.direction + inputData.normalWS * normal;
							half VdotL = pow( saturate( dot( inputData.viewDirectionWS, -lightDir ) ), scattering );
							half3 translucency = atten * ( VdotL * direct + inputData.bakedGI * ambient ) * Translucency;
							color.rgb += Albedo * translucency * strength;
						}
    #endif
				}
    #endif

    #ifdef _REFRACTION_ASE
					float4 projScreenPos = ScreenPos / ScreenPos.w;
					float3 refractionOffset = ( RefractionIndex - 1.0 ) * mul( UNITY_MATRIX_V, float4( WorldNormal,0 ) ).xyz * ( 1.0 - dot( WorldNormal, WorldViewDirection ) );
					projScreenPos.xy += refractionOffset.xy;
					float3 refraction = SHADERGRAPH_SAMPLE_SCENE_COLOR( projScreenPos.xy ) * RefractionColor;
					color.rgb = lerp( refraction, color.rgb, color.a );
					color.a = 1;
    #endif

    #ifdef ASE_FINAL_COLOR_ALPHA_MULTIPLY
					color.rgb *= color.a;
    #endif

   

    return color;
}
