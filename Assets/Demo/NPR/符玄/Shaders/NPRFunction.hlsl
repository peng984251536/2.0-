#pragma multi_compile_local _ _RAMP_COORHAIR _RAMP_WARMHAIR _RAMP_COORBODY _RAMP_WARMBODY
#pragma multi_compile_local _ _HAIR
#pragma multi_compile_local _ _SoomthNormal
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#define SKYBOX_RAMP_COORHAIR 0
#define SKYBOX_RAMP_WARMHAIR 1
#define SKYBOX_RAMP_COORBODY 2
#define SKYBOX_RAMP_WARMBODY 3

#ifndef SKYBOX_RAMP
#if defined(_RAMP_COORHAIR)
    #define SKYBOX_RAMP SKYBOX_RAMP_COORHAIR
#elif defined(_RAMP_WARMHAIR)
    #define SKYBOX_RAMP SKYBOX_RAMP_WARMHAIR
#elif defined(_RAMP_COORBODY)
    #define SKYBOX_RAMP SKYBOX_RAMP_COORBODY
#elif defined(_RAMP_WARMBODY)
    #define SKYBOX_RAMP SKYBOX_RAMP_WARMBODY
#else
#define SKYBOX_RAMP SKYBOX_RAMP_WarmBody
#endif
#endif

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);
float4 _MainTex_ST;
TEXTURE2D(_LightingMap);
SAMPLER(sampler_LightingMap);
float4 _LightingMap_ST;
TEXTURE2D(_IBLMap);
SAMPLER(sampler_IBLMap);
TEXTURE2D(_RampMap01);
SAMPLER(sampler_RampMap01);
TEXTURE2D(_RampMap02);
SAMPLER(sampler_RampMap02);
TEXTURE2D(_RampMap03);
SAMPLER(sampler_RampMap03);
TEXTURE2D(_MatCap);
SAMPLER(sampler_MatCap);

float _EdgeViewScale;
float4 _EdgeOutLineOffset;

