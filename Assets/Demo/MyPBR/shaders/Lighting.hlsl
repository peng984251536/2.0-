#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/Debugging3D.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/AmbientOcclusion.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
#include "Library\PackageCache\com.unity.render-pipelines.universal@12.1.12\ShaderLibrary\Shadows.hlsl"

TEXTURE2D_SHADOW(_CharShadowMap);
SAMPLER_CMP(sampler_CharShadowMap);
float4 _CharShadowMap_TexelSize;
TEXTURE2D(_CharShadowRampRT);
SAMPLER(sampler_CharShadowRampRT);
TEXTURE2D(_GradientTex);
SAMPLER(sampler_GradientTex);
float4 _GradientTex_TexelSize;
// TEXTURE2D(_CharShadowMap);
// SAMPLER(sampler_CharShadowMap);
float4 _CharShadowMap_ST;
float4x4 _LightPro_Matrix;
float4x4 _LightPro_Matrix_invers;
float3 _LightPosWS;
float4 _ShadowDebugParams;
float3 _MainLightDir;
float _ShadowRampVal;

float IsShadow(float2 shadowUV, float depth)
{
    float2 texelSize = float2(_CharShadowMap_TexelSize.xy) *_ShadowRampVal;

    float2 uv1 = shadowUV + float2(1,1)  * texelSize;
    float2 uv2 = shadowUV + float2(-1,1) * texelSize;
    float2 uv3 = shadowUV + float2(1,-1) * texelSize;
    float2 uv4 = shadowUV + float2(-1,-1)* texelSize;
    
    float depthVal1 = SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
        float3(uv1,depth));
    float depthVal2 = SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
        float3(uv2,depth));
    float depthVal3 = SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
        float3(uv3,depth));
    float depthVal4 = SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
        float3(uv4,depth));

    float com = (depthVal1+depthVal2+depthVal3+depthVal4)/4;
    return com;
}


half3 MyLightingPhysicallyBased(BRDFData brdfData, BRDFData brdfDataClearCoat,
                                half3 lightColor, half3 lightDirectionWS, half lightAttenuation,
                                half3 normalWS, half3 viewDirectionWS,
                                half clearCoatMask, bool specularHighlightsOff)
{
    //对阴影进行处理
    //float3 shadowColor = _GradientTex.SampleLevel(sampler_GradientTex,float2(lightAttenuation,0.5),0).rgb; 


    half NdotL = saturate(dot(normalWS, lightDirectionWS));
    half3 radiance = lightColor * (lightAttenuation * NdotL);

    half3 brdf = brdfData.diffuse;
    #ifndef _SPECULARHIGHLIGHTS_OFF
    [branch] if (!specularHighlightsOff)
    {
        brdf += brdfData.specular * DirectBRDFSpecular(brdfData, normalWS, lightDirectionWS, viewDirectionWS);

        #if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
        // Clear coat evaluates the specular a second timw and has some common terms with the base specular.
        // We rely on the compiler to merge these and compute them only once.
        half brdfCoat = kDielectricSpec.r * DirectBRDFSpecular(brdfDataClearCoat, normalWS, lightDirectionWS, viewDirectionWS);

        // Mix clear coat and base layer using khronos glTF recommended formula
        // https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_materials_clearcoat/README.md
        // Use NoV for direct too instead of LoH as an optimization (NoV is light invariant).
        half NoV = saturate(dot(normalWS, viewDirectionWS));
        // Use slightly simpler fresnelTerm (Pow4 vs Pow5) as a small optimization.
        // It is matching fresnel used in the GI/Env, so should produce a consistent clear coat blend (env vs. direct)
        half coatFresnel = kDielectricSpec.x + kDielectricSpec.a * Pow4(1.0 - NoV);

        brdf = brdf * (1.0 - clearCoatMask * coatFresnel) + brdfCoat * clearCoatMask;
        #endif // _CLEARCOAT
    }
    #endif // _SPECULARHIGHLIGHTS_OFF

    return brdf * radiance;
}

