Shader "CharShadow/CharShadowShader"
{
    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    // float _BilaterFilterFactor; //法线判定的插值
    // float2 _BlurRadius; //滤波的采样范围
    float4 _bilateralParams; //x:BlurRadius.x||y:BlurRadius.y||z:BilaterFilterFactor
    #define BilaterFilterFactor _bilateralParams.z
    #define DirectLightingStrength _bilateralParams.w


    struct a2v
    {
        uint vertexID :SV_VertexID;
    };

    struct v2f
    {
        float4 pos:SV_Position;
        float2 uv:TEXCOORD0;
    };

    v2f vert(a2v IN)
    {
        v2f o;
        o.pos = GetFullScreenTriangleVertexPosition(IN.vertexID);
        o.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
        return o;
    }
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {

            Name "HBAO"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
            

            //获取摄像机空间坐标
            float3 GetWorldPos(float2 uv)
            {
                //采样到的depth，0代表最远处，1代表最近处
                float depth = SampleSceneDepth(uv);
                float2 newUV = float2(uv.x, uv.y);
                newUV = newUV * 2 - 1;


                    depth = 1-depth;
                    float4 viewPos = mul(_PMatrix_invers, float4(newUV, depth*2-1, 1));
                    viewPos /= viewPos.w;
                    viewPos.z = -viewPos.z;
                    //return viewPos.xyz;

                return viewPos.xyz;
            }
            

            half4 frag(v2f IN) : SV_Target
            {
                float2 uv = IN.uv;

                float3 viewPos = GetWorldPos(uv);

                return 0;
            }
            ENDHLSL
        }

    }
}