struct appdata
{
    float4 vertex: POSITION;
    float3 normal:NORMAL;
    float3 tangent : TANGENT;
    float3 color : COLOR;
    //float3 tangentu:TANGENT;
    float2 uv :TEXCOORD0;
    // float2 uv1 :TEXCOORD1;
    // float2 uv2 :TEXCOORD2;
    // float2 uv3 :TEXCOORD3;
    // float2 uv4 :TEXCOORD4;
    // float2 uv5 :TEXCOORD5;
    float2 uv6 :TEXCOORD6;
    float2 uv7 :TEXCOORD7;
    float3 faceDorWS :TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
    float4 vertex: SV_POSITION;
    float2 uv:TEXCOORD0;
    float3 normalWS:TEXCOORD1;
    float3 posWS:TEXCOORD2;
    float4 MatCapUV:TEXCOORD3;
    float3 faceDorWS :TEXCOORD4;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

float3 NPR_body(v2f i, Light light, float f0, float specularWith, float specularIns,
                float sepcularMatellicIns, float4 debugParams = 0, float debugLog = 0)
{
    float4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
    float4 iBLMap = SAMPLE_TEXTURE2D(_IBLMap, sampler_IBLMap, i.uv);

    i.normalWS = normalize(i.normalWS);
    float3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
    float3 lightDir = normalize(light.direction.xyz);
    float3 halfDir = normalize(viewDirWS + lightDir);
    float NdotL = saturate(dot(i.normalWS, lightDir));
    float halfNdotL = NdotL * 0.5 + 0.5;
    float HdotN = saturate(dot(i.normalWS, halfDir));
    float VdotN = saturate(dot(viewDirWS, i.normalWS));
    //NdotL = smoothstep(0.5,0.6,NdotL);
    //return NdotL;


    //--------基础色----------//
    float shadow = smoothstep(0, 0.08, NdotL) * light.shadowAttenuation; //考虑到被物体遮挡
    shadow = max(shadow, 0.15);
    float2 uv = float2(shadow, iBLMap.a);
    //uv = float2(shadow,_DebugParams.w/10);
    float3 rampColor;
    #if SKYBOX_RAMP == SKYBOX_RAMP_COORHAIR
    uv = float2(shadow, 0.75);
    rampColor = SAMPLE_TEXTURE2D(_RampMap01, sampler_RampMap01, uv);
    #elif SKYBOX_RAMP == SKYBOX_RAMP_WARMHAIR
                    uv = float2(shadow, 0.25);
                    rampColor = SAMPLE_TEXTURE2D(_RampMap01, sampler_RampMap01, uv);
    #elif SKYBOX_RAMP == SKYBOX_RAMP_COORBODY
                    rampColor = SAMPLE_TEXTURE2D(_RampMap02, sampler_RampMap02, uv);
    #elif SKYBOX_RAMP == SKYBOX_RAMP_WARMBODY
                    rampColor = SAMPLE_TEXTURE2D(_RampMap03, sampler_RampMap03, uv);
    #endif
    float3 diffuseColor = baseMap.rgb * rampColor * light.color;
    float isAO = step(-0.1, iBLMap.r) - step(0.1, iBLMap.r);
    float isDiffuse = step(0.1, iBLMap.r) - step(1.1, iBLMap.r);
    diffuseColor = isAO * diffuseColor * diffuseColor + isDiffuse * diffuseColor;
    //return float4(diffuseColor,1);

    //---------高光----------//
    float MatCap = SAMPLE_TEXTURE2D(_MatCap, sampler_MatCap,
                                    i.MatCapUV.xy).r;
    float sepcular;
    float sepcularMetallic;
    float2 _MatCapUV;
    #if defined(_HAIR)
                sepcular=0;
                sepcularMetallic = iBLMap.b;
                _MatCapUV = i.MatCapUV.xy;
    #else
    sepcular = iBLMap.g;
    sepcularMetallic = iBLMap.b;
    _MatCapUV = i.MatCapUV.zw;
    #endif


    //非金属的高光我可以尝试用BRDF代替
    float3 specularRamp;
    #if SKYBOX_RAMP == SKYBOX_RAMP_COORHAIR
    specularRamp = SAMPLE_TEXTURE2D(_RampMap01, sampler_RampMap01, float2(0.15, iBLMap.a));
    specularRamp *= shadow;
    #elif SKYBOX_RAMP == SKYBOX_RAMP_WARMHAIR
                    specularRamp = SAMPLE_TEXTURE2D(_RampMap01, sampler_RampMap01, float2(0.15,iBLMap.a));
                    specularRamp*=shadow;
    #elif SKYBOX_RAMP == SKYBOX_RAMP_COORBODY
                    specularRamp = SAMPLE_TEXTURE2D(_RampMap02, sampler_RampMap02, float2(0.15,iBLMap.a));
    #elif SKYBOX_RAMP == SKYBOX_RAMP_WARMBODY
                    specularRamp = SAMPLE_TEXTURE2D(_RampMap03, sampler_RampMap03, float2(0.15,iBLMap.a));
    #endif


    //-----菲涅尔----//
    float F0 = f0;
    float frenel = F0 + (1 - F0) * pow(1 - VdotN, specularWith);
    frenel = saturate(frenel);
    float3 frenelColor = specularRamp * frenel * sepcular;
    frenelColor = baseMap.rgb * frenelColor * frenelColor * specularIns;
    //return frenel;


    //---------金属效果----------//
    float MatCap2 = SAMPLE_TEXTURE2D(_MatCap, sampler_MatCap, _MatCapUV).r;
    //specularRamp = SAMPLE_TEXTURE2D(_RampMap03, sampler_RampMap03, float2(0.2,_DebugParams.w));
    half specularMatel = MatCap * pow(sepcularMetallic, 2) * shadow;
    //specularMatel = pow(HdotN, _SpecularWith);
    //specularMatel = step(_DebugParams.w,specularMatel) ;
    float3 specularMatelColor = baseMap.rgb * MatCap2 * sepcularMatellicIns * specularRamp * sepcularMetallic;
    //return MatCap;
    //return float4(specularRamp,1);


    //------最终颜色混合------//
    float3 finalColor = 0;
    if (debugLog == 0)
    {
        //diffuseColor = diffuseColor;
        //finalColor = specularMatelColor;
        //finalColor = diffuseColor;
        finalColor = diffuseColor + frenelColor + specularMatelColor;
        //finalColor = specularMatelColor;
        //finalColor += diffuseColor+specularColor;
        //finalColor = diffuseColor + specularMatelColor;
        //finalColor = 0;
    }
    else if (debugLog == 1)
    {
        finalColor = iBLMap.r;
    }
    else if (debugLog == 2)
    {
        finalColor = iBLMap.g;
    }
    else if (debugLog == 3)
    {
        finalColor = iBLMap.b;
    }
    else if (debugLog == 4)
    {
        if (iBLMap.a > debugParams.x && iBLMap.a < debugParams.y)
        {
            finalColor = iBLMap.a;
        }
        else
        {
            finalColor = 0;
        }
        //finalColor = iBLMap.a;
    }

    return finalColor.rgb;
}

float3 NPR_Add_body(v2f i, Light light, float f0, float specularWith, float specularIns,
                    float sepcularMatellicIns, float4 debugParams = 0, float debugLog = 0)
{
    float4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
    float4 iBLMap = SAMPLE_TEXTURE2D(_IBLMap, sampler_IBLMap, i.uv);

    i.normalWS = normalize(i.normalWS);
    float3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
    float3 lightDir = normalize(light.direction.xyz);
    float3 halfDir = normalize(viewDirWS + lightDir);
    float NdotL = saturate(dot(i.normalWS, lightDir));
    float halfNdotL = NdotL * 0.5 + 0.5;
    float HdotN = saturate(dot(i.normalWS, halfDir));
    float VdotN = saturate(dot(viewDirWS, i.normalWS));
    //NdotL = smoothstep(0.5,0.6,NdotL);


    //--------基础色----------//
    float atten = light.shadowAttenuation * light.distanceAttenuation * 0.5;
    float shadow = smoothstep(0, 0.2, NdotL); //考虑到被物体遮挡
    //shadow = max(shadow, 0.0);
    //return atten;
    float2 uv = float2(shadow, iBLMap.a);
    //uv = float2(shadow,_DebugParams.w/10);
    float3 rampColor;
    #if SKYBOX_RAMP == SKYBOX_RAMP_COORHAIR
    uv = float2(shadow, 0.75);
    rampColor = SAMPLE_TEXTURE2D(_RampMap01, sampler_RampMap01, uv);
    #elif SKYBOX_RAMP == SKYBOX_RAMP_WARMHAIR
                    uv = float2(shadow, 0.25);
                    rampColor = SAMPLE_TEXTURE2D(_RampMap01, sampler_RampMap01, uv);
    #elif SKYBOX_RAMP == SKYBOX_RAMP_COORBODY
                    rampColor = SAMPLE_TEXTURE2D(_RampMap02, sampler_RampMap02, uv);
    #elif SKYBOX_RAMP == SKYBOX_RAMP_WARMBODY
                    rampColor = SAMPLE_TEXTURE2D(_RampMap03, sampler_RampMap03, uv);
    #endif
    float3 diffuseColor = baseMap.rgb * rampColor * light.color * shadow * atten;
    float isAO = step(-0.1, iBLMap.r) - step(0.1, iBLMap.r);
    float isDiffuse = step(0.1, iBLMap.r) - step(1.1, iBLMap.r);
    diffuseColor = isAO * 0 + isDiffuse * diffuseColor;
    //return shadow;
    //return float4(diffuseColor,1);

    //---------高光----------//
    float MatCap = SAMPLE_TEXTURE2D(_MatCap, sampler_MatCap,
                                    i.MatCapUV.xy).r;
    float sepcular;
    float sepcularMetallic;
    float2 _MatCapUV;
    #if defined(_HAIR)
                sepcular=0;
                sepcularMetallic = iBLMap.b;
                _MatCapUV = i.MatCapUV.xy;
    #else
    sepcular = iBLMap.g;
    sepcularMetallic = iBLMap.b;
    _MatCapUV = i.MatCapUV.zw;
    #endif


    //非金属的高光我可以尝试用BRDF代替
    float3 specularRamp;
    #if SKYBOX_RAMP == SKYBOX_RAMP_COORHAIR
    specularRamp = SAMPLE_TEXTURE2D(_RampMap01, sampler_RampMap01, float2(0.15, iBLMap.a));
    specularRamp *= shadow;
    #elif SKYBOX_RAMP == SKYBOX_RAMP_WARMHAIR
                    specularRamp = SAMPLE_TEXTURE2D(_RampMap01, sampler_RampMap01, float2(0.15,iBLMap.a));
                    specularRamp*=shadow;
    #elif SKYBOX_RAMP == SKYBOX_RAMP_COORBODY
                    specularRamp = SAMPLE_TEXTURE2D(_RampMap02, sampler_RampMap02, float2(0.15,iBLMap.a));
    #elif SKYBOX_RAMP == SKYBOX_RAMP_WARMBODY
                    specularRamp = SAMPLE_TEXTURE2D(_RampMap03, sampler_RampMap03, float2(0.15,iBLMap.a));
    #endif


    //---------金属效果----------//
    float MatCap2 = SAMPLE_TEXTURE2D(_MatCap, sampler_MatCap, _MatCapUV).r;
    //specularRamp = SAMPLE_TEXTURE2D(_RampMap03, sampler_RampMap03, float2(0.2,_DebugParams.w));
    half specularMatel = MatCap * pow(sepcularMetallic, 2) * shadow;
    //specularMatel = pow(HdotN, _SpecularWith);
    //specularMatel = step(_DebugParams.w,specularMatel) ;
    float3 specularMatelColor = MatCap2 * sepcularMatellicIns * sepcularMetallic * baseMap.rgb;
    specularMatelColor *= light.color * rampColor * light.shadowAttenuation * light.distanceAttenuation;
    //return MatCap;
    //return float4(specularRamp,1);


    //------最终颜色混合------//
    float3 finalColor = 0;
    if (debugLog == 0)
    {
        //diffuseColor = diffuseColor;
        //finalColor = specularMatelColor;
        //finalColor = diffuseColor;
        finalColor = diffuseColor + specularMatelColor;
        //finalColor = specularMatelColor;
        //finalColor += diffuseColor+specularColor;
        //finalColor = diffuseColor + specularMatelColor;
        //finalColor = 0;
    }
    else if (debugLog == 1)
    {
        finalColor = iBLMap.r;
    }
    else if (debugLog == 2)
    {
        finalColor = iBLMap.g;
    }
    else if (debugLog == 3)
    {
        finalColor = iBLMap.b;
    }
    else if (debugLog == 4)
    {
        if (iBLMap.a > debugParams.x && iBLMap.a < debugParams.y)
        {
            finalColor = iBLMap.a;
        }
        else
        {
            finalColor = 0;
        }
        //finalColor = iBLMap.a;
    }

    return finalColor.rgb;
}


float3 NPR_face(v2f i, Light light, float _ShadowOffset, float4 debugParams = 0)
{
    float4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
    float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);

