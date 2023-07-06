Shader "3/jignzi"
{
    Properties
    {
        _MainTex("MainTex",2D) = "while"{}
        _NormalMap("NormalMap",2D) = "while"{}
        _NormalScale("_NormalScale",Range(0,1))=1
        _BaseColor("BaseColor",color) = (1,1,1,1)
        _Alpha("_Alpha",Range(0,1)) = 1

        _EdgeWidth("EdgeWidth",vector) = (1,1,1,1)
        [HDR]_EdgeColor("EdgeColor",color) = (1,1,1,1)

        _BorderSize("BorderSize",float) = 0
        [HDR]_BorderColor("BorderColor",color) = (1,1,1,1)
        
        _NoiseMap("NoiseMap",2D) = "while"{}
        _NoiseScale("NoiseScale",Range(0,1.3))=0.5
        _NoiseWidth("NoiseWidth",float)=0.1

        //        _SRef("Stencil Ref", Float) = 1
        //        [Enum(UnityEngine.Rendering.CompareFunction)] _SComp("Stencil Comp", Float) = 8
        //        [Enum(UnityEngine.Rendering.StencilOp)] _SOp("Stencil Op", Float) = 1
        //        [Enum(UnityEngine.Rendering.CompareFunction)] _ZComp("Depth Comp", Float) = 6
    }

    Subshader
    {
        Tags
        {
            "Queue" = "Geometry"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D_X(_NoiseMap);
        SAMPLER(sampler_NoiseMap);
        TEXTURE2D(_NormalMap);
        SAMPLER(sampler_NormalMap);
        TEXTURE2D_X(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);
        TEXTURE2D(_MyOpauqeTexture);
        SAMPLER(sampler_MyOpauqeTexture);
        float4 _MainTex_ST;
        float4 _MainTex_TexelSize;
        float4 _MyOpauqeTexture_TexelSize;
        float2 _EdgeWidth;
        float _BorderSize;
        float4 _BorderColor;
        float _NormalScale;
        float _NoiseScale;
        float _NoiseWidth;

        struct appdata
        {
            float4 vertex: POSITION;
            float3 normal:NORMAL;
            float2 uv :TEXCOORD0;
            float4 tangent:TANGENT;
        };

        struct v2f
        {
            float4 vertex: SV_POSITION;
            float2 uv:TEXCOORD0;
            float2 uv1:TEXCOORD1;

            float3 TDirWS : TEXCOORD2;
            float3 BDirWS : TEXCOORD3;
            float3 NDirWS : TEXCOORD4;
        };

        float3 GaoShiTexFrac(float2 uv)
        {
            float weight[3] = {0.4026, 0.2442, 0.0545};

            float2 uv0 = uv;
            float2 uv1 = uv0 + float2(0, _MyOpauqeTexture_TexelSize.y * 1) * _EdgeWidth.x;
            float2 uv2 = uv0 + float2(_MyOpauqeTexture_TexelSize.x * 1, 0) * _EdgeWidth.x;
            float2 uv3 = uv0 - float2(0, _MyOpauqeTexture_TexelSize.y * 1) * _EdgeWidth.x;
            float2 uv4 = uv0 - float2(_MyOpauqeTexture_TexelSize.x * 1, 0) * _EdgeWidth.x;
            float2 uv5 = uv0 + float2(0, _MyOpauqeTexture_TexelSize.y * 2) * _EdgeWidth.x;
            float2 uv6 = uv0 + float2(_MyOpauqeTexture_TexelSize.x * 2, 0) * _EdgeWidth.x;
            float2 uv7 = uv0 - float2(0, _MyOpauqeTexture_TexelSize.y * 2) * _EdgeWidth.x;
            float2 uv8 = uv0 - float2(_MyOpauqeTexture_TexelSize.x * 2, 0) * _EdgeWidth.x;

            float3 sum = SAMPLE_TEXTURE2D(_MyOpauqeTexture, sampler_MyOpauqeTexture, uv0) * weight[0] * 2;
            sum += SAMPLE_TEXTURE2D(_MyOpauqeTexture, sampler_MyOpauqeTexture, uv1) * weight[1];
            sum += SAMPLE_TEXTURE2D(_MyOpauqeTexture, sampler_MyOpauqeTexture, uv2) * weight[1];
            sum += SAMPLE_TEXTURE2D(_MyOpauqeTexture, sampler_MyOpauqeTexture, uv3) * weight[1];
            sum += SAMPLE_TEXTURE2D(_MyOpauqeTexture, sampler_MyOpauqeTexture, uv4) * weight[1];
            sum += SAMPLE_TEXTURE2D(_MyOpauqeTexture, sampler_MyOpauqeTexture, uv5) * weight[2];
            sum += SAMPLE_TEXTURE2D(_MyOpauqeTexture, sampler_MyOpauqeTexture, uv6) * weight[2];
            sum += SAMPLE_TEXTURE2D(_MyOpauqeTexture, sampler_MyOpauqeTexture, uv7) * weight[2];
            sum += SAMPLE_TEXTURE2D(_MyOpauqeTexture, sampler_MyOpauqeTexture, uv8) * weight[2];
            return sum / 2;
        }

        void Unity_Rectangle_float(float2 UV, float Width, float Height, out float Out)
        {
            //把uv转换到0为中心的坐标轴上
            float2 d = abs(UV * 2 - 1) - float2(Width, Height);
            //fwidth = abs( dFdx(v) + dFdy(v))
            //偏导函数求值
            d = 1 - d / fwidth(d);
            Out = saturate(min(d.x, d.y));
        }
        ENDHLSL

        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
                "RenderType" = "Geometry"
            }

            Name "镜子"
            //Blend SrcAlpha OneMinusSrcAlpha
            //ColorMask 0 
            ZTest On
            ZWrite On
            ZTest LEqual
            Cull Back

            //            Stencil
            //            {
            //                Ref[_SRef]
            //                Comp[_SComp]
            //                Pass[_SOp]
            //                Fail keep
            //                ZFail keep
            //            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            half4 _BaseColor;
            float _Alpha;
            half4 _EdgeColor;


            v2f vert(appdata v)
            {
                v2f o;
                //v.vertex.xyz += _Width * normalize(v.vertex.xyz);

                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);


                o.NDirWS = TransformObjectToWorldNormal(v.normal.xyz);
                o.TDirWS = normalize(TransformObjectToWorldDir(v.tangent.xyz));
                o.BDirWS = normalize(cross(o.NDirWS, o.TDirWS) * v.tangent.w);

                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                half2 screenUV = (i.vertex.xy / _ScreenParams.xy);
                half depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
                depth = LinearEyeDepth(depth, _ZBufferParams); //把深度值转回裁剪空间的深度值
                half3 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb;
                half4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv);
                half noiseMap = SAMPLE_TEXTURE2D(_NoiseMap,sampler_NoiseMap,i.uv).r;
                half3x3 TBNtoWS = half3x3
                (
                    i.TDirWS.x, i.BDirWS.x, i.NDirWS.x,
                    i.TDirWS.y, i.BDirWS.y, i.NDirWS.y,
                    i.TDirWS.z, i.BDirWS.z, i.NDirWS.z
                );
                _NoiseScale = pow(_NoiseScale,1/2.2);
                clip(_NoiseScale-noiseMap);
                half isNoiseEdge = step(_NoiseScale-_NoiseWidth,noiseMap);
                

                //-----透明度
                half3 col1 = GaoShiTexFrac(screenUV);

                //基础颜色
                float3 normalTS;
                //UnpackNormal()
                normalTS.xy = normalMap.xy * 2 - 1;
                normalTS.xy *= _NormalScale;
                normalTS.z = sqrt(1 - saturate(dot(normalTS.xy, normalTS.xy)));
                half3 normalWS = mul(TBNtoWS,normalTS);
                baseColor = (dot(_MainLightPosition.xyz,normalWS)*0.5+0.5)*
                    baseColor*_BaseColor;
                baseColor = lerp(baseColor,col1,_Alpha);
                //return float4(baseColor,1);

                //-----交叉颜色
                //vertex.w是视图空间的深度值
                float isEdgeColor = saturate(abs(depth - i.vertex.w) / (_EdgeWidth.y * 0.1));
                //return pow(i.vertex.z/i.vertex.w,1/2.2);
                float3 EdgeColor = lerp(_EdgeColor, baseColor, isEdgeColor);

                //-----边框
                float RectangleMask;
                Unity_Rectangle_float(i.uv,
                                      _BorderSize, _BorderSize,
                                      RectangleMask);
                RectangleMask = 1 - RectangleMask;
                float border = _BorderSize * RectangleMask;
                border = smoothstep(0, 1, border);
                //return borderColor;
                float3 borderColor = lerp(EdgeColor, _BorderColor, border||isNoiseEdge);

                return float4(borderColor.rgb, 1);
            }
            ENDHLSL
        }
    }
}