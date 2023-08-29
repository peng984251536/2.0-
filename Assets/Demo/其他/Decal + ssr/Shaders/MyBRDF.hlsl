#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


TEXTURE2D(_LUTTex);
SAMPLER(sampler_LUTTex);

half3 MyBRDF_Direct(half3 diffColor, half3 specColor, half rlPow4, half smoothness)
{
    half LUT_RANGE = 16.0; // must match range in NHxRoughness() function in GeneratedTextures.cpp
    // Lookup texture to save instructions
    half specular = _LUTTex.Sample(sampler_LUTTex,half2(rlPow4, 1-smoothness)).r * LUT_RANGE;


    return diffColor + specular * specColor;
}

half3 MyBRDF_Indirect(half3 diffColor, half3 specColor, BRDFData indirect, half grazingTerm, half fresnelTerm)
{
    half3 c = indirect.diffuse * diffColor;
    c += indirect.specular * lerp (specColor, grazingTerm, fresnelTerm);
    return c;
}

half3 BRDF_Unity_PBS(half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness,
    float3 normal, float3 viewDir,
    Light light, BRDFData gi)
{
    float3 reflDir = reflect (viewDir, normal);

    half nl = saturate(dot(normal, light.direction));
    half nv = saturate(dot(normal, viewDir));

    // Vectorize Pow4 to save instructions
    half2 rlPow4AndFresnelTerm = Pow4 (float2(dot(reflDir, light.direction), 1-nv));  // use R.L instead of N.H to save couple of instructions
    half rlPow4 = rlPow4AndFresnelTerm.x; // power exponent must match kHorizontalWarpExp in NHxRoughness() function in GeneratedTextures.cpp
    half fresnelTerm = rlPow4AndFresnelTerm.y;

    half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));

    half3 color = MyBRDF_Direct(diffColor, specColor, rlPow4, smoothness);
    color *= light.color * nl;
    color += MyBRDF_Indirect(diffColor, specColor, gi, grazingTerm, fresnelTerm);
    //return MyBRDF_Indirect(diffColor, specColor, gi, grazingTerm, fresnelTerm);

    return color;
}
