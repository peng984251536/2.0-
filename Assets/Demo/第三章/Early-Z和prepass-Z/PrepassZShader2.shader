Shader "Unlit/PrepassZShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Alpha("_Alpha",range(0,1)) = 1.0
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            //ZTest Always
            ZTest LEqual
            ZWrite On
            ColorMask 0
            Cull Front

        }

        Pass
        {
            Tags
            {
                "LightMode"="ForwardBase"
            }
            blend SrcAlpha OneMinusSrcAlpha

            ZTest Equal
            ZWrite Off
            Cull Front

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Alpha;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 normalWS : TEXCOORD1;
            };

            //移除伽马校正的效果
            inline half3 MyGammaToLinearSpace(half3 sRGB)
            {
                return sRGB * (sRGB * (sRGB * 0.305306011h + 0.682171111h) + 0.012522878h);
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                col = col * saturate(dot(i.normalWS, _WorldSpaceLightPos0.xyz));
                col.rgb = GammaToLinearSpace(col.rgb); 
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                col.a = _Alpha;
                return col;
            }
            ENDCG
        }
    }
}