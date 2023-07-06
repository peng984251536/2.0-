Shader "URP/GameObjectShader"
{
    Properties
    {

        _MainTex("MainTex",2D) = "while"{}
        _BaseColor("outline color",color) = (1,1,1,1)
        _Alpha("_Alpha",float) = 1

        _SRef("Stencil Ref", Float) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _SComp("Stencil Comp", Float) = 8
        [Enum(UnityEngine.Rendering.StencilOp)] _SOp("Stencil Op", Float) = 2
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZComp("Depth Comp", Float) = 6
    }

    Subshader
    {

        Pass
        {
            Tags
            {
                "Queue" = "Geometry"
            }
            Tags
            {
                "LightMode" = "UniversalForward" "RenderType" = "Opaque"
            }

            //Blend SrcAlpha OneMinusSrcAlpha
            ZTest On
            ZWrite On
            ZTest [_ZComp]
            Cull Off

            Stencil
            {
                Ref[_SRef]
                Comp[_SComp]
                Pass[_SOp]
            }

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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
                float3 posWS:TEXCOORD1;
            };

            #pragma vertex vert
            #pragma fragment frag
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D_X(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            float4 _MainTex_ST;
            float2 _MainTex_TexelSize;

            half4 _BaseColor;
            float _Alpha;
            float4 _MyFlowDir;

            v2f vert(appdata v)
            {
                v2f o;
                //v.vertex.xyz += _Width * normalize(v.vertex.xyz);

                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.posWS = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                float2 screenUV = (i.vertex.xy / _ScreenParams.xy);
                float4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                //float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                //return float4(_MyFlowDir.rgb*0.5+0.5,1);
                //float isClip = dot(viewDir,_MyFlowDir);
                //clip(isClip);

                // half depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
                // depth = LinearEyeDepth(depth, _ZBufferParams);
                //
                // clip(i.vertex.w-depth);

                return float4(tex.rgb * _BaseColor.rgb, _Alpha);
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }

            ZWrite On
            ColorMask 0
            Cull Off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
}