    i.normalWS = normalize(i.normalWS);
    i.faceDorWS = normalize(i.faceDorWS);
    float3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
    float3 lightDir = normalize(light.direction);
    float3 halfDir = normalize(viewDirWS + lightDir);
    float NdotL = saturate(dot(i.normalWS, lightDir));
    float halfNdotL = NdotL * 0.5 + 0.5;
    float HdotN = saturate(dot(i.normalWS, halfDir));
    float VdotN = saturate(dot(viewDirWS, i.normalWS));
    //NdotL = smoothstep(0.5,0.6,NdotL);


    //---------脸部SDF----------//
    half3 F = SafeNormalize(half3(i.faceDorWS.x, 0.0, i.faceDorWS.z));
    half3 L = SafeNormalize(half3(lightDir.x, 0.0, lightDir.z));
    half FDotL = dot(F, L);
    half FCrossL = cross(F, L).y; //控制左右
    half isShadow = step(0, FDotL); //控制是否有阴影
    float2 shadowUV = i.uv;
    //判断方向
    shadowUV.x = lerp(shadowUV.x, 1.0 - shadowUV.x, step(0.0, FCrossL));
    float4 lightingMap = SAMPLE_TEXTURE2D(_LightingMap, sampler_LightingMap, shadowUV);
    half faceShadow = smoothstep
    (
        FDotL * -0.5 + 0.5 + _ShadowOffset,
        FDotL * -0.5 + 0.5 + _ShadowOffset + 0.01,
        lightingMap.a
    );
    //return faceShadow;
    //faceShadow*=light.shadowAttenuation;

