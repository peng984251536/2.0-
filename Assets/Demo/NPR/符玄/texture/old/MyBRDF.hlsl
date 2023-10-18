
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

float3 EnvironmentColor(BRDFData brdfData,float3 viewDirWS,
    float3 normalWS,float3 posWS)
{
    //---------EnvironmentBRDF----------//
    half3 reflectVector = reflect(-viewDirWS, normalWS);
    half NoV = saturate(dot(normalWS, viewDirWS));
    half fresnelTerm = Pow4(1.0 - NoV);
    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector,
        posWS, brdfData.perceptualRoughness, 1.0h);
    float3 gi = SampleSH(normalWS); //环境光;
    float3 environment = EnvironmentBRDF(brdfData,gi,indirectSpecular,fresnelTerm);

    return environment;
    
}

float3 BRDFSpecularColor(BRDFData brdfData,float3 viewDirWS,
    float3 normalWS,float3 lightDir)
{
    float BRDFSpecular = DirectBRDFSpecular(brdfData, normalWS,
                                              lightDir, viewDirWS);
    return BRDFSpecular;
}

BRDFData InitBRDFData(float3 diffuseColor,float rougness,float metallic)
{
    BRDFData brdfData = (BRDFData)0;
    float r = clamp( 0.75,0, 1);
    float m = clamp( 0.75,0, 1);
    brdfData.diffuse = diffuseColor;
    brdfData.specular = metallic;
    brdfData.perceptualRoughness = rougness;
    brdfData.roughness = max(PerceptualRoughnessToRoughness(brdfData.perceptualRoughness),
        HALF_MIN_SQRT);
    brdfData.roughness2 = max(brdfData.roughness * brdfData.roughness, HALF_MIN);
    brdfData.roughness2MinusOne = brdfData.roughness2 - half(1.0);
    brdfData.normalizationTerm = brdfData.roughness * half(4.0) + half(2.0);
    brdfData.grazingTerm = saturate(2-brdfData.roughness - metallic);

    return brdfData;
}


