Shader "2/GammaTest"
{
    Properties
    {
        [Gamma]_MainTex ("Texture", 2D) = "white" {}
        
        [Enum(yes,0,no,1)] _ChangeEnum ("是否做颜色信息变换", Float) = 0
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

        //线性空间的伽马校正
        inline half3 MyLinearToGammaSpace(half3 linRGB)
        {
            linRGB = max(linRGB, half3(0.h, 0.h, 0.h));
            return max(1.055h * pow(linRGB, 0.416666667h) - 0.055h, 0.h);
        }

        //移除伽马校正的效果
        inline half3 MyGammaToLinearSpace(half3 sRGB)
        {
            return sRGB * (sRGB * (sRGB * 0.305306011h + 0.682171111h) + 0.012522878h);
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

            float _RGBEnum;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Color;
            float _ChangeEnum;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };


            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // sample the texture
                float3 col = tex2D(_MainTex, i.uv).rgb;

                float3 lineRGB = GammaToLinearSpace(col);
                float3 sRGB = LinearToGammaSpace(col);

                //return float4(sRGB,1);
                // apply fog
                //return float4(col * _Color.rgb, 1);
                UNITY_APPLY_FOG(i.fogCoord, col);
                float3 finalColor = lerp(lineRGB, sRGB, _RGBEnum);
                
                return float4(lerp(finalColor,col,_ChangeEnum), 1);
            }
            ENDCG
        }
    }
}