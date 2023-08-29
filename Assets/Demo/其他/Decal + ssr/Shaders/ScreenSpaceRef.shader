Shader "URP/ScreenSpaceRefShader"
{
    Properties {}

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    TEXTURE2D_X(_CameraDepthTexture);
    SAMPLER(sampler_CameraDepthTexture);
    TEXTURE2D(_GBuffer2);//法线
    SAMPLER(sampler_GBuffer2);

    float4 _phaseParams;
    float4  _DebugParams;
    float4x4 _VPMatrix_invers;
    float4x4   _VMatrix;
    float4x4 _VMatrix_invers;
    float2 _haltonVector2;
    float _haltonScale;
    // float _BilaterFilterFactor; //法线判定的插值
    // float2 _BlurRadius; //滤波的采样范围
    float4 _bilateralParams; //x:BlurRadius.x||y:BlurRadius.y||z:BilaterFilterFactor
    #define BlurRadiusX _bilateralParams.x
    #define BlurRadiusY _bilateralParams.y
    #define BilaterFilterFactor _bilateralParams.z
    #define DirectLightingStrength _bilateralParams.w
    static const float2 offset[4] =
    {
        float2(0, 0),
        float2(2, -2),
        float2(-2, -2),
        float2(0, 2)
    };


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

    float3 GetWorldPos(float2 uv, float depth)
    {
        float4 ndc = float4(uv * 2 - 1, (1 - depth) * 2 - 1, 1);
        float4 posWS = mul(_VPMatrix_invers, ndc);
        posWS /= posWS.w;
        return posWS.xyz;
    }
    ENDHLSL

    Subshader
    {
        //Pass 0 反射参数
        Pass
        {

            Name "SSR_RayCast"
            //Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
            ZWrite Off
            ZTest Always


            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "RayCast.hlsl"

            #pragma vertex vert
            #pragma fragment rayCast

            float4 fff(v2f i) : SV_Target
            {
                return float4(1,0.5,1,1);
            }
            
            ENDHLSL
        }

        //Pass 1 着色
        Pass
        {

            Name "SSR_ResolveColor"
            Cull Off
            ZWrite Off
            ZTest Always


            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment resolve

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "SSRef.hlsl"
            ENDHLSL
        }

        //pass 2
        //VF_temporal
        Pass
        {
            Name "VF_temporal"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment TemporalFrag

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Assets/Demo/其他/VolumeFog/Shaders/VFTemporal.hlsl"

            // TEXTURE2D(_CameraTexture);
            // SAMPLER(sampler_CameraTexture);

            float4 TemporalFrag(v2f i) : SV_Target
            {
                float2 uv = i.uv;


                float4 finalCol = temporal(uv);
                return finalCol;
            }
            ENDHLSL
        }
        
        //pass 3
        Pass
        {
            Name "VF_FinalBlur"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment FinalFrag

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "MyBRDF.hlsl"

            #pragma multi_compile_local _ _BRDFSSR
            #define kMaterialFlagSpecularSetup            8 // Lit material use specular setup instead of metallic setup

            TEXTURE2D(_SSRayColor);
            SAMPLER(sampler_SSRayColor);
            TEXTURE2D(_CameraTexture);
            SAMPLER(sampler_CameraTexture);
            TEXTURE2D_X(_GBuffer1);
            SAMPLER(sampler_GBuffer1);
            TEXTURE2D_X(_GBuffer0);
            SAMPLER(sampler_GBuffer0);


            half3 MyGlobalIllumination(BRDFData brdfData,
            half3 bakedGI, float3 positionWS,
            half3 normalWS, half3 viewDirectionWS)
            {
                half3 reflectVector = reflect(-viewDirectionWS, normalWS);
                half NoV = saturate(dot(normalWS, viewDirectionWS));
                half fresnelTerm = Pow4(1.0 - NoV);
                //return fresnelTerm;

                half3 indirectDiffuse = bakedGI;
                half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, brdfData.perceptualRoughness, 1.0h);
                //return indirectDiffuse;
                half3 color = EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
                
                return color;
            }

            // Computes the scalar specular term for Minimalist CookTorrance BRDF
            // NOTE: needs to be multiplied with reflectance f0, i.e. specular color to complete
            half MyDirectBRDFSpecular(BRDFData brdfData, half3 normalWS,
                half3 lightDirectionWS, half3 viewDirectionWS)
            {
                float3 lightDirectionWSFloat3 = float3(lightDirectionWS);
                float3 halfDir = SafeNormalize(lightDirectionWSFloat3 + float3(viewDirectionWS));

                float NoH = saturate(dot(float3(normalWS), halfDir));
                half LoH = half(saturate(dot(lightDirectionWSFloat3, halfDir)));

                // GGX Distribution multiplied by combined approximation of Visibility and Fresnel
                // BRDFspec = (D * V * F) / 4.0
                // D = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2
                // V * F = 1.0 / ( LoH^2 * (roughness + 0.5) )
                // See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
                // https://community.arm.com/events/1155

                // Final BRDFspec = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2 * (LoH^2 * (roughness + 0.5) * 4.0)
                // We further optimize a few light invariant terms
                // brdfData.normalizationTerm = (roughness + 0.5) * 4.0 rewritten as roughness * 4.0 + 2.0 to a fit a MAD.
                float d = NoH * NoH * brdfData.roughness2MinusOne + 1.00001f;
                            //return d;

                half LoH2 = LoH * LoH;
                half specularTerm = brdfData.roughness2 / ((d * d) * max(0.1h, LoH2) * brdfData.normalizationTerm);
                            //return brdfData.roughness2;

                // On platforms where half actually means something, the denominator has a risk of overflow
                // clamp below was added specifically to "fix" that, but dx compiler (we convert bytecode to metal/gles)
                // sees that specularTerm have only non-negative terms, so it skips max(0,..) in clamp (leaving only min(100,...))
                #if defined (SHADER_API_MOBILE) || defined (SHADER_API_SWITCH)
                    specularTerm = specularTerm - HALF_MIN;
                    specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
                #endif

            return specularTerm;
            }

            float4 FinalFrag(v2f i) : SV_Target
            {
                float2 uv = i.uv;

                float4 ssrColor = SAMPLE_TEXTURE2D(_SSRayColor, sampler_SSRayColor, uv);
                //float4 albedoMap = SAMPLE_TEXTURE2D(_GBuffer0, sampler_GBuffer0, uv);
                float4 NormalMap = SAMPLE_TEXTURE2D(_GBuffer2, sampler_GBuffer2, uv);
                float4 cubeMap = SAMPLE_TEXTURE2D(_CameraTexture, sampler_CameraTexture, uv);
                float4 specularMap = SAMPLE_TEXTURE2D_X(_GBuffer1, sampler_GBuffer1, uv);
                specularMap.r = specularMap.r*0.8+0.2;
                float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
                NormalMap.a = clamp(NormalMap.a,0.04,0.96);
                float roughness = 1 - NormalMap.a;
                float3 posWS = GetWorldPos(uv,depth);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz-posWS.xyz);
                //把反射光当做高光交给它计算
                float oneMinusReflectivity =clamp(1- specularMap.r,0.04,0.96);
                float mask = (ssrColor.a);
                //float3 diffuse = albedo.rgb*oneMinusReflectivity;
                BRDFData brdf_data = (BRDFData)1;
                brdf_data.specular = ssrColor.rgb;
                brdf_data.diffuse = 0;
                // brdf_data.roughness2 = max(roughness*roughness,HALF_MIN);
                // brdf_data.roughness2MinusOne = brdf_data.roughness2-1;
                // brdf_data.normalizationTerm = roughness*4.0h+2.0h;
                
                // brdf_data.perceptualRoughness = 1-NormalMap.a;
                // brdf_data.grazingTerm = saturate(NormalMap.a + specularMap.r);
                
                //return mask;


                #if defined(_BRDFSSR)
                Light _light = (Light)0;
                _light.color = 0;
                _light.direction = 0;
                ssrColor.rgb = BRDF_Unity_PBS(0,cubeMap.rgb,oneMinusReflectivity,NormalMap.a,
                    NormalMap.xyz,viewDir,_light,brdf_data);
                return float4(ssrColor.rgb*mask,1);
                #else
                Light _light = (Light)0;
                _light.color = 0;
                _light.direction = 0;
                ssrColor.rgb = BRDF_Unity_PBS(0,cubeMap.rgb,oneMinusReflectivity,NormalMap.a,
                    NormalMap.xyz,viewDir,_light,brdf_data);
                //return float4(ssrColor.rgb*ssrColor.a,1);
                #endif
                
                
                //ssrColor.rgb *
                // float3 ssrInt = DirectBRDFSpecular(brdf_data,
                // worldNormal.xyz,0,viewDir);
                //ssrColor*=GetReflectivity(uv);
                //return ssrInt;
                //return mask;

                float3 finalColor = lerp(cubeMap.rgb,ssrColor.rgb,saturate(mask));
                // finalColor = ssrColor.rgb;
                
                return float4(finalColor.rgb,cubeMap.a);
            }
            ENDHLSL
        }


    }
}