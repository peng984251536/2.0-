Shader "Hidden/Volumetric"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        // 亮度
        _Brightness ("Brightness", Float) = 1

    }

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline"
        }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        #pragma multi_compile _ _SCREEN_SPACE_OCCLUSION
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS _ADDITIONAL_OFF
        #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile _ _SHADOWS_SOFT
        #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

        #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
        #pragma multi_compile _ SHADOWS_SHADOWMASK


        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half _Brightness;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        float4 _CameraDepthTexture_TexelSize;
        TEXTURE2D(_VolumeLightTexture);
        SAMPLER(sampler_VolumeLightTexture);
        float4 _VolumeLightTexture_TexelSize;
        //---------矩阵----------//
        float4x4 _VPMatrix_invers;
        float4x4 _PMatrix_invers;
        float4x4 _VMatrix_invers;
        float4x4 _VMatrix;
        float4x4 _PMatrix;

        //---------MaxDistance----------//
        #define _MaxDistance 200.0f


        struct appdata
        {
            float4 positionOS : POSITION;
            float2 texcoord : TEXCOORD0;
        };

        struct v2f
        {
            float2 uv : TEXCOORD0;
            float4 positionCS : SV_POSITION;
            float3 posWS : TEXCOORD1;
            float3 centerPos:TEXCOORD2;
        };

        float4 GetWorldPos(float2 uv)
        {
            //采样到的depth，0代表最远处，1代表最近处
            float depth = SampleSceneDepth(uv);
            float2 newUV = float2(uv.x, uv.y);
            newUV = newUV * 2 - 1;


            depth = 1 - depth;
            float4 posWS = mul(_VPMatrix_invers, float4(newUV, depth * 2 - 1, 1));
            posWS /= posWS.w;
            //posWS.z = -posWS.z;

            return float4(posWS.xyz,depth) ;
        }

        // 阴影函数
        float Getshadow(float3 posWorld)
        {
            float4 shadowCoord = TransformWorldToShadowCoord(posWorld);
            float shadow = MainLightRealtimeShadow(shadowCoord);
            return shadow;
        }

        v2f vert(appdata v)
            {
                v2f o;
                VertexPositionInputs PositionInputs = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = PositionInputs.positionCS;
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.posWS = TransformObjectToWorld(v.positionOS.xyz);
                o.centerPos = TransformObjectToWorld(float3(0,0,0));

                return o;
        }
        ENDHLSL


        Pass
        {

            Tags
            {
                "LightMode"="MyVolumeLightPass"
            }
            
            Name "VolumetricLight"
            ZTest On
            ZWrite Off
            ZTest LEqual
            //Cull Front


            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            //#define _StepSize 1.0f
            //#define _MaxStep 100
            float _StepSize;
            float _MaxStep;
            float _LightIntensity;
            float4 _LightColor;
            float _LightAttenIntensity;
            float _LightAttenSmooth;
            


            half4 frag(v2f i) : SV_Target
            {
                float2 screenUV = i.positionCS.xy / _VolumeLightTexture_TexelSize.zw;

                float4 posWSAndDepth = GetWorldPos(screenUV);
                float3 posWS =posWSAndDepth.xyz;
                float depth = 1-posWSAndDepth.w;
                if(depth==1)
                    return 0;
                //posWS = i.posWS;
                //return float4(posWS,1);

                //if(depth>i.positionCS.z)
				// {
				// 	clip(-1);
				// }

                //光线步进参数
                float3 rd = normalize(posWS - _WorldSpaceCameraPos.xyz);
                float3 camPos = _WorldSpaceCameraPos.xyz;
                float3 currentPos = _WorldSpaceCameraPos.xyz;


                float m_length = min(length(posWS - _WorldSpaceCameraPos.xyz), 200);

                //测试新算法
                //m_length = distance(posWS,i.centerPos)*2;
                //currentPos = posWS - rd*m_length;
                //return i.positionCS.z;


                float delta = _StepSize*(m_length/_MaxStep);
                float totalInt = 0;
                float d = 0;

                float4 shadowCoord = TransformWorldToShadowCoord(posWS);
                float shadow = MainLightRealtimeShadow(shadowCoord);
                //return shadowCoord.z>_LightAttenIntensity;
                //ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
                //half4 shadowParams = GetMainLightShadowParams();
                //return SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowCoord, shadowSamplingData, shadowParams, false);
                //Light light = GetMainLight(shadowCoord);
                //return shadow;

                // 光线进步计算
                for (int j = 1; j < _MaxStep; j++)
                {
                    d += delta;
                    if (d > m_length) break; // 判断距离大于设定的距离 不在生成
                    // 根据步长 delta 和方向向量 rd 计算出当前像素的位置 currentPos
                    currentPos = camPos + d * rd;
                    // 然后使用 Getshadow 函数计算出当前像素位置的阴影值

                    float4 shadowCoord = TransformWorldToShadowCoord(currentPos);
                    float atten = smoothstep(_LightAttenIntensity,_LightAttenIntensity+_LightAttenSmooth,shadowCoord.z);
                    totalInt += _LightIntensity * saturate( Getshadow(currentPos))*(atten);

                }
                //float4 shadowCoord = TransformWorldToShadowCoord(currentPos);
                //float shadow = MainLightRealtimeShadow(shadowCoord);
                //totalInt = Getshadow(currentPos);
                //return shadow;

                Light mylight = GetMainLight(); //获取场景主光源
                half4 LightColor = half4(mylight.color, 1); //获取主光源的颜色

                half3 lightCol = totalInt * mylight.color / _MaxStep;
                half4 oCol = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, screenUV);
                half3 dCol = oCol.rgb+lightCol.rgb*_LightColor.a; //原图和 计算后的图叠加


                //return m_length;
                return float4(lightCol, 1);

                return 1;
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                col.rgb = col.rgb * _Brightness;
                return col;
            }
            ENDHLSL
        }
        
        
        Pass
        {

            Tags
            {
                "LightMode"="MyVolumeLightPass"
            }
            
            Name "VolumetricLightBlend"
            ZTest On
            ZWrite Off
            ZTest LEqual
            Cull Back


            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            //#define _StepSize 1.0f
            //#define _MaxStep 100
            float _StepSize;
            float _MaxStep;
            float _LightIntensity;
            float4 _LightColor;





            half4 frag(v2f i) : SV_Target
            {
                float2 screenUV = i.positionCS.xy / _CameraDepthTexture_TexelSize.zw;

                half4 vCol = SAMPLE_TEXTURE2D(_VolumeLightTexture, sampler_VolumeLightTexture, screenUV);
                half4 oCol = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, screenUV);
                half3 dCol = oCol.rgb+vCol.rgb*_LightIntensity; //原图和 计算后的图叠加


                //return m_length;
                return float4(dCol, oCol.a);

                return 1;
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                col.rgb = col.rgb * _Brightness;
                return col;
            }
            ENDHLSL
        }
    }
}