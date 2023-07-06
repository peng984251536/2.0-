Shader "Unlit/flowmap"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Alpha ("Alpha", range(0,1)) = 1
        _Flowmap ("Flowmap", 2D) = "white" {}
        _FlowSpeed("FlowSpeed",float) = 1
        _FlowLerp("FlowLerp",Range(0,1)) = 1
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
            Tags
            {
                "LightMode"="ForwardBase"
            }
            blend SrcAlpha OneMinusSrcAlpha

            ZTest LEqual
            ZWrite On
            Cull Back

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Alpha;

            sampler2D _Flowmap;
            float4 _Flowmap_ST;
            float _FlowSpeed;
            float _FlowLerp;

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
                //获取流向
                half2 flowmap = tex2D(_Flowmap,i.uv).rg*2-1;
                flowmap*=_FlowLerp;
                //frac构造周期
                float phase0 = frac(_Time.y*0.1*_FlowSpeed);
                float phase1 = frac(_Time.y*0.1*_FlowSpeed+0.5);

                
                // sample the texture
                half3 tex0 = tex2D(_MainTex, i.uv+flowmap.xy*phase0).rgb;
                half3 tex1 = tex2D(_MainTex, i.uv+flowmap.xy*phase1).rgb;

                //构造函数
                float flowLerp = abs(0.5-phase0)/0.5;
                half3 flowColor = lerp(tex0,tex1,flowLerp);
                //flowColor=tex0;
                
                float4 finalColor = float4(flowColor,1);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, finalColor);
                finalColor.a = _Alpha;
                return finalColor;
            }
            ENDCG
        }
    }
}