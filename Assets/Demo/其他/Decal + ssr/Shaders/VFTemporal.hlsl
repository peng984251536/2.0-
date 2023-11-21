#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


TEXTURE2D(_blueNoiseTex);
SAMPLER(sampler_blueNoiseTex);
TEXTURE2D(_MotionVectorTexture);
SAMPLER(sampler_MotionVectorTexture);
TEXTURE2D(_PreTexture);
SAMPLER(sampler_PreTexture);
TEXTURE2D(_CurTexture);
SAMPLER(sampler_CurTexture);
// float4x4 _PrevViewProjectionMatrix;
// float4x4 _ViewProjectionMatrix;

float _TScale;
float _TResponse;
// float2 _haltonVector2;
// float _haltonScale;


float4 GetSampleColor(float2 uv)
{
    float4 current = _CurTexture.Sample(sampler_CurTexture,uv);
    return current;
}


float4 temporal(float2 uv)
{
    // float2 Halton = float2(_haltonVector2.x/_ScreenParams.x,_haltonVector2.y/_ScreenParams.y);
    // uv -= Halton*_haltonScale;
    //return float4(uv,0,1);
    
    float2 velocity = _MotionVectorTexture.Sample(sampler_MotionVectorTexture,uv);
    float2 prevUV = uv - velocity;

    float4 current = _CurTexture.Sample(sampler_CurTexture,uv);
    float4 previous = _PreTexture.Sample(sampler_PreTexture,prevUV);
    //return current;

    float2 du = float2(1.0 / _ScreenParams.x, 0.0);
    float2 dv = float2(0.0, 1.0 / _ScreenParams.y);

    //对周围9个格子进行采样,组成AABB包围盒
    float4 currentTopLeft = GetSampleColor(uv.xy - dv - du);
    float4 currentTopCenter = GetSampleColor(uv.xy - dv);
    float4 currentTopRight = GetSampleColor(uv.xy - dv + du);
    float4 currentMiddleLeft = GetSampleColor( uv.xy - du);
    float4 currentMiddleCenter = GetSampleColor( uv.xy);
    float4 currentMiddleRight = GetSampleColor(uv.xy + du);
    float4 currentBottomLeft = GetSampleColor(uv.xy + dv - du);
    float4 currentBottomCenter = GetSampleColor( uv.xy + dv);
    float4 currentBottomRight = GetSampleColor( uv.xy + dv + du);
    float4 currentMin = min(currentTopLeft, min(currentTopCenter,
                                                min(currentTopRight,
                                                    min(currentMiddleLeft,
                                                        min(currentMiddleCenter,
                                                            min(currentMiddleRight,
                                                                min(currentBottomLeft,
                                                                    min(currentBottomCenter, currentBottomRight))))))));
    float4 currentMax = max(currentTopLeft, max(currentTopCenter,
                                                max(currentTopRight,
                                                    max(currentMiddleLeft,
                                                        max(currentMiddleCenter,
                                                            max(currentMiddleRight,
                                                                max(currentBottomLeft,
                                                                    max(currentBottomCenter, currentBottomRight))))))));

    float scale = _TScale;

    float4 center = (currentMin + currentMax) * 0.5f;
    currentMin = (currentMin - center) * scale + center;
    currentMax = (currentMax - center) * scale + center;

    previous = clamp(previous, currentMin, currentMax);

    /*float currentLum = Luminance(current.rgb);
    float previousLum = Luminance(previous.rgb);
    float unbiasedDiff = abs(currentLum - previousLum) / max(currentLum, max(previousLum, 0.2f));
    float unbiasedWeight = 1.0 - unbiasedDiff;
    float unbiasedWeightSqr = sqr(unbiasedWeight);

    float response = lerp(_TMinResponse, _TMaxResponse, unbiasedWeightSqr);*/

    float4 reflection = lerp(current, previous, saturate(_TResponse * (1 - length(velocity) * 8)));
    reflection = lerp(current, previous, _TResponse);
    return reflection;
}


