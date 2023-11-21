Shader "5/StylizedPBR"
{
    Properties
    {
        _MainTex("MainTex",2D) = "while"{}
        _BaseColor("outline color",color) = (1,1,1,1)
        _LightingMap("lightingMap",2D) = "while"{}
    }

    Subshader
    {
        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward" "RenderType" = "Opaque" "Queue" = "Geometry"
            }

            //Blend SrcAlpha OneMinusSrcAlpha
            ZTest On
            ZWrite On
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"


            struct appdata
            {
                float4 vertex: POSITION;
                float3 normal:NORMAL;
                float2 uv :TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex: SV_POSITION;
                float2 uv:TEXCOORD0;
                float3 normalWS:TEXCOORD1;
                float3 viewDirWS:TEXCOORD2;
                float3 refDirWS:TEXCOORD3;
                float3 posWS:TEXCOORD4;
                float4 posScreenSpace:TEXCOORD5;
            };

            TEXTURE2D_X(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            float4 _CameraDepthTexture_TexelSize;
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);
            float4 _CameraOpaqueTexture_ST;
            float4 _CameraOpaqueTexture_TexelSize;
            half4 _BaseColor;


            float4x4 _PMatrix_invers;
            float4x4 _VMatrix_invers;
            float4x4 _VMatrix;
            float4x4 _PMatrix;
            float4 _SSRParms;
            #define maxRayMarchingStep _SSRParms.x
            #define screenStep _SSRParms.y
            #define depthThickness _SSRParms.z
            

            v2f vert(appdata v)
            {
                v2f o;

                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                o.posWS = TransformObjectToWorld(v.vertex);
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                o.viewDirWS = normalize(_WorldSpaceCameraPos.xyz - o.posWS);
                o.refDirWS = -normalize(reflect(o.viewDirWS, o.normalWS));
                o.posScreenSpace = ComputeScreenPos(o.vertex);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 screenSpace = i.posScreenSpace.xyz/i.posScreenSpace.w;
                i.viewDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                i.refDirWS = -normalize(reflect(i.viewDirWS, i.normalWS));
                //i.refDirWS.y*=-1;

                

                return 0;
                //return float4(finalColor, 1);
            }
            ENDHLSL
        }
    }
}