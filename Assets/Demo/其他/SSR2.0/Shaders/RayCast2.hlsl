
#include "SSR_Library.hlsl"

TEXTURE2D_X(_CameraDepthTexture);
SAMPLER(sampler_CameraDepthTexture);
float4 _CameraDepthTexture_TexelSize;
TEXTURE2D(_GBuffer2); //法线
SAMPLER(sampler_GBuffer2);




float4 _SSR_ScreenSize;






half4 MyRayMarch(float3 reflectVector, float3 positionWS, float3 screenStart,
                 int NumSteps, float stepSize, float thickness)
{
    float3 tempWS = positionWS + reflectVector * 1;
    //TransformWorldToHClip()
    float4 temp_scrPos = mul(_VPMatrix, float4(tempWS, 1));
    float3 temp_screen = temp_scrPos.xyz / temp_scrPos.w;
    temp_screen.xyz = temp_screen.xyz * 0.5 + 0.5;
    temp_screen.z = 1 - temp_screen.z;
    //return temp_screen.z;
    //return length(positionWS-tempWS);

    //屏幕空间的方向
    float3 scrStepDir = normalize(temp_screen - screenStart);
    //scrStepDir.xy =float2(scrStepDir.x *_CameraDepthTexture_TexelSize.x,scrStepDir.y *_CameraDepthTexture_TexelSize.y);
    //scrStepDir.xy*=0.5;
    //return float4(tempWS,1);

    float3 curScreen = screenStart;
    float mask = 0.0;
    //return float4(scrStepDir,1);

    // float scale = RayStepScale;
    // curScreen += scrStepDir * scale*RayStepNum;
    // float recordDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture,
    //                                    sampler_CameraDepthTexture, curScreen.xy).r;
    // float delta = recordDepth - curScreen.z;
    // return recordDepth - curScreen.z>thickness;

    UNITY_UNROLL
    for (int i = 0; i < 100 && i < NumSteps; i++)
    {
        //----------new----------//
        // float distnace = Clamp(curScreen.xy, curScreen.xy + scrStepDir.xy,
        //                        _CameraDepthTexture_TexelSize.xy);
        curScreen = curScreen + scrStepDir * stepSize;
        float recordDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture,
                                               sampler_CameraDepthTexture, curScreen.xy).r;
        if(recordDepth < 0.0001)
            continue;
        //(-LinearEyeDepth(sampleMinDepth)) - (-LinearEyeDepth(samplePos.z));
        float delta = - LinearEyeDepth(recordDepth, _ZBufferParams) +
            LinearEyeDepth(curScreen.z, _ZBufferParams);

        if (curScreen.x < 0 || curScreen.x > 1 ||
            curScreen.y < 0 || curScreen.y > 1 ||
            curScreen.z < 0 || curScreen.z > 1)
        {
            mask = 0.0;
            break;
        }
        // if (recordDepth == 0)
        // {
        //     mask = 0.0;
        //     break;
        // }
        //大于0时说明光线撞到物体了
        if (delta > 0)
        {
            //return delta-thickness;
            if (delta <=  thickness||delta >=  -thickness)
            {
                continue;
            }

            mask = 1.0;
            break;
        }
    }
    return float4(curScreen.xyz, mask);
}


void rayCast(PixelInput i, out half4 outRayCast : SV_Target0, out half4 outRayCastMask : SV_Target1)
{
    float2 uv = i.uv;
    //outRayCast = float4(uv,0,1);

    float4 NormalMap = SAMPLE_TEXTURE2D(_GBuffer2, sampler_GBuffer2, uv);
    float3 normalVS = mul((float3x3)_VMatrix,NormalMap.xyz);
    float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
    float2 uv_jitter = (uv + _JitterSizeAndOffset.zw) *
        _ScreenSize.xy / _downsampleDivider * _NoiseTex_TexelSize.xy;
    float2 jitter = _NoiseTex.SampleLevel( sampler_NoiseTex, uv_jitter,0).rg;
    //jitter *= _JitterSizeAndOffset.xy;
    float roughness = clamp(1 - NormalMap.a,0.05,0.95) ;
    float2 Xi = jitter;

    Xi.y*=0.5+0.5;
    Xi.y = lerp(Xi.y, 0.0, _BRDFBias);


    float3 worldPos = GetWorldPos(uv, depth);
    float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - worldPos.xyz);
    float3 screenPos = float3(uv, depth);


    float skybox = (depth > 0.0001);
    if(skybox==0)
    {
        outRayCast = float4(uv,depth,1);
        outRayCastMask = 0;
        return;
    }
    

    //之所以用这个法线，是利用粗糙度模拟微表面法线
    //1、 Importance Sampling
    //https://blog.csdn.net/qq_42999564/article/details/127631258
    //#if defined(_IMPORTANCE_SAMPLING)
    //float3 normalVS = normalize(mul(_VMatrix,NormalMap.xyz));
    float4 H = TangentToWorld(float3(NormalMap.xyz),MyImportanceSampleGGX(Xi, roughness));
    //H.xyz = normalize(H.xyz);
    //H.xyz = normalize(mul(_VMatrix_invers,H.xyz));
    //#else
    //float4 H = float4(NormalMap.xyz, 1);
    //#endif
    // outRayCast = float4(H.xyz, H.w);
    // return;


    float3 refDirWS = normalize(reflect(viewDir, H.xyz));
    //dir = normalize(mul((float3x3)_WorldToCameraMatrix, dir));
    //return refDirWS.z;
    //return float4(worldNormal.xyz,1);

    //-------光线步进相关参数
    float numSteps = RayStepNum;
    jitter =jitter+0.5f;
    float stepSize = (1.0 / numSteps) * RayStepScale;
    stepSize = stepSize * (jitter.x + jitter.y) + stepSize;
    float thickness = _thickness;
    float4 rayTrace =
        MyRayMarch(refDirWS, worldPos, screenPos,
                   numSteps, stepSize, thickness);

    outRayCast = float4(rayTrace.xyz, H.w);
    outRayCastMask = rayTrace.w;
    //return rayTrace.w;
    //return float4(rayTrace.xy,0,1);
    //return float4(rayTrace.xyz*rayTrace.w,rayTrace.w);
    //return H.w;
    //return rayTrace.w;
}

