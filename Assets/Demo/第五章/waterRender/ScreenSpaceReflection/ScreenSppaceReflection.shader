Shader "5/ScreenSppaceReflection"
{
    Properties
    {
        _MainTex("MainTex",2D) = "while"{}
        _BaseColor("outline color",color) = (1,1,1,1)
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

            half3 ScreenSpaceReflection(float3 reflectVector,
                                        float3 positionWS, float3 screenStart)
            {
                float3 tempWS = positionWS + reflectVector * 1;
                float4 temp_scrPos = ComputeScreenPos(TransformWorldToHClip(tempWS));
                float3 temp_screen = temp_scrPos.xyz / temp_scrPos.w;
                //return temp_screen;
                //屏幕空间的方向
                float3 scrStepDir = normalize(temp_screen - screenStart);
                //return scrStepDir;
                float3 curScreen = screenStart;
                float hit = 0.5;
                float2 hitUV = float3(0, 0, 0);

                //UNITY_UNROLL
                for (int i = 0; i < 100 && i < maxRayMarchingStep; i++)
                {
                    //每次循环都递进一步
                    curScreen += (screenStep * scrStepDir*_CameraOpaqueTexture_TexelSize.y);
                    //当curScreen超出屏幕范围时
                    if (curScreen.x < 0 || curScreen.x > 1 || curScreen.y < 0 || curScreen.y > 1 || curScreen.z < 0 ||
                        curScreen.z > 1)
                    {
                        //return float3(curScreen.xy, curScreen.z);
                        hit = 0.0;
                        //hitUV = curScreen.xy;
                        break;
                    }
                    float curDepth = curScreen.z;
                    float recordDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture,
                                                           curScreen.xy).r;

                    //if (curDepth > recordDepth - depthThickness)// && recordDepth + depthThickness > curDepth)
                    if (recordDepth + depthThickness > curDepth)
                    {
                        hit = 1;
                        hitUV = curScreen.xy;
                        break;
                    }
                }
                return half3(hitUV.xy, hit);
            }

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
                
                float depth = SAMPLE_TEXTURE2D_X(
                    _CameraDepthTexture, sampler_CameraDepthTexture, screenSpace.xy).r;
                
                float3 screenSpaceRef = ScreenSpaceReflection(i.refDirWS, i.posWS,
                                                              screenSpace);

                float3 ssrColor = SAMPLE_TEXTURE2D(
                    _CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenSpaceRef.xy).rgb;

                //return maxRayMarchingStep/150;
                // if (screenSpaceRef.x>1||screenSpaceRef.x<0||screenSpaceRef.y>1||screenSpaceRef.y<0)
                // {
                //     return float4(1,1,0,1);
                // }
                //return i.refDirWS.y;
                //i.refDirWS = TransformObjectToWorld(i.refDirWS);
                //return screenSpaceRef.z;
                //return float4(i.refDirWS,0) ;
                //return float4(screenSpaceRef.xy,0, 0);

                float3 finalColor = ssrColor*_BaseColor.rgb;
                finalColor = lerp(float3(1,1,1),finalColor,screenSpaceRef.z);

                
                return float4(finalColor, 1);
            }
            ENDHLSL
        }
    }
}