#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 texcoord : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv : TEXCOORD0;
    float4 positionCS : SV_POSITION;
    float depth :TEXCOORD1;
    float3 normalWS : TEXCOORD2;
    float3 viewPosWS : TEXCOORD3;
};

float3 _MainLightDir;
// float4x4 _LightRotateMatrix;
// float4x4 _LightClipMatrix;
float4x4 _LightPro_Matrix;
float _ShadowDistance;
float _ShadowRampVal;
float3 _LightPosWS;
float4 _ShadowDebugParams;

float3 ApplyShadowBias02(float3 positionWS, float3 normalWS, float3 lightDirection)
{
    float invNdotL = 1.0 - saturate(dot(lightDirection, normalWS));
    float scale = invNdotL * _ShadowDebugParams.y;

    // normal bias is negative since we want to apply an inset normal offset
    positionWS = lightDirection * _ShadowDebugParams.xxx + positionWS;
    positionWS = normalWS * scale.xxx + positionWS;
    return positionWS;
}

float4 GetShadowPosHClip(Attributes input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    //float3 modelPosWS = TransformObjectToWorld(float3(0,0.73,0));
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
    float3 lightDir = normalize(_MainLightDir.xyz);

    //float3 newPosWS = ApplyShadowBias02(positionWS, normalWS, lightDir);

    // float4x4 matrix_move = float4x4
    // (
    //     1, 0, 0, -newPosWS.x + lightDir.x * _ShadowDistance,
    //     0, 1, 0, -newPosWS.y + lightDir.y * _ShadowDistance,
    //     0, 0, 1, -newPosWS.z + lightDir.z * _ShadowDistance,
    //     0, 0, 0, 1
    // );
    // float4x4 matrix_move = float4x4
    //   (
    //       1, 0, 0, lightDir.x * (_ShadowDistance)-modelPosWS.x,
    //       0, 1, 0, lightDir.y * (_ShadowDistance)-modelPosWS.y,
    //       0, 0, 1, lightDir.z * (_ShadowDistance)-modelPosWS.z,
    //       0, 0, 0, 1
    //   );
    //
    // float4x4 matrixLight = mul(_LightRotateMatrix,matrix_move) ;
    
    // float4 positionVS = mul(matrixLight, float4(positionWS, 1.0));
    // float4 positionVS2 = mul(UNITY_MATRIX_V, float4(positionWS, 1.0));
    // float4 posCS = mul(_LightClipMatrix,float4(positionVS.xyz, 1.0));
    // float4 posCS2 = mul(UNITY_MATRIX_P,float4(positionVS2.xyz, 1.0));
    float4 posCS3 = mul(_LightPro_Matrix,float4(positionWS.xyz, 1.0));
    posCS3.xy = posCS3.xy/2 + float2(-posCS3.w,posCS3.w)*0.5 ;
    
    return posCS3;
}

Varyings CharShadowVert(Attributes input)
{
    Varyings o;
    //UNITY_SETUP_INSTANCE_ID(input);
    //UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
    //UNITY_TRANSFER_INSTANCE_ID(input, o);

    float3 posWS = TransformObjectToWorld(input.positionOS);


    o.positionCS = GetShadowPosHClip(input);
    o.depth = 1-((o.positionCS.z/o.positionCS.w)*0.5+0.5);
    o.normalWS = TransformObjectToWorldNormal(input.normalOS);
    o.viewPosWS = normalize(posWS-_LightPosWS.xyz);
    return o;
}

half4 ShadowPassFragment(Varyings input) : SV_TARGET
{
    float depth = input.positionCS.z;
    float VdotN = dot(input.viewPosWS,input.normalWS);
    float frenal = _ShadowRampVal + (1-_ShadowRampVal)*pow(1-VdotN,4.0);
    
    return float4(depth,frenal,0,0);
}

struct ShadowMapOutput
{
    half4 GBuffer0 : SV_Target0;
    half4 GBuffer1 : SV_Target1;
};

ShadowMapOutput ShadowRampFragment(Varyings input)
{
    input.viewPosWS = normalize(input.viewPosWS);
    float depth = input.positionCS.z;

    
    //float frenel = F0 + (1 - F0) * pow(1 - VdotN, specularWith);
    float VdotN = dot(input.viewPosWS,input.normalWS);
    float frenal = _ShadowRampVal + (1-_ShadowRampVal)*pow(1-VdotN,4.0);

    ShadowMapOutput output;
    // output.GBuffer0 = 0;
    // output.GBuffer1 = 0;
    // return;
    
    output.GBuffer0 = input.depth;
    output.GBuffer1 = frenal;

    return output;
}