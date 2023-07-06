Shader "MyBRDF/MyBRDFByTest"
{
    // Keep properties of StandardSpecular shader for upgrade reasons.
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}

        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _Glossiness("Smoothness (平滑度)", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        [Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0

        //        [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        //        _MetallicGlossMap("Metallic", 2D) = "white" {}
        //
        //        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        //        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0
        //
        //        _BumpScale("Scale", Float) = 1.0
        //        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}
        //
        //        _Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
        //        _ParallaxMap ("Height Map", 2D) = "black" {}
        //
        //        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        //        _OcclusionMap("Occlusion", 2D) = "white" {}
        //
        //        _EmissionColor("Color", Color) = (0,0,0)
        //        _EmissionMap("Emission", 2D) = "white" {}
        //
        //        _DetailMask("Detail Mask", 2D) = "white" {}
        //
        //        _DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
        //        _DetailNormalMapScale("Scale", Float) = 1.0
        //        [Normal] _DetailNormalMap("Normal Map", 2D) = "bump" {}
        //
        //        [Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0
        
        [Toggle(_On_Test)] _On_Test("测试",Float)=0


        // Blending state
        [HideInInspector] _Mode ("__mode", Float) = 0.0
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] _ZWrite ("__zw", Float) = 1.0

    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "SimpleLit"
            "IgnoreProjector" = "True"
            "ShaderModel"="4.5"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            // Use same blending / depth states as Standard shader
            //            Blend[_SrcBlend][_DstBlend]
            //            ZWrite[_ZWrite]
            //            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "DisneyDiffuse.hlsl"
            #include "Specular.hlsl"
            #include "Fresnel.hlsl"
            #pragma shader_feature _On_Test
            // #pragma vertex LitPassVertexSimple
            // #pragma fragment LitPassFragmentSimple
            //
            // #include "Packages/com.unity.render-pipelines.universal/Shaders/SimpleLitInput.hlsl"
            // #include "Packages/com.unity.render-pipelines.universal/Shaders/SimpleLitForwardPass.hlsl"
            //
            // #pragma vertex LitPassVertex
            // #pragma fragment LitPassFragment
            //
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"

            #pragma vertex vertex
            #pragma fragment fragment

            half4 _Color;
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;

            float _Cutoff; //透明度

            float _Glossiness;
            float _GlossMapScale;

            float _Metallic;
            TEXTURE2D(_MetallicGlossMap);
            SAMPLER(sampler_MetallicGlossMap);

            float _BumpScale;
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);

            half4 _EmissionColor;
            TEXTURE2D(_EmissionMap);
            SAMPLER(sampler_EmissionMap);

            struct appdata
            {
                float4 pos : POSITION;
                float4 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float3 tangent : TANGENT;
                float4 color :COLOR;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 halfRef : TEXCOORD2;
                float3 viewDir:TEXCOORD3;
                float3 posWS:TEXCOORD4;
                float3 normalOS:TEXCOORD5;
            };

            v2f vertex(appdata v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.pos);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normalWS = TransformObjectToWorldNormal(v.normal);

                float3 posWS = TransformObjectToWorld(v.pos);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - posWS);
                o.halfRef = normalize(viewDir + _MainLightPosition.xyz);
                o.viewDir = viewDir;
                o.posWS = posWS;
                o.normalOS = v.normal;
                return o;
            }

            float4 fragment(v2f i):SV_Target
            {
                float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                Light light = GetMainLight();

                float3 normalWS = TransformObjectToWorldNormal(i.normalOS);
                float NdotL = saturate(dot(normalWS, light.direction));
                float halfNdotL = dot(normalWS, light.direction) * 0.5 + 0.5;
                float NdotV = saturate(dot(normalWS, i.viewDir));
                float HdotL = saturate(dot(i.halfRef, light.direction));
                
                //float NdotH = saturate(dot(i.halfRef, i.normalWS));
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz-i.posWS);
                float3 h = normalize(viewDir + light.direction.xyz);
                float NdotH = saturate(dot(normalWS,h));
                
                float perceptualRoughness = 1 - _Glossiness;
                float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

                //DisneyDiffuse 部分
                float diffuseLight = DisneyDiffuseLight(NdotL, HdotL, perceptualRoughness);
                float diffuseView = DisneyDiffuseView(NdotV, HdotL, perceptualRoughness);
                float diffuse = MyDisneyDiffuse(NdotV, NdotV, HdotL, perceptualRoughness) * halfNdotL;


                //---------Specular(反射部分)--------//
                //NDF,法线分布函数
                float NDF = ggx_term_byTR(NdotH, roughness);
                // NDF = NDFTerm(NdotH,roughness);

                //GGX,几何遮蔽函数
                float GGX = SmithJointGGXVisibilityTerm2(NdotL, NdotV, roughness);

                //反射光
                float specularTerm = max(0, NDF * GGX * PI * NdotL);

  
                #if _On_Test
                #endif
                return specularTerm;;


                return float4(i.halfRef, 1);
            }
            ENDHLSL
        }
    }

    Fallback "Hidden/Universal Render Pipeline/FallbackError"
    //CustomEditor "UnityEditor.Rendering.Universal.ShaderGUI.SimpleLitShader"
}