    //--------基础色----------//
    float3 rampColor = 0;
    float2 uv = float2(faceShadow + debugParams.w, 0.1);
    #if SKYBOX_RAMP == SKYBOX_RAMP_COORBODY
                //return 0.55;
                rampColor = SAMPLE_TEXTURE2D(_RampMap02, sampler_RampMap02, uv);
    #elif SKYBOX_RAMP == SKYBOX_RAMP_WARMBODY
                    //return 1;
                    rampColor = SAMPLE_TEXTURE2D(_RampMap03, sampler_RampMap03, uv);
    #endif
    float3 diffuseColor = baseMap.rgb * rampColor * light.color;
    //return float4(rampColor,1);
    //return lightingMap.g;


    float3 finalColor = 0;
    //finalColor = specularMatelColor;
    //finalColor += diffuseColor+specularColor;
    finalColor = diffuseColor;

    return finalColor;
}

float3 NPR_Add_face(v2f i, Light light, float _ShadowOffset, float4 debugParams = 0)
{
    float4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
    float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);

    i.normalWS = normalize(i.normalWS);
    i.faceDorWS = normalize(i.faceDorWS);
    float3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
    float3 lightDir = normalize(light.direction);
    float3 halfDir = normalize(viewDirWS + lightDir);
    float NdotL = saturate(dot(i.normalWS, lightDir));
    float halfNdotL = NdotL * 0.5 + 0.5;
    float HdotN = saturate(dot(i.normalWS, halfDir));
    float VdotN = saturate(dot(viewDirWS, i.normalWS));
    float atten = light.shadowAttenuation * light.distanceAttenuation * 0.25;
    //NdotL = smoothstep(0.5,0.6,NdotL);


    //---------脸部SDF----------//
    half3 F = SafeNormalize(half3(i.faceDorWS.x, 0.0, i.faceDorWS.z));
    half3 L = SafeNormalize(half3(lightDir.x, 0.0, lightDir.z));
    half FDotL = dot(F, L);
    half FCrossL = cross(F, L).y; //控制左右
    half isShadow = step(0, FDotL); //控制是否有阴影
    float2 shadowUV = i.uv;
    //判断方向
    shadowUV.x = lerp(shadowUV.x, 1.0 - shadowUV.x, step(0.0, FCrossL));
    float4 lightingMap = SAMPLE_TEXTURE2D(_LightingMap, sampler_LightingMap, shadowUV);
    half faceShadow = smoothstep
    (
        FDotL * -0.5 + 0.5 + _ShadowOffset,
        FDotL * -0.5 + 0.5 + _ShadowOffset + 0.01,
        lightingMap.a
    );
    //return faceShadow;
    //faceShadow*=light.shadowAttenuation;

    //--------基础色----------//
    float colorMask = saturate(1-lightingMap.r);
    float3 rampColor = 0;
    float2 uv = float2(faceShadow + debugParams.w, 0.1);
    #if SKYBOX_RAMP == SKYBOX_RAMP_COORBODY
                //return 0.55;
                rampColor = SAMPLE_TEXTURE2D(_RampMap02, sampler_RampMap02, uv);
    #elif SKYBOX_RAMP == SKYBOX_RAMP_WARMBODY
                    //return 1;
                    rampColor = SAMPLE_TEXTURE2D(_RampMap03, sampler_RampMap03, uv);
    #endif
    float3 diffuseColor = baseMap.rgb * rampColor * light.color*atten*faceShadow;
    //return lightingMap.r;
    //return light.color*atten;
    return float4(diffuseColor,1);
    //return lightingMap.g;


    float3 finalColor = 0;
    //finalColor = specularMatelColor;
    //finalColor += diffuseColor+specularColor;
    finalColor = diffuseColor;

    return finalColor;
}



//--------------------描边-------------------------------//
float _EdgeWidth;
float3 _EdgeColor;
float _DebugLog;

v2f OutLineVert(appdata v)
{
    v2f o;
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
    UNITY_TRANSFER_INSTANCE_ID(v, o);

    float3 normalOS = v.normal.xyz;
    #if defined(_SoomthNormal)
    normalOS = v.tangent.xyz;
    #endif

    float edgeWidth = _EdgeWidth * 0.01*saturate(v.color.r);
    //根据与摄像机的位置坐衰减
    float4 posClip = TransformObjectToHClip(float4(v.vertex.xyz, 1));
    float4 posView = mul(UNITY_MATRIX_MV,float4(v.vertex.xyz, 1));
    //float depth = (posClip.z/posClip.w)*0.5+0.5;
    float depth = abs(posView.z);
    depth = min(depth,_EdgeViewScale);
    depth = lerp(depth,1,0.05);
    edgeWidth *= depth;
    //posView+=_EdgeOutLineOffset;
    
    float3 newVertex = v.vertex + edgeWidth*normalOS;
    o.vertex = TransformObjectToHClip(float4(newVertex, 1));
    o.vertex.z+=_EdgeOutLineOffset.z/1000;
    return o;
}
