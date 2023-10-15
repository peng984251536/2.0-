Shader "Unlit/GenshipSkyBoxShader"
{
    Properties
    {
        [NoScaleOffset]_IrradianceMap("_IrradianceMap", 2D) = "white" {}
        _NoiseMap("_NoiseMap", 2D) = "white" {}
    }
    
    HLSLINCLUDE
    
    //生成随机数
    float rand(float3 co)
    {
        return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
        
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
        ZWrite Off

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
            float3 _star_color;
            float _star_color_intensity;
            float3 _star_offset;
            float2 _star_mask;
            float _star_scale;
            
            // // -------------------------- */
            // // /* night 夜晚: star 属性 
            // float _starColorIntensity;
            // float _starIntensityLinearDamping;
            //
            // sampler2D _StarDotMap;
            // float4 _StarDotMap_ST;
            //
            // sampler2D _StarColorLut;
            // float4 _StarColorLut_ST;
            //
            // sampler2D _NoiseMap;
            // float4 _NoiseMap_ST;
            // float _NoiseSpeed;
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
                float4 Varying_ViewDirAndAngle1_n1 : TEXCOORD2;
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
                //
                float upDotV = abs(dot(_UpDir, _viewDir.xyz));
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
                float random = rand(_worldPos.xyz);
                //float2 screenUV = _clippos.xy/_clippos.w;
                float2 uv = v.uv *_star_scale;//+float2(1,0)*random;

                // //调试用
                o.Varying_IrradianceColor.xyz = _additionPart + _mainColor;
                o.Varying_IrradianceColor.w = _VDotSunDampingA_pow3;
                //o.Varying_IrradianceColor.rgb = _mainColor;
                o.posWS = _worldPos;

                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                //return float4(i.Varying_StarColorUVAndNoise_UV.xy,0.0,1);
                //return i.Varying_IrradianceColor.r;
                //return float4(i.Varying_IrradianceColor.rgb,1);

                //太阳渲染
                float3 _viewDir = normalize(i.posWS.xyz - _WorldSpaceCameraPos /*_WorldSpaceCameraPos*/);
                //这是关于视角向量 和 up 的角度
                float _VDotUp = dot(_viewDir, _UpDir);
                float _UpDotSun = dot(_UpDir, _sun_dir);
                float _UpDotMoon = dot(_UpDir, _moon_dir);
                //越向上或者越向下的天空盒，这个参数就越大,为了让pow的时候，越接近地平线值越小
                float _VDotUp_Multi999 = abs(_VDotUp) * _sun_disk_power_999;
                //这里是 太阳落下的光照
                float _VDotSun = dot(_sun_dir, _viewDir); //这个是产生太阳效果的原因
                //把这个参数映射到0.5-1
                float _VDotSunRemap01Clamp = abs(_VDotSun) * 0.5 + 0.5;
                //由于地平线的_VDotUp_Multi999 是 0，所以地平线会产生光环效果
                float sunDisk = pow(_VDotSunRemap01Clamp, _VDotUp_Multi999);
                sunDisk = min(1, sunDisk);
                float3 sun_Disk_color = _sun_color_intensity * _sun_color;
                float3 sun_Disk_mask = pow(i.Varying_IrradianceColor.w,2.5)*
                    dot(sunDisk, float3(1, 0.12, 0.03));
                //决定是否有太阳光
                float _sun_part_enable = 1;
                if (_UpDotSun <= 0)
                {
                    _sun_part_enable = 1 - smoothstep(_sun_atten.x, _sun_atten.y, _UpDotSun);
                }
                sun_Disk_mask *= _sun_part_enable;
                float3 finalColor = lerp(i.Varying_IrradianceColor.rgb,sun_Disk_color,sun_Disk_mask);
                //sun_Disk_color *= sun_Disk_mask;
                //return sunDisk;
                //return float4(sun_Disk_color,1);

                //星星-70
                float _StarMask = smoothstep(-0.1,0,_UpDotMoon);
                float3 random = rand(i.posWS.xyz);
                float3 samplerUV =(normalize(i.posWS.xyz))*_star_scale;
                float3 samplerNormal = normalize(_viewDir.xyz+_star_offset);
                float noiseMask = tex3DAsNormal(_NoiseMap,sampler_NoiseMap,
                    samplerUV.xy,samplerUV.yz,samplerUV.xz,samplerNormal);
                //float _noise = _NoiseMap.Sample(sampler_NoiseMap,i.Varying_StarColorUVAndNoise_UV.xy).r;
                _StarMask = _StarMask*smoothstep(_star_mask.x,_star_mask.x+_star_mask.y,noiseMask);
                float3 star_color = _star_color*_star_color_intensity;
                finalColor = lerp(finalColor,star_color,_StarMask);
                //return _StarMask;
                //return _noise;

                //月亮
                // float _VDotMoonClamp01 = clamp(dot(_moon_dir, _viewDir), 0, 1);
                // float _moon_disk = lerp(1.0, _VDotMoonClamp01, 1.0 / max(_moon_size * 0.1, 0.00001));
                // _moon_disk = smoothstep(0.9, 0.9 + _moon_bloom, _moon_disk);
                //
                // float _moon_disk_pow2 = _moon_disk * _moon_disk;
                // float _moon_disk_pow4 = _moon_disk_pow2 * _moon_disk_pow2;
                // float _moon_disk_pow6 = _moon_disk_pow4 * _moon_disk_pow2;
                //
                // float _moon_part_enable = 1;
                // if (_UpDotMoon <= 0)
                // {
                //     _moon_part_enable = 1 - smoothstep(_moon_atten.x, _moon_atten.y, _UpDotMoon);
                // }
                // float3 moon_Disk_color = _moon_part_enable * _moon_disk_pow6 * _moon_color*_moon_intensity;
                // //需要做一张噪点图模拟月亮表面
                // //return float4(moon_Disk_color, 1);

                
                
                //finalColor = i.Varying_IrradianceColor.rgb;
                return  float4(saturate(finalColor), 1);
            }
            ENDHLSL
        }
    }
}