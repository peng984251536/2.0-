Shader "Unlit/GenshipSkyDetalShader"
{
    Properties
    {
        _IrradianceMap("_IrradianceMap", 2D) = "white" {}
        _BaseColorMap("_BaseColorMap", 2D) = "white" {}
        _NoiseMap("_NoiseMap", 2D) = "white" {}
        _StarMap("_StarMap", 2D) = "white" {}
        
        _star_color_intensity("_star_color_intensity", float) = 1.0
        _StarColor("_StarColor",color)=(1,1,1,1)
        _BackgroundColor("_BackgroundColor",color)=(1,1,1,1)
    }
    
    HLSLINCLUDE
    
    //生成随机数
    float rand(float3 co)
    {
        return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
    }

    float rand2(float3 co)
    {
        float d1 = distance(co.xyz,float3(12.9898, 78.233, 53.539));
        float d2 = distance(co.xyz,float3(-12.9898, -78.233, -53.539));
        return sin(d1+d2)*0.5+0.5;
    }
    
    half3 tex3DAsNormal(Texture2D tex, SamplerState _sampler
        ,float2 xy, float2 yz, float2 xz, float3 worldNormal)
    {
        half3 colorForward = tex.SampleLevel(_sampler,yz,0);
        half3 colorUp = tex.SampleLevel(_sampler,xz,0);
        half3 colorLeft = tex.SampleLevel(_sampler,xy,0); 

        worldNormal = abs(worldNormal);
        worldNormal = worldNormal / (worldNormal.x + worldNormal.y + worldNormal.z);
        half3 finalColor = colorForward * worldNormal.x + colorUp * worldNormal.y + colorLeft * worldNormal.z;

        return finalColor;
    }

    ENDHLSL
    
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent" "Queue" = "Transparent"
        }
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off
        ZTest Always
        

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            /*贴图*/
            TEXTURE2D(_IrradianceMap);
            SAMPLER(sampler_IrradianceMap);
            TEXTURE2D(_NoiseMap);
            SAMPLER(sampler_NoiseMap);
            TEXTURE2D(_StarMap);
            SAMPLER(sampler_StarMap);
            TEXTURE2D(_BaseColorMap);
            SAMPLER(sampler_BaseColorMap);
            float4 _NoiseMap_ST;
            float4 _BaseColorMap_ST;

            // /* day 白天: sun sky 属性 start
            float3 _upPartSunColor;
            float3 _upPartSkyColor;
            float3 _downPartSunColor;
            float3 _downPartSkyColor;
            float3 _upMoonColor;
            float _mainColorSunGatherFactor;
            float _IrradianceMapR_maxAngleRange;


            // add的光（可以理解为自发光）
            float3 _SunAdditionColor;
            float _SunAdditionIntensity;
            float _IrradianceMapG_maxAngleRange;
            //太阳光参数
            float _sun_disk_power_999;
            float3 _sun_color;
            float _sun_color_intensity;
            float2 _sun_atten;

            // // -------------------------- */
            //
            // // /* night 夜晚: moon 属性 
            float _moon_size;
            float _moon_intensity;
            float _moon_bloom;
            float2 _moon_atten;
            float3 _moon_color;
            // // -------------------------- */
            //star
            float3 _StarColor;
            float3 _BackgroundColor;
            float3 _star_color;
            float _star_color_intensity;
            float3 _star_offset;
            float2 _star_mask;
            float2 _star_mask2;
            float _star_scale;
            
            // // -------------------------- */
            //
            // // /* sun & moon dir
            float3 _moon_dir;
            float3 _sun_dir;
            // // -------------------------- */
            //
            // // /* misc 
            // float _star_part_enable;
            // float _sun_part_enable;
            // float _moon_part_enable;
            // // -------------------------- */


            #define _UpDir float3(0,1,0)


            float FastAcosForAbsCos(float in_abs_cos)
            {
                float _local_tmp = ((in_abs_cos * -0.0187292993068695068359375 + 0.074261002242565155029296875) *
                    in_abs_cos - 0.212114393711090087890625) * in_abs_cos + 1.570728778839111328125;
                return _local_tmp * sqrt(1.0 - in_abs_cos);
            }

            float FastAcos(float in_cos)
            {
                float local_abs_cos = abs(in_cos);
                float local_abs_acos = FastAcosForAbsCos(local_abs_cos);
                return in_cos < 0.0 ? PI - local_abs_acos : local_abs_acos;
            }

            // 兼容原本的 GetFinalMiuResult(float u)
            // 真正的含义是 acos(u) 并将 angle 映射到 up 1，middle 0，down -1
            float GetFinalMiuResult(float u)
            {
                float _acos = FastAcos(u);

                // tmp0 = HALF_PI - tmp0;
                // float _angle_up_to_down_1_n1 = (HALF_PI - tmp0) * INV_HALF_PI;
                float angle1_to_n1 = (HALF_PI - _acos) * INV_TWO_PI;
                return angle1_to_n1;
            }

            float3 GetLightDir()
            {
                // return normalize(_MainLightPosition.xyz);
                return normalize(_sun_dir);
            }


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 Varying_StarColorUVAndNoise_UV : TEXCOORD0;
                float4 Varying_NoiseUV_large : TEXCOORD1;
                float4 Varying_ViewDirAndRandom : TEXCOORD2;
                float4 Varying_IrradianceColor : TEXCOORD3;
                float3 posWS :TEXCOORD4;
                float3 normalWS :TEXCOORD5;
                float4 vertex : SV_POSITION;
            };


            v2f vert(appdata v)
            {
                v2f o;
                float3 _worldPos = mul(UNITY_MATRIX_M, float4(v.vertex.xyz, 1.0)).xyz;
                //float4 _clippos = mul(UNITY_MATRIX_VP, float4(_worldPos, 1.0));
                float4 _clippos = TransformObjectToHClip(v.vertex.xyz);
                o.vertex = _clippos;


                //用一个约定俗成的坐标代替摄像机坐标
                // 实际用低位效果与 云 一致，
                #define _RolePos_maybe float3(-3.48413, 195.00, 2.47919)
                float3 _viewDir = normalize(_worldPos.xyz - _WorldSpaceCameraPos /*_WorldSpaceCameraPos*/);
                //
                // //外界传入的太阳向量
                float _VDotSun = dot(_sun_dir, _viewDir.xyz);
                float _VDotMoon = dot(_moon_dir, _viewDir.xyz);
                float _UpDotSun = dot(_UpDir, _sun_dir);
                float upDotV = abs(dot(_UpDir, _viewDir.xyz));
                float random = rand(_worldPos.xyz);
                //o.Varying_IrradianceColor.rgb = upDotV;

                //以下直接在顶点着色器计算了（地平线颜色，天空颜色）
                //颜色R
                float2 _irradianceMap_R_uv;
                _irradianceMap_R_uv.x = upDotV / max(_IrradianceMapR_maxAngleRange, 1.0e-04);
                _irradianceMap_R_uv.y = 0.5;
                //对ramp图进行采样
                float _irradianceMapR = _IrradianceMap.SampleLevel
                    (sampler_IrradianceMap, _irradianceMap_R_uv, 0.0).r;
                //o.Varying_IrradianceColor.rgb = _irradianceMapR;

                //这个值用于判断太阳在那一部分
                float sun_atten = 1- smoothstep(_sun_atten.x, _sun_atten.y, _UpDotSun);
                float _VDotSunDampingA = max(0, lerp(1, _VDotSun, _mainColorSunGatherFactor))*sun_atten;
                float _VDotSunDampingA_pow3 = _VDotSunDampingA * _VDotSunDampingA * _VDotSunDampingA;
                float3 _downPartColor = lerp(_downPartSkyColor, _downPartSunColor, _VDotSunDampingA_pow3);
                float3 _upPartColor = lerp(_upPartSkyColor, _upPartSunColor, _VDotSunDampingA_pow3);
                float3 _mainColor = lerp(_upPartColor, _downPartColor, _irradianceMapR);
                //月亮天空颜色
                float _VDotMoonDamping = max(0,  _VDotMoon);
                _VDotMoonDamping = pow(_VDotMoonDamping,2.2);
                _mainColor = lerp(_mainColor,_upMoonColor,_VDotMoonDamping);
                //o.Varying_IrradianceColor.rgb = _mainColor;

                // // _irradianceMapG 最左边是 0 度的，最右边是 _IrradianceMapG_maxAngleRange 0.3 *90°=27° 的，即只记录水平朝向的值，更高，更低的值都是 27° 的值。
                // //   如果 _IrradianceMapG_maxAngleRange 小，例如 0.01，则 1° 以上就没值了，表示 _sunAdditionPartColor (sky color) 只有水平地方有
                // //   如果 _IrradianceMapG_maxAngleRange 小，例如 1.0，则 90° 应该还有值，表示 _sunAdditionPartColor (sky color) 高处也有
                float2 _irradianceMap_G_uv;
                _irradianceMap_G_uv.x = upDotV / max(_IrradianceMapG_maxAngleRange, 1.0e-04);
                _irradianceMap_G_uv.y = 0.5;
                float _irradianceMapG = _IrradianceMap.SampleLevel
                    (sampler_IrradianceMap, _irradianceMap_G_uv, 0.0).g;

                float3 _sunAdditionPartColor = _irradianceMapG * _SunAdditionColor * _SunAdditionIntensity;
                // float _VDotSunFactor = smoothstep(0, 1, (_VDotSunRemap01Clamp-1)/0.7 + 1);
                // float _sunAdditionPartFactor = lerp(_VDotSunFactor, 1.0, _upFactor);
                float3 _additionPart = _sunAdditionPartColor * _VDotSunDampingA_pow3;

                //计算调用noise的uv
                //这个uv需要利用三面映射算法
                //float2 screenUV = _clippos.xy/_clippos.w;
                float2 uv = v.uv *_star_scale;//+float2(1,0)*random;

                // //调试用
                o.Varying_IrradianceColor.xyz = _additionPart + _mainColor;
                o.Varying_IrradianceColor.w = _VDotSunDampingA_pow3;
                o.Varying_ViewDirAndRandom.xyz = _viewDir;
                o.Varying_NoiseUV_large.xy = TRANSFORM_TEX(v.uv,_BaseColorMap);
                o.Varying_StarColorUVAndNoise_UV.xy = v.uv;
                o.Varying_StarColorUVAndNoise_UV.zw = TRANSFORM_TEX(v.uv,_NoiseMap);
                o.posWS = _worldPos;

                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float4 maskMap = _IrradianceMap.Sample(sampler_IrradianceMap,i.Varying_StarColorUVAndNoise_UV.xy);
                float3 baseColor = _BaseColorMap.Sample(sampler_BaseColorMap,i.Varying_NoiseUV_large.xy);
                float noise1 = _NoiseMap.Sample(sampler_NoiseMap,i.Varying_StarColorUVAndNoise_UV.zw).r;
                baseColor*=_star_color_intensity*_StarColor;

                float3 backgroundColor = _BackgroundColor;
                
                float alpha = maskMap.r*noise1;
                float3 finalColor = float3(baseColor+backgroundColor);
                //测试
                //finalColor = baseColor;
                //alpha = 1;


                
                return float4(finalColor.rgb,alpha);
                return maskMap.r;
            }
            ENDHLSL
        }
    }
}