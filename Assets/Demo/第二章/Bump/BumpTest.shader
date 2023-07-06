Shader "2/BumpTest"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MainColor("MainColor",color) = (1,1,1,1)

        _NormalMap ("NormalMap", 2D) = "white" {}
        _NormalScale("NormalScale",Range(0,1))=1

        _SpecularInt ("SpecularInt",Range(0,1))=1

        _HeightMap ("HeightMap", 2D) = "white" {}
        _HeightScale ("HeightScale", Range(-0.1,0.1)) = 0
        _OccMap ("OccMap", 2D) = "white" {}

        _CubeMap ("CubeMap", cube) = "white" {}

        [Enum(shicha,0,touposhicha,1)] _Enum ("视差映射类型", Float) = 0
        [Enum(linRGB,0,sRGB,1)] _RGBEnum ("选择线性/非线性空间", Float) = 0

        [HDR]_Color ("baseColor",Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        CGINCLUDE
        #include <UnityCG.cginc>
        #include <Lighting.cginc>
        #include <AutoLight.cginc>

        float _Enum;
        sampler2D _MainTex;
        float4 _MainTex_ST;
        float4 _MainColor;

        sampler2D _NormalMap;
        float4 _NormalMap_ST;
        float _NormalScale;
        float _SpecularInt;

        sampler2D _HeightMap;
        float4 _HeightMap_ST;
        float _HeightScale;
        sampler2D _OccMap;
        float4 _OccMap_ST;

        samplerCUBE _CubeMap;

        float4 _Color;
        float _ChangeEnum;


        //视差映射
        float2 ParallaxMapping(float2 Height_HV, float3 V)
        {
            float height =tex2D(_HeightMap, Height_HV).r;
            //height =smoothstep(0.2,0.8,height);
            //return height;
            float2 offsetuv = V.xy / V.z * pow(height, 1) * _HeightScale;
            return offsetuv;
        }

        //陡峭视差映射
        float2 SteepParallaxMapping(float2 uv, float3 V)
        {
            float layerNum = 40; //迭代层数
            float layerHeight = 1 / layerNum; //每层步进距离
            float currentLayerHeight = 0; //当前高度
            float2 offsetLayerUV = V.xy / V.z * _HeightScale; //最大偏移距离
            float2 stepOffset = offsetLayerUV / layerNum; //每步偏移量
            float2 offsetUV = float2(0, 0);
            float2 currentUV = uv; //当前采样高度UV
            float currentHeight = tex2D(_HeightMap, currentUV + offsetUV).r; //当前高度
            for (int i = 0; i < layerNum; i++)
            {
                if (currentLayerHeight > currentHeight)
                {
                    return offsetUV; //当前采样的层数高度，大于当前高度
                }
                offsetUV += stepOffset;
                currentHeight = tex2D(_HeightMap, currentUV + offsetUV).r; //采样偏移
                currentLayerHeight += layerHeight;
            }

            return offsetUV;
        }

        //浮雕映射
        float2 ReliefMapping(float2 uv, float3 V)
        {
            float2 offlayerUV = V.xy / V.z * _HeightScale; //依然是最大偏移量
            float RayNumber = 40; //步进算法
            float layerHeight = 1 / RayNumber; //每层高度
            float2 SteppingUV = offlayerUV / RayNumber; //每步偏移量
            float currentLayerHeight = 0; //当前高度
            float offlayerUVL = length(offlayerUV); //长度
            float2 offUV = float2(0, 0);
            for (int i = 0; i < RayNumber; i++)
            {
                offUV += SteppingUV;
                float currentHeight = tex2D(_HeightMap, uv + offUV).r;
                currentLayerHeight += layerHeight; //层数增加
                if (currentHeight < currentLayerHeight)
                {
                    break;
                }
            }

            float2 T0 = uv + offUV; //当前UV
            float2 T1 = uv + offUV - SteppingUV; //上一个UV

            //二分查找
            for (int j = 0; j < 40; j++)
            {
                float2 P0 = (T1 + T0) * 0.5;
                float P0Height = tex2D(_HeightMap, P0).r; //当前采样高度
                float P0LayerHeight = length(P0) / offlayerUVL; //当前高度（公式中还应乘上总高度1）

                if (P0Height < P0LayerHeight)
                {
                    T0 = P0;
                }
                else
                {
                    T1 = P0;
                }
            }
            return (T0 + T1) / 2 - uv;
        }
        ENDCG

        Pass
        {
            ZTest LEqual
            ZWrite On
            Cull Back

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include <Lighting.cginc>
            #include <AutoLight.cginc>

            // float _RGBEnum;
            // sampler2D _MainTex;
            // float4 _MainTex_ST;
            // float4 _MainColor;
            //
            // sampler2D _NormalMap;
            // float4 _NormalMap_ST;
            // float _NormalScale;
            // float _SpecularInt;
            //
            // sampler2D _HeightMap;
            // float4 _HeightMap_ST;
            // sampler2D _OccMap;
            // float4 _OccMap_ST;
            //
            // samplerCUBE _CubeMap;
            //
            // float4 _Color;
            // float _ChangeEnum;

            struct appdata
            {
                float3 normal : NORMAL;
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 tangent:TANGENT;
            };

            struct v2f
            {
                float4 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 nDirWS : TEXCOORD1;
                //float3 lDirWS : TEXCOORD2;
                float3 posWS : TEXCOORD3;
                float3 TDirWS : TEXCOORD4;
                float4 uv2 : TEXCOORD5;
                float3 BDirWS : TEXCOORD6;
                float4 color: TEXCOORD7;
            };


            v2f vert(appdata v)
            {
                v2f o;
                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.uv, _NormalMap);
                o.uv2.xy = TRANSFORM_TEX(v.uv, _HeightMap);
                o.uv2.zw = TRANSFORM_TEX(v.uv, _OccMap);

                o.nDirWS = UnityObjectToWorldNormal(v.normal.xyz);
                o.posWS = mul(unity_ObjectToWorld, v.vertex);
                o.vertex = UnityObjectToClipPos(v.vertex);
                // float height = tex2Dlod(_HeightMap,float4(o.uv2.xy,0,0)).r;
                // float3 newPos = o.posWS+_HeightScale*height*o.nDirWS;
                // o.color = height;
                // o.posWS = newPos;
                //o.vertex = UnityWorldToClipPos(newPos);

                o.TDirWS = normalize(UnityObjectToWorldDir(v.tangent.xyz));
                o.BDirWS = normalize(cross(o.nDirWS, o.TDirWS) * v.tangent.w);

                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                // sample the texture
                //-------HalfLambert--------
                //return i.color;

                float2 MainTex_UV = i.uv.xy;
                float2 Normal_UV = i.uv.zw;

                half3x3 TBN = transpose(half3x3(i.TDirWS, i.BDirWS, i.nDirWS)); //TBN矩阵
                float3 VDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                half3 VDirTS = normalize(mul(-VDirWS, TBN));

                float2 offuv;
                offuv = 1 - lerp( ParallaxMapping(i.uv2.xy, VDirTS),SteepParallaxMapping(i.uv2.xy, VDirTS), _Enum);
                MainTex_UV += offuv;
                Normal_UV += offuv;
                //return offuv.r;

                //贴图采样
                float ao = tex2D(_OccMap, MainTex_UV).r;
                float3 TexCol = tex2D(_MainTex, MainTex_UV).rgb * float3(1, 0.6, 0.2);

                float3 normalTS = UnpackNormal(tex2D(_NormalMap, Normal_UV)).xyz;
                normalTS.xy *= _NormalScale;
                normalTS.z = sqrt(1 - saturate(dot(normalTS.xy, normalTS.xy)));

                float3 NDirWS = normalize(mul(TBN, normalTS));
                float3 lDirWS = normalize(_WorldSpaceLightPos0);
                i.nDirWS = NDirWS;

                // float height =1- tex2D(_HeightMap,i.uv2.xy);
                // float3 newPos = i.posWS + NDirWS*_HeightScale;
                // float3 newViewDir = normalize(_WorldSpaceCameraPos.xyz - newPos);
                float3 RDirWS = normalize(reflect(-VDirWS, NDirWS));

                //float3 RDirWS = normalize(reflect(-VDirWS, NDirWS));
                float3 HDirWS = normalize(VDirWS + lDirWS);
                float NdotL = dot(NDirWS, lDirWS) * 0.5 + 0.5;
                float NDotH = max(0, dot(NDirWS, HDirWS));


                float Glossiness = lerp(0, 50, _SpecularInt);
                float MipMapLevel = lerp(0.00001, 8, 1 - _SpecularInt);

                float3 Diffuse = _LightColor0.rgb * TexCol * _MainColor * NdotL;
                float3 Specular = _SpecularInt * pow(NDotH, Glossiness);
                float3 ambient = texCUBElod(_CubeMap, float4(RDirWS, 1)) * UNITY_INV_PI;
                float3 result = Diffuse + Specular + ambient; //+ambient
                result = lerp(float3(0, 0, 0), result, ao);
                return float4(result, 1);
            }
            ENDCG
        }
    }
}