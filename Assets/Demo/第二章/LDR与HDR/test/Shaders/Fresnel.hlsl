inline half3 FresnelTerm(half3 F0, half cosA)
{
    half t = pow((1 - cosA), 5); // ala Schlick interpoliation
    return F0 + (1 - F0) * t;
}

inline half3 FresnelLerp(half3 F0, half3 F90, half cosA)
{
    half t = pow((1 - cosA), 5); // ala Schlick interpoliation
    return lerp(F0, F90, t);
}

// approximage Schlick with ^4 instead of ^5
inline half3 FresnelLerpFast(half3 F0, half3 F90, half cosA)
{
    half t = pow((1 - cosA), 4);
    return lerp(F0, F90, t);
}

//引入粗糙度的菲涅耳公式
float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
{
    return F0 + (max(float3(1.0 - roughness,1.0 - roughness,1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
} 
