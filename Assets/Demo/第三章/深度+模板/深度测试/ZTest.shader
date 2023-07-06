Shader "3/ZTest"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("Base Color",Color) = (1,1,1,1)
        _Roughness("Roughness",Range(0,1)) = 0.5

        _XRayColor("XRay Color",Color) = (1,1,1,1)
        _Fresnel("Fresnel",Range(0,1)) = 0.5
    }
    SubShader
    {
        LOD 100

        CGINCLUDE
        #include <UnityCG.cginc>
        #include <Lighting.cginc>
        #include <AutoLight.cginc>

        float4 _XRayColor;
        float4 _BaseColor;
        float4 _MainTex_ST;
        sampler2D _MainTex;
        float _Roughness;
        float _Fresnel;

        struct v2f
        {
            float4 pos : SV_POSITION;
            float3 viewDir : TEXCOORD0;
            float3 posWS : TEXCOORD1;
            float3 normalWS : TEXCOORD2;
            float2 uv :TEXCOORD3;
            float4 color : COLOR;
        };

        v2f vertXray(appdata_base v)
        {
            v2f o;
            o.posWS = mul(unity_ObjectToWorld, v.vertex);
            o.pos = UnityObjectToClipPos(v.vertex);
            o.viewDir = normalize(_WorldSpaceCameraPos.xyz - o.posWS);
            o.normalWS = UnityObjectToWorldNormal(v.normal);

            //float rim = 1 - dot(o.normalWS, o.viewDir);

            o.color = _XRayColor;

            return o;
        }

        float4 fragXray(v2f i):SV_Target
        {
            float ndotV = saturate(dot(i.normalWS, i.viewDir));
            float f = _Fresnel + (1 - _Fresnel) * pow((1 - ndotV), 5);

            float3 finalColor = lerp(float3(1,1,1),_XRayColor,f);
            return float4(finalColor,1);
        }

        v2f vertNormal(appdata_base v)
        {
            v2f o;
            o.posWS = mul(unity_ObjectToWorld, v.vertex);
            o.pos = UnityObjectToClipPos(v.vertex);
            //o.viewDir = normalize(_WorldSpaceCameraPos.xyz-o.posWS);
            o.normalWS = UnityObjectToWorldNormal(v.normal);
            o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

            //DecodeDepthNormal()

            return o;
        }

        float4 fragNormal(v2f i):SV_Target
        {
            float4 baseColor = tex2D(_MainTex, i.uv);

            float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
            float3 halfDir = normalize(viewDir + _WorldSpaceLightPos0.xyz);

            float ndotL = dot(i.normalWS, _WorldSpaceLightPos0.xyz);
            float halfNdotL = ndotL * 0.5 + 0.5;
            float ndotV = saturate(dot(i.normalWS, viewDir));
            float ldotH = saturate(dot(_WorldSpaceLightPos0.xyz, halfDir));
            ndotL = saturate(ndotL);
            float perRoughness = _Roughness * _Roughness;

            float fd90 = 0.5 + 2 * ldotH * ldotH * perRoughness;
            float lightScatter = 1 + (fd90 - 1) * pow((1 - ndotL), 5);
            float viewScatter = 1 + (fd90 - 1) * pow((1 - ndotV), 5);

            float3 finalColor = baseColor * _BaseColor.rgb * lightScatter * viewScatter * halfNdotL;
            return float4(finalColor, 1);
        }
        ENDCG

        Pass
        {
            Tags
            {
                "RenderType"="Transparent"
                "Queue"="Transparent"
            }
            Blend DstColor Zero
            //Blend SrcAlpha One
            ZTest Greater
            ZWrite Off
            Cull Back

            CGPROGRAM
            #pragma vertex vertXray
            #pragma fragment fragXray
            ENDCG
        }

        Pass
        {
            Tags
            {
                "RenderType"="Opaque"
                "Queue"="Transparent"
            }
            ZTest LEqual
            ZWrite On
            Cull Back

            CGPROGRAM
            #pragma vertex vertNormal
            #pragma fragment fragNormal
            ENDCG
        }
    }
}