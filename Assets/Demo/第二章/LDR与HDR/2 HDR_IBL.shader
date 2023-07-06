Shader "2/HDR_IBL"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        
        _Roughness ("Roughness",Range(0,1)) = 0.5
        _Reflectivity("Reflectivity",Range(0,1))=0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            //#include "UnityStandardCore.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Roughness;
            float _Reflectivity;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 normal:NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 worldNormal:TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };



            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld,o.vertex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            float4 frag(v2f i):SV_Target
            {
                float4 baseColor = tex2D(_MainTex, i.uv);

                float NdotL = saturate(dot(i.worldNormal, _WorldSpaceLightPos0.xyz));
                NdotL = saturate(NdotL);
                //float NdotH = saturate(dot(i.halfRef, i.normalWS));
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
                float3 h = normalize(viewDir + _WorldSpaceLightPos0.xyz);
                float NdotH = saturate(dot(i.worldNormal, h));
                float HdotL = saturate(dot(h, _WorldSpaceLightPos0.xyz));
                float NdotV = saturate(dot(i.worldNormal, viewDir));
                
                //-------IBL(间接光)------//
                //half3 ambient_GI = FragmentGI(); //环境光
                //-----间接光镜面反射
                float mip_roughness = _Roughness * (1.7 - 0.7 * _Roughness);
                float3 refDirWS = reflect(-viewDir, i.worldNormal);
                half mip = mip_roughness * UNITY_SPECCUBE_LOD_STEPS;
                half4 encodedIrradiance = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0,refDirWS,mip);

                //float3 iblSpecular = DecodeHDR(encodedIrradiance, unity_SpecCube0_HDR);
                float grazingTerm = saturate(2 - _Reflectivity - _Roughness);
                float3 ibl = encodedIrradiance.rgb * FresnelTerm(_Reflectivity,NdotV);

                float3 finalColor = ibl;

                #if _On_Test
                #endif
                

                //漫反射测试
                //return float4(FresnelTerm(_Reflectivity,NdotV),1) ;
                return float4(ibl,1);

                return float4(FresnelLerp(float3(0.04,0.04,0.04), grazingTerm, NdotV), 1);
            }
            ENDCG
        }
    }
}
