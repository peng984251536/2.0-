#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/Debugging3D.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/AmbientOcclusion.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"
#include "Library\PackageCache\com.unity.render-pipelines.universal@12.1.12\ShaderLibrary\Shadows.hlsl"

//TEXTURE2D_SHADOW(_CharShadowMap);
//SAMPLER_CMP(sampler_CharShadowMap);
// TEXTURE2D(_CharShadowMap);
// SAMPLER(sampler_CharShadowMap);
float4 _CharShadowMap_ST;
float4x4 _LightPro_Matrix;
float4x4 _LightPro_Matrix_invers;
float4 _ShadowDebugParams;

float IsShadow(float depth, float charDepth)
{
    if (charDepth <= 0.0001)
        charDepth = 1;
    return charDepth - depth;
}

///////////////////////////////////////////////////////////////////////////////
//                      Fragment Functions                                   //
//       Used by ShaderGraph and others builtin renderers                    //
///////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
/// PBR lighting...
////////////////////////////////////////////////////////////////////////////////
half4 MyUniversalFragmentPBR(InputData inputData, SurfaceData surfaceData)
{
    #if defined(_SPECULARHIGHLIGHTS_OFF)
    bool specularHighlightsOff = true;
    #else
    bool specularHighlightsOff = false;
    #endif
    BRDFData brdfData;

    // NOTE: can modify "surfaceData"...
    InitializeBRDFData(surfaceData, brdfData);

    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
    {
        return debugColor;
    }
    #endif

    // Clear-coat calculation...
    BRDFData brdfDataClearCoat = CreateClearCoatBRDFData(surfaceData, brdfData);
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLightLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
    return mainLight.shadowAttenuation;


    //TODO
    // ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
    // float attenuation1 = SampleShadowmapFiltered(
    //     TEXTURE2D_SHADOW_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture),
    //     inputData.shadowCoord, shadowSamplingData);
    // attenuation1 = SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture,
    //                                        float3(inputData.shadowCoord.xy,_ShadowDebugParams.y/10));
    //return attenuation1;

    //对mainLight进行调整
    //TODO
    float4 posLs = mul(_LightPro_Matrix, float4(inputData.positionWS, 1));
    float3 PosNDC = (posLs.xyz / posLs.w);
    float2 shadowUV = (PosNDC.xy) * 0.5 + 0.5;
    //return shadowUV.x;
    shadowUV.y = 1 - shadowUV.y;
    float depth = 1 - ((PosNDC.z) * 0.5 + 0.5);
    //return depth;
    // float charDepth = _CharShadowMap.Sample(sampler_CharShadowMap,shadowUV);
    // if(charDepth<=0.0001)
    //     charDepth = 1;
    //float IsCharShadow = step(depth,charDepth);
    //float charShadowAttenuation = step(depth,charDepth); 
    //mainLight.shadowAttenuation *= step(charDepth,depth);
    //mainLight.shadowAttenuation *= charShadowAttenuation;
    //return step(depth,charDepth);
    //return  step(charDepth,depth);
    // float fetchesWeights[9];
    // float2 fetchesUV[9];
    // ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
    // SampleShadow_ComputeSamples_Tent_5x5(shadowSamplingData.shadowmapSize, shadowUV.xy, fetchesWeights, fetchesUV);

    float attenuation = 0;
    // attenuation = fetchesWeights[0] * IsShadow(depth,_CharShadowMap.Sample(sampler_CharShadowMap,fetchesUV[0]).r);
    // attenuation += fetchesWeights[1] * IsShadow(depth,_CharShadowMap.Sample(sampler_CharShadowMap,fetchesUV[1]).r);
    // attenuation += fetchesWeights[2] * IsShadow(depth,_CharShadowMap.Sample(sampler_CharShadowMap,fetchesUV[2]).r);
    // attenuation += fetchesWeights[3] * IsShadow(depth,_CharShadowMap.Sample(sampler_CharShadowMap,fetchesUV[3]).r);
    // attenuation += fetchesWeights[4] * IsShadow(depth,_CharShadowMap.Sample(sampler_CharShadowMap,fetchesUV[4]).r);
    // attenuation += fetchesWeights[5] * IsShadow(depth,_CharShadowMap.Sample(sampler_CharShadowMap,fetchesUV[5]).r);
    // attenuation += fetchesWeights[6] * IsShadow(depth,_CharShadowMap.Sample(sampler_CharShadowMap,fetchesUV[6]).r);
    // attenuation += fetchesWeights[7] * IsShadow(depth,_CharShadowMap.Sample(sampler_CharShadowMap,fetchesUV[7]).r);
    // attenuation += fetchesWeights[8] * IsShadow(depth,_CharShadowMap.Sample(sampler_CharShadowMap,fetchesUV[8]).r);

    // attenuation = SampleShadowmapFiltered(_CharShadowMap,sampler_CharShadowMap,
    //     float4(shadowUV.xy,0,0), shadowSamplingData);
    // half4 shadowParams = GetMainLightShadowParams();
    // float3 coor = float3(fetchesUV[0].xy, depth);
    // attenuation = 0;
    // attenuation += fetchesWeights[0] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
    //                                                            float3(fetchesUV[0].xy,depth));
    // attenuation += fetchesWeights[1] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
    //                                                            float3(fetchesUV[1].xy,depth));
    // attenuation += fetchesWeights[2] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
    //                                                            float3(fetchesUV[2].xy,depth));
    // attenuation += fetchesWeights[3] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
    //                                                            float3(fetchesUV[3].xy,depth));
    // attenuation += fetchesWeights[4] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
    //                                                            float3(fetchesUV[4].xy,depth));
    // attenuation += fetchesWeights[5] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
    //                                                            float3(fetchesUV[5].xy,depth));
    // attenuation += fetchesWeights[6] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
    //                                                            float3(fetchesUV[6].xy,depth));
    // attenuation += fetchesWeights[7] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
    //                                                            float3(fetchesUV[7].xy,depth));
    // attenuation += fetchesWeights[8] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
    //                                                            float3(fetchesUV[8].xy,depth));
    // //float IsCharShadow = step(depth,attenuation);
    // //return lerp(attenuation,1,IsCharShadow);
    // mainLight.shadowAttenuation*=attenuation;

    //attenuation = SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,float3(fetchesUV[0].xy,depth));
    //float3 c1 = lerp(float3(0, 0, 0), float3(0.8, 0.3, 0.2), smoothstep(_ShadowDebugParams.x,_ShadowDebugParams.y, attenuation));
    //float3 c2 = lerp(c1,1,smoothstep(_ShadowDebugParams.z,_ShadowDebugParams.w, attenuation));
    //return float4(c2,1) ;
    //return attenuation;

    // if (attenuation == 0)
    //     attenuation = 1;

    //attenuation = LerpWhiteTo(attenuation, shadowParams.x);
    //return  BEYOND_SHADOW_FAR(coor) ? 1.0 : attenuation;


    // float atten = lerp(
    //     mainLight.shadowAttenuation*charShadowAttenuation*attenuation,
    //     mainLight.shadowAttenuation,
    //     charShadowAttenuation);
    // if(attenuation<=0.0001)
    //     attenuation = 1;
    //attenuation=attenuation>0.001?1:0;
    //attenuation = lerp(attenuation,1,IsCharShadow);
    //mainLight.shadowAttenuation *= attenuation;


    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    lightingData.giColor = GlobalIllumination(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
                                              inputData.bakedGI, aoFactor.indirectAmbientOcclusion,
                                              inputData.positionWS,
                                              inputData.normalWS, inputData.viewDirectionWS);

    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    {
        lightingData.mainLightColor = LightingPhysicallyBased(brdfData, brdfDataClearCoat,
                                                              mainLight,
                                                              inputData.normalWS, inputData.viewDirectionWS,
                                                              surfaceData.clearCoatMask, specularHighlightsOff);
    }

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_CLUSTERED_LIGHTING
    for (uint lightIndex = 0; lightIndex < min(_AdditionalLightsDirectionalCount, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfDataClearCoat, light,
                                                                          inputData.normalWS, inputData.viewDirectionWS,
                                                                          surfaceData.clearCoatMask, specularHighlightsOff);
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfDataClearCoat, light,
                                                                          inputData.normalWS, inputData.viewDirectionWS,
                                                                          surfaceData.clearCoatMask, specularHighlightsOff);
        }
    LIGHT_LOOP_END
    #endif

    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif

    return CalculateFinalColor(lightingData, surfaceData.alpha);
}