half3 MyLightingPhysicallyBased(BRDFData brdfData, BRDFData brdfDataClearCoat, Light light, half3 normalWS,
                                half3 viewDirectionWS, half clearCoatMask, bool specularHighlightsOff)
{
    return MyLightingPhysicallyBased(brdfData, brdfDataClearCoat, light.color, light.direction,
                                     light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS,
                                     clearCoatMask, specularHighlightsOff);
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


    //TODO
    // float f0 = _ShadowDebugParams.x;
    // float LdotN = dot(_MainLightDir,inputData.normalWS);
    // float fresnel = f0 + (1-f0) * pow(1-LdotN,5);


    //对mainLight进行调整
    //TODO
    float4 posLs = mul(_LightPro_Matrix, float4(inputData.positionWS, 1));
    float clipW = posLs.w;
    if (posLs.x <= clipW && posLs.x >= -clipW && posLs.y <= clipW && posLs.y >= -clipW && posLs.z <= clipW && posLs.z >=
        -clipW)
    {
        float3 PosNDC = (posLs.xyz / posLs.w);
        PosNDC.xy = (PosNDC.xy*0.5 + float2(-0.5,0.5));
        float2 shadowUV = (PosNDC.xy) * 0.5 + 0.5;
        //return shadowUV.x;
        shadowUV.y = 1 - shadowUV.y;
        
        float depth = ((PosNDC.z));


        //---------rampShadow--------------//
        // float depthVal = SAMPLE_TEXTURE2D(_CharShadowRampRT, sampler_CharShadowRampRT,shadowUV.xy);
        // float4 clipPos = float4(shadowUV.x,1-shadowUV.y,depthVal,1);
        // clipPos.xyz=clipPos.xyz*2-1;
        // float4 posWS = mul(_LightPro_Matrix_invers,clipPos);
        // posWS/=posWS.w;
        // //posWS.z = -posWS.z;
        // //return posWS.z;
        // //return float4(posWS.xyz,1);
        // //DepthNormal
        //float com = IsShadow(shadowUV,depth);
        //return com;
        
        float3 viewDirWS = normalize(_LightPosWS-inputData.positionWS);
        float VdotN = dot(viewDirWS,inputData.normalWS);
        float frenal = _ShadowRampVal + (1-_ShadowRampVal)*pow(1-VdotN,4.0);
        //return posWS;
        
        float fetchesWeights[9];
        float2 fetchesUV[9];
        ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
        SampleShadow_ComputeSamples_Tent_5x5(_CharShadowMap_TexelSize, shadowUV.xy, fetchesWeights, fetchesUV);

        float attenuation = 0;
        half4 shadowParams = GetMainLightShadowParams();
        attenuation = 0;
        attenuation += fetchesWeights[0] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
                                                                   float3(fetchesUV[0].xy,depth));
        attenuation += fetchesWeights[1] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
                                                                   float3(fetchesUV[1].xy,depth));
        attenuation += fetchesWeights[2] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
                                                                   float3(fetchesUV[2].xy,depth));
        attenuation += fetchesWeights[3] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
                                                                   float3(fetchesUV[3].xy,depth));
        attenuation += fetchesWeights[4] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
                                                                   float3(fetchesUV[4].xy,depth));
        attenuation += fetchesWeights[5] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
                                                                   float3(fetchesUV[5].xy,depth));
        attenuation += fetchesWeights[6] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
                                                                   float3(fetchesUV[6].xy,depth));
        attenuation += fetchesWeights[7] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
                                                                   float3(fetchesUV[7].xy,depth));
        attenuation += fetchesWeights[8] * SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,
                                                                   float3(fetchesUV[8].xy,depth));


        
        
        // float IsCharShadow = step(depth,attenuation);
        // return IsCharShadow;
        // return lerp(attenuation,1,IsCharShadow);
        //fresnel = lerp(fresnel,1,attenuation);
        mainLight.shadowAttenuation *= attenuation;
        //return fresnel;

        //Q这个depth不需要自己转换的，蛋疼
        // attenuation = SAMPLE_TEXTURE2D_SHADOW(_CharShadowMap, sampler_CharShadowMap,float3(fetchesUV[0].xy,
        //      ((PosNDC.z))-_ShadowDebugParams.x/20));
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
    }


    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    lightingData.giColor = GlobalIllumination(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
                                              inputData.bakedGI, aoFactor.indirectAmbientOcclusion,
                                              inputData.positionWS,
                                              inputData.normalWS, inputData.viewDirectionWS);

    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    {
        lightingData.mainLightColor = MyLightingPhysicallyBased(brdfData, brdfDataClearCoat,
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
