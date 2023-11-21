#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
float4x4 _VMatrix_invers;
float4x4 _VMatrix;
float4x4 _VPMatrix_invers;
float4x4 _VPMatrix;





struct VertOutput
{
    uint vertexID :SV_VertexID;
};


struct PixelInput
{
    float4 pos:SV_Position;
    float2 uv:TEXCOORD0;
};


float4 TangentToWorld(float3 N, float4 H)
{
    float3 UpVector = abs(N.z) < 0.999 ? float3(0.0, 0.0, 1.0) : float3(1.0, 0.0, 0.0);
    float3 T = normalize(cross(UpVector, N));
    float3 B = cross(N, T);

    return float4((T * H.x) + (B * H.y) + (N * H.z), H.w);
}


float4 MyImportanceSampleGGX(float2 Xi, float Roughness)
{
    float m = Roughness * Roughness;
    //float m2 = m * m;
		
    float Phi = 2 * PI * Xi.x;
				 
    float CosTheta = sqrt((1.0 - Xi.y) / (1.0 + (m - 1.0) * Xi.y));
    float SinTheta = sqrt(max(1e-5, 1.0 - CosTheta * CosTheta));
				 
    float3 H;
    H.x = SinTheta * cos(Phi);
    H.y = SinTheta * sin(Phi);
    H.z = CosTheta;
		
    float d = (CosTheta * m - CosTheta) * CosTheta + 1;
    float D = m / (PI * d * d);
    float pdf = D * CosTheta;

    return float4(H, pdf);
}



float3 GetWorldSpacePos(float2 uv, float depth)
{
    float4 ndc = float4(uv * 2 - 1, (1 - depth) * 2 - 1, 1);
    float4 posWS = mul(_VPMatrix_invers, ndc);
    posWS /= posWS.w;
    return posWS.xyz;
}