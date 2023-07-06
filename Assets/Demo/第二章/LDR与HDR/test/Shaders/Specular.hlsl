// Note: Disney diffuse must be multiply by diffuseAlbedo / PI. This is done outside of this function.

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

inline float ggx_term_byTR(float NdotH, float roughness)
{
    float a2 = roughness * roughness;
    float d = (NdotH * a2 - NdotH) * NdotH + 1.0f; // 2 mad
    return INV_PI * a2 / (d * d + 1e-7f); // This function is not intended to be running on Mobile,
    // therefore epsilon is smaller than what can be represented by half
}

inline float NDFTerm(float NdotH, float roughness)
{
    float a2 = roughness * roughness;
    half n = (2.0 / a2) - 2.0; // https://dl.dropboxusercontent.com/u/55891920/papers/mm_brdf.pdf
    //n = max(n, 1e-4f);

    float NDF = (n + 2) * 0.5 / PI * pow(NdotH, n);
    return NDF;
}

inline float SmithJointGGXVisibilityTerm(float NdotL, float NdotV, float roughness)
{
    // Original formulation:
    //  lambda_v    = (-1 + sqrt(a2 * (1 - NdotL2) / NdotL2 + 1)) * 0.5f;
    //  lambda_l    = (-1 + sqrt(a2 * (1 - NdotV2) / NdotV2 + 1)) * 0.5f;
    //  G           = 1 / (1 + lambda_v + lambda_l);

    // Reorder code to be more optimal
    half a = roughness;
    half a2 = a * a;

    half lambdaV = NdotL * sqrt((-NdotV * a2 + NdotV) * NdotV + a2);
    half lambdaL = NdotV * sqrt((-NdotL * a2 + NdotL) * NdotL + a2);
    // float lambdaV = NdotL * (NdotV * (1 - a) + a);
    // float lambdaL = NdotV * (NdotL * (1 - a) + a);

    // Simplify visibility term: (2.0f * NdotL * NdotV) /  ((4.0f * NdotL * NdotV) * (lambda_v + lambda_l + 1e-5f));
    return 0.5f / (lambdaV + lambdaL + 1e-5f); // This function is not intended to be running on Mobile,
    // therefore epsilon is smaller than can be represented by half
}

inline float SmithJointOriginal(float NdotL, float NdotV, float roughness)
{
    half a2 = roughness * roughness;
    half lambda_v = (-1 + sqrt(a2 * (1 - NdotL) / NdotL + 1)) * 0.5f;
    half lambda_l = (-1 + sqrt(a2 * (1 - NdotV) / NdotV + 1)) * 0.5f;
    half G = 1 / (1 + lambda_v + lambda_l);
    return G;
}

inline float SmithJointGGXVisibilityTerm2(float NdotL, float NdotV, float roughness)
{
    // Original formulation:
    //  lambda_v    = NdotV / ( NdotV * (1-a2) + a2 );
    //  lambda_l    = NdotL / ( NdotL * (1-a2) + a2 );
    //  G           = (lambda_v + lambda_l)/( 4 * NdotV * NdotL );

    // Reorder code to be more optimal
    half a = pow(roughness + 1, 2) / 4;
    half a2 = a / 2;

    half lambdaV = 1 / (NdotV * (1 - a2) + a2);
    half lambdaL = 1 / (NdotL * (1 - a2) + a2);

    // Simplify visibility term: (NdotL * NdotV) /  ((4.0f * NdotL * NdotV) * (lambda_v * lambda_l + 1e-5f));
    return 1 / (lambdaV * lambdaL); // This function is not intended to be running on Mobile,
    // therefore epsilon is smaller than can be represented by half
}
