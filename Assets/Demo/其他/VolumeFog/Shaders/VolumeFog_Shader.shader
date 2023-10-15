Shader "URP/VolumeFog_Shader"
{
    Properties
    {
        //        _VolumeFogRT("MainTex",2D) = "while"{}
        _BaseColor("outline color",color) = (1,1,1,1)

        //        _SRef("Stencil Ref", Float) = 1
        //        [Enum(UnityEngine.Rendering.CompareFunction)] _SComp("Stencil Comp", Float) = 8
        //        [Enum(UnityEngine.Rendering.StencilOp)] _SOp("Stencil Op", Float) = 2
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    
    float4 _phaseParams;
    float4x4 _VPMatrix_invers;
    float2 _haltonVector2;
    float _haltonScale;
    // float _BilaterFilterFactor; //法线判定的插值
    // float2 _BlurRadius; //滤波的采样范围
    float4 _bilateralParams; //x:BlurRadius.x||y:BlurRadius.y||z:BilaterFilterFactor
    #define BlurRadiusX _bilateralParams.x
    #define BlurRadiusY _bilateralParams.y
    #define BilaterFilterFactor _bilateralParams.z
    #define DirectLightingStrength _bilateralParams.w
    

    struct a2v
    {
        uint vertexID :SV_VertexID;
    };

    struct v2f
    {
        float4 pos:SV_Position;
        float2 uv:TEXCOORD0;
    };

    v2f vert(a2v IN)
    {
        v2f o;
        o.pos = GetFullScreenTriangleVertexPosition(IN.vertexID);
        o.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
        return o;
    }

    // Returns (dstToBox, dstInsideBox). If ray misses box, dstInsideBox will be zero
    //根据包围盒的最大距离、最小距离、射线步近位置、射线步近的向量的倒数
    //计算出第一次接触的位置、到达第二次接触的距离
    float2 rayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 invRaydir)
    {
        // Adapted from: http://jcgt.org/published/0007/03/04/
        float3 t0 = (boundsMin - rayOrigin) * invRaydir;
        float3 t1 = (boundsMax - rayOrigin) * invRaydir;
        float3 tmin = min(t0, t1);
        float3 tmax = max(t0, t1);

        float dstA = max(max(tmin.x, tmin.y), tmin.z);
        float dstB = min(tmax.x, min(tmax.y, tmax.z));

        // CASE 1: ray intersects box from outside (0 <= dstA <= dstB)
        // dstA is dst to nearest intersection, dstB dst to far intersection

        // CASE 2: ray intersects box from inside (dstA < 0 < dstB)
        // dstA is the dst to intersection behind the ray, dstB is dst to forward intersection

        // CASE 3: ray misses box (dstA > dstB)

        float dstToBox = max(0, dstA);
        float dstInsideBox = max(0, dstB - dstToBox);
        return float2(dstToBox, dstInsideBox);
    }

    //重新映射函数
    float remap(float v, float minOld, float maxOld, float minNew, float maxNew)
    {
        return minNew + (v - minOld) * (maxNew - minNew) / (maxOld - minOld);
    }

    // Henyey-Greenstein
    float hg(float a, float g)
    {
        float g2 = g * g;
        return (1 - g2) / (4 * 3.1415 * pow(1 + g2 - 2 * g * (a), 1.5));
    }

    float phase(float a)
    {
        float blend = .5;
        float hgBlend = hg(a, _phaseParams.x) * (1 - blend) + hg(a, -_phaseParams.y) * blend;
        return _phaseParams.z + hgBlend * _phaseParams.w;
    }
    ENDHLSL

    Subshader
    {
        Pass
        {
            Tags
            {
                //"LightMode" = "VF_RayMarch"
                "RenderType" = "Opaque"// "Queue" = "Geometry"
            }

            Name "VF_RayMarch"
            //Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
            ZWrite Off
            ZTest Always


            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            TEXTURE3D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);
            TEXTURE3D(_DetailNoiseTex);
            SAMPLER(sampler_DetailNoiseTex);
            TEXTURE2D(_blueNoiseTex);
            SAMPLER(sampler_blueNoiseTex);
            TEXTURE2D(_shape2NoiseTex);
            SAMPLER(sampler_shape2NoiseTex);
            TEXTURE2D(_CameraTexture);
            SAMPLER(sampler_CameraTexture);
            TEXTURE2D_X(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            float4 _CameraDepthTexture_ST;
            //half4 _BaseColor;

            //shapeParams
            float4 _CameraTexture_TexelSize;
            float4 _blueNoiseTex_TexelSize;
            float3 _shapeScale;
            float3 _shapeOffset;
            float4 _shapeNoiseWeights;
            float _blueSize;
            //Params
            float3 _boundsMin;
            float3 _boundsMax;
            float _rayOffsetStrength;
            float _RayStepScale;
            float _RayStepNum;
            float _baseSpeed;
            float _smoothMin;
            float _smoothMax;
            float2 _noiseModelVal;

            //detailParams
            // Animation settings
            float3 _detailNoiseScale;
            float3 _detailOffset;
            float _detailSpeed;
            float2 _smoothVal;

            //shape2
            float3 _shape2Scale;
            float3 _shape2Offset;
            float _smoothMin2;
            float _smoothMax2;

            //lightMarchParams
            float4 _lightMarchParams;
            float _lightMarchStep;
            #define numStepsLight _lightMarchParams.x
            #define lightAbsorptionTowardSun _lightMarchParams.y
            #define darknessThreshold _lightMarchParams.z
            #define lightMarchScale _lightMarchParams.w

            //windSetting
            float3 _windDir;
            float3 _windSpeed;
            float _timeScale;
            


            //采样噪声贴图
            //采样信息可以影响到云密度
            float sampleDensity(float3 rayPos)
            {
                // Constants:
                const int mipLevel = 0;
                const float baseScale = 1 / 1000.0;
                const float offsetSpeed = 1 / 100.0;

                //todo-
                const float baseSpeed = 1;
                const float densityOffset = 1;

                // Calculate texture sample positions
                float time = _Time.y * _timeScale;
                float3 wind = _windDir*_windSpeed;
                float3 size = _boundsMax - _boundsMin;
                float3 boundsCentre = (_boundsMin + _boundsMax) * .5;
                float3 uvw = (size * .5 + rayPos) * baseScale;
                float3 shapeSamplePos = uvw * _shapeScale +
                    _shapeOffset * offsetSpeed*wind*time;

                // Calculate falloff at along x/z edges of the cloud container
                //设置远点到边缘的距离，点越远离50，边缘衰减越大
                //水平边缘做衰减
                const float containerEdgeFadeDst = 50;
                float dstFromEdgeX = min(containerEdgeFadeDst, min(rayPos.x - _boundsMin.x, _boundsMax.x - rayPos.x));
                float dstFromEdgeZ = min(containerEdgeFadeDst, min(rayPos.z - _boundsMin.z, _boundsMax.z - rayPos.z));
                float edgeWeight = min(dstFromEdgeZ, dstFromEdgeX) / containerEdgeFadeDst;
                //return edgeWeight;

                // Calculate height gradient from weather map
                //float2 weatherUV = (size.xz * .5 + (rayPos.xz-boundsCentre.xz)) / max(size.x,size.z);
                //float weatherMap = WeatherMap.SampleLevel(samplerWeatherMap, weatherUV, mipLevel).x;
                //高度方向上做衰减
                float gMin = .2;
                float gMax = .7;
                float heightPercent = (rayPos.y - _boundsMin.y) / size.y;
                float heightGradient = saturate(remap(heightPercent, 0.0, gMin, 0, 1)) * saturate(
                    remap(heightPercent, 1, gMax, 0, 1));
                //return heightGradient;
                //return edgeWeight;
                heightGradient = heightGradient * edgeWeight;
                //return heightGradient;

                // Calculate base shape density
                float4 shapeNoise = _NoiseTex.SampleLevel(sampler_NoiseTex, shapeSamplePos, mipLevel);
                shapeNoise = SAMPLE_TEXTURE3D(_NoiseTex, sampler_NoiseTex, shapeSamplePos).r;
                shapeNoise = smoothstep(_smoothMin, _smoothMax, shapeNoise);
                //return shapeNoise;
                //形状噪声（shape noise）的加权和,大概意思是控制噪声的比重
                //我觉得还不到smoothstep好用
                float baseShapeDensity = shapeNoise * heightGradient;
                //return baseShapeDensity;

                //云整体形状，防止重复度太高
                float2 shape2ScalePos = uvw.xz * _shape2Scale.xz +
                    _shape2Offset.xz * offsetSpeed*wind*time;
                float modelNoise = SAMPLE_TEXTURE2D(_shape2NoiseTex, sampler_shape2NoiseTex, shape2ScalePos).b;
                modelNoise = 1 - smoothstep(_smoothMin2, _smoothMax2, modelNoise);
                baseShapeDensity = modelNoise * baseShapeDensity;
                //return modelNoise;
                //return baseShapeDensity;
                // float3 detailSamplePos = uvw * _detailNoiseScale + _detailOffset * offsetSpeed;
                // float detailNoise = 1-SAMPLE_TEXTURE3D(_DetailNoiseTex,sampler_DetailNoiseTex,detailSamplePos).r;
                // float detailFBM = smoothstep(_smoothVal.x,_smoothVal.y,detailNoise);
                //     return detailFBM;

                // Save sampling from detail tex if shape density <= 0
                if (baseShapeDensity > 0)
                {
                    // Sample detail noise
                    float3 detailSamplePos = uvw * _detailNoiseScale +
                        _detailOffset * offsetSpeed*wind*time;
                    float detailNoise = SAMPLE_TEXTURE3D(_DetailNoiseTex, sampler_DetailNoiseTex, detailSamplePos).r;
                    float detailFBM = smoothstep(_smoothVal.x, _smoothVal.y, detailNoise);
                    //return detailNoise;
                    //return detailFBM;

                    // Subtract detail noise from base shape (weighted by inverse density so that edges get eroded more than centre)
                    float oneMinusShape = 1 - baseShapeDensity;
                    //float detailErodeWeight = oneMinusShape * oneMinusShape * oneMinusShape;
                    //float cloudDensity = baseShapeDensity - (1 - detailFBM)*oneMinusShape;

                    float cloudDensity = baseShapeDensity - oneMinusShape * detailFBM;
                    cloudDensity = lerp(cloudDensity, 1 - detailFBM, 0.5f);

                    return cloudDensity;
                }
                return baseShapeDensity;
            }
            

            half4 frag(v2f i) : SV_Target
            {
                //float4 tex = SAMPLE_TEXTURE2D(_VolumeFogRT, sampler_VolumeFogRT, i.uv);
                float2 screenUV = i.uv;
                float3 baseColor = SAMPLE_TEXTURE2D(_CameraTexture,
                                                    sampler_CameraTexture, screenUV).rgb;
                float4 viewPos = mul(_VPMatrix_invers, float4(screenUV*2-1, 1, 1));
                viewPos /= viewPos.w;
                float3 viewDir = normalize(viewPos - _WorldSpaceCameraPos.xyz);
                //return viewPos.x;
                //return float4(viewPos.xy,0,1);
                //return float4(viewDir.xyz,1);


                // Depth and cloud container intersection info:
                float nonlin_depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture,
                                                        sampler_CameraDepthTexture, screenUV).r;
                float depth = LinearEyeDepth(nonlin_depth, _ZBufferParams);
                float2 rayToContainerInfo = rayBoxDst(_boundsMin, _boundsMax,
                                                      _WorldSpaceCameraPos.xyz, 1 / viewDir);
                float dstToBox = rayToContainerInfo.x;
                float dstInsideBox = rayToContainerInfo.y;
                dstInsideBox = min(dstInsideBox,depth);
                dstToBox =  min(dstToBox,depth);
                float jitter_Scale = dstToBox/(dstToBox+dstInsideBox) ;

                float3 rayPos = _WorldSpaceCameraPos.xyz;
                //return dstToBox - _timeScale;
                float3 entryPoint = rayPos + normalize(viewDir) * dstToBox; //开始位置

                //扰动
                //之前的扰动是错误的
                float2 jitter_uv = float2((screenUV + _haltonVector2*_haltonScale) *
                    _CameraTexture_TexelSize.zw/_blueSize / _blueNoiseTex_TexelSize.zw);
                float2 randomOffset = SAMPLE_TEXTURE2D(_blueNoiseTex, sampler_blueNoiseTex,
                    jitter_uv).rg*2-1;
                //return float4(randomOffset.r*0.5+0.5,0,0,0);
                randomOffset = _rayOffsetStrength * (randomOffset.r);
                // float3 testColor = randomOffset;
                // return float4(testColor,0) ;
                float dstTravelled = randomOffset*_RayStepScale;
                //float dstLimit = min(i.vertex.w - dstToBox, dstInsideBox); //步近最远距离
                float dstLimit = max(3, dstInsideBox);


                // March through volume:
                float transmittance = 1;
                float3 lightEnergy = 0;
                float stepSize1 = _RayStepScale;

                // Phase function makes clouds brighter around sun
                //控制高光
                float cosAngle = dot(viewDir, _MainLightPosition.xyz);
                float cosAngle2 = dot(-viewDir, _MainLightPosition.xyz);
                cosAngle = min(cosAngle, cosAngle2);
                float phaseVal = phase(cosAngle);
                //return phaseVal;


                //我的，计算与正方体交点
                //entryPoint = Point(i.normalWS, i.viewDir, _WorldSpaceCameraPos.xyz);
                //return (dstTravelled-dstLimit);
                //  for (int j=0;j<1;j++)
                //  {
                //      dstTravelled += stepSize;
                //  }
                //return (dstToBox) / _timeScale;
                //return dstLimit/_timeScale;
                //return i.vertex.w/_timeScale;
                //return (i.vertex.w - dstToBox)/_timeScale;
                //return dstInsideBox/_timeScale;
                //return (dstTravelled-dstLimit)+_baseSpeed;
                //stepSize = dstLimit/stepSize;

                //光线衰减测试
                // float lightTransmittance =
                //     lightmarch(entryPoint + i.viewDir * (dstTravelled));
                // return lightTransmittance;
                // rayPos = entryPoint + viewDir * (dstTravelled);
                // float density = sampleDensity(rayPos);
                // return density;
                //return float4(entryPoint, 1);


                [unroll(20)]
                for (int n = 0; dstLimit > dstTravelled; n++)
                {
                    if (n >= 20)
                        break;

                    rayPos = entryPoint + viewDir * (dstTravelled);
                    //return float4(entryPoint, 1);
                    float density = sampleDensity(rayPos);
                    //return density;

                    if (density > 0)
                    {
                        //光线函数
                        //return position.y;
                        float3 dirToLight = normalize(_MainLightPosition.xyz);
                        float dstInsideBox = rayBoxDst(_boundsMin, _boundsMax,
                                                       rayPos, 1 / dirToLight).y;
                        numStepsLight = min(numStepsLight, 4);
                        float num = (numStepsLight + 1) * numStepsLight * 0.5;
                        float stepSizeOne = dstInsideBox / num;
                        //stepSizeOne = _lightMarchStep;
                        float stepSize2 = stepSizeOne;
                        float totalDensity = 0;
                        float3 lightPos = rayPos;
                        for (int step = 0; step < numStepsLight; step ++)
                        {
                            lightPos += dirToLight * stepSize2;
                            totalDensity += max(0, sampleDensity(lightPos) * stepSize2);
                            stepSize2 += stepSizeOne;
                        }
                        float lightTransmittance = exp(-totalDensity * lightAbsorptionTowardSun);
                        //return transmittance;
                        //return darknessThreshold + transmittance * (1 - darknessThreshold);
                        lightEnergy += density * stepSize2 * transmittance * lightTransmittance * phaseVal;

                        //云密度计算
                        //lightEnergy += density * stepSize * transmittance * lightTransmittance * phaseVal;
                        //transmittance *= exp(-density * stepSize * lightAbsorptionThroughCloud);
                        transmittance *= exp(-density * stepSize2);


                        // Exit early if T is close to zero as further samples won't affect the result much
                        if (transmittance < 0.01)
                        {
                            break;
                        }
                    }
                    dstTravelled += stepSize1;
                }
                lightEnergy = lightEnergy * lightMarchScale * _MainLightColor.rgb;


                //环境光
                half3 ambient_GI = SampleSH(float3(0, 1, 0)); //环境光
                ambient_GI = _GlossyEnvironmentColor ;
                float3 ambientLight = ambient_GI * (1 - transmittance) * darknessThreshold;
                //ambientLight = ambientLight * ((Luminance(lightEnergy)));
                //return float4(ambient_GI,1-transmittance);
                //return float4(ambientLight,1);


                float3 finalColor = lerp(lightEnergy, baseColor.rgb, transmittance); //
                //return lightEnergy * lightMarchScale;
                //return transmittance;
                //return transmittance* + lightEnergy * lightMarchScale;
                //transmittance = smoothstep(0, 1, transmittance);
                //return float4(0, 0, 0, 1 - transmittance);
                //return float4(ambient_GI, 1);
                //return float4(transmittance, transmittance, transmittance, transmittance);
                return float4(finalColor + ambientLight, transmittance);
                //return float4(transmittance.rgb, 0.9);
            }
            ENDHLSL
        }
        
        // 2 - Horizontal Blur
        Pass
        {
            //双边滤波_水平
            Name "Horizontal_BilaterFilter"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag_bilateralnormal
            #pragma multi_compile_local _SOURCE_DEPTH _SOURCE_DEPTH_NORMALS _SOURCE_GBUFFER
            #pragma multi_compile_local _RECONSTRUCT_NORMAL_LOW _RECONSTRUCT_NORMAL_MEDIUM _RECONSTRUCT_NORMAL_HIGH
            #pragma multi_compile_local _ORTHOGRAPHIC

            // TEXTURE2D(_MainTex);
            // SAMPLER(sampler_MainTex);
            // float2 _MainTex_TexelSize;

            TEXTURE2D_X(_VolumeFogRT);
            SAMPLER(sampler_VolumeFogRT);
            float4 _VolumeFogRT_TexelSize;
            

            float4 frag_bilateralnormal(v2f i) : SV_Target
            {
                float2 delta = _VolumeFogRT_TexelSize.xy * _bilateralParams.xy;

                float2 uv = i.uv;
                // return float4(i.uv,0,1);
                
                float2 uv0a = i.uv - float2(1.0, 0) * delta;
                float2 uv0b = i.uv + float2(1.0, 0) * delta;
                float2 uv1a = i.uv - float2(2.0, 0) * delta;
                float2 uv1b = i.uv + float2(2.0, 0) * delta;

                // float3 normal0 = GetNormal(uv);
                // float3 normal1 = GetNormal(uv0a);
                // float3 normal2 = GetNormal(uv0b);
                // float3 normal3 = GetNormal(uv1a);
                // float3 normal4 = GetNormal(uv1b);

                float4 col = SAMPLE_TEXTURE2D(_VolumeFogRT, sampler_VolumeFogRT, uv);
                float4 col0a = SAMPLE_TEXTURE2D(_VolumeFogRT, sampler_VolumeFogRT, uv0a);
                float4 col0b = SAMPLE_TEXTURE2D(_VolumeFogRT, sampler_VolumeFogRT, uv0b);
                float4 col1a = SAMPLE_TEXTURE2D(_VolumeFogRT, sampler_VolumeFogRT, uv1a);
                float4 col1b = SAMPLE_TEXTURE2D(_VolumeFogRT, sampler_VolumeFogRT, uv1b);

                half w = 0.4026;
                half w0a = 0.0545;
                half w0b =  0.0545;
                half w1a =  0.2442;
                half w1b =  0.2442;


                half4 result = w * col;
                result += w0a * col0a;
                result += w0b * col0b;
                result += w1a * col1a;
                result += w1b * col1b;

                result = result / (w + w0a + w0b + w1a + w1b);
                return float4(result.rgb, result.a);
            }
            ENDHLSL
        }

        // 2 - Vertical Blur
        Pass
        {
            Name "Vertical_BilaterFilter"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag_bilateralnormal
            #pragma multi_compile_local _SOURCE_DEPTH _SOURCE_DEPTH_NORMALS _SOURCE_GBUFFER
            #pragma multi_compile_local _RECONSTRUCT_NORMAL_LOW _RECONSTRUCT_NORMAL_MEDIUM _RECONSTRUCT_NORMAL_HIGH
            #pragma multi_compile_local _ _ORTHOGRAPHIC

            // TEXTURE2D(_MainTex);
            // SAMPLER(sampler_MainTex);
            // float2 _MainTex_TexelSize;

            TEXTURE2D(_VolumeFogRT);
            SAMPLER(sampler_VolumeFogRT);
            float2 _VolumeFogRT_TexelSize;
            

            float4 frag_bilateralnormal(v2f i) : SV_Target
            {
                float2 delta = _VolumeFogRT_TexelSize.xy * _bilateralParams.xy;

                float2 uv = i.uv;
                float2 uv0a = i.uv - float2(0, 1.0) * delta;
                float2 uv0b = i.uv + float2(0, 1.0) * delta;
                float2 uv1a = i.uv - float2(0, 2.0) * delta;
                float2 uv1b = i.uv + float2(0, 2.0) * delta;

                // float3 normal0 = GetNormal(uv);
                // float3 normal1 = GetNormal(uv0a);
                // float3 normal2 = GetNormal(uv0b);
                // float3 normal3 = GetNormal(uv1a);
                // float3 normal4 = GetNormal(uv1b);

                float4 col = SAMPLE_TEXTURE2D(_VolumeFogRT, sampler_VolumeFogRT, uv);
                float4 col0a = SAMPLE_TEXTURE2D(_VolumeFogRT, sampler_VolumeFogRT, uv0a);
                float4 col0b = SAMPLE_TEXTURE2D(_VolumeFogRT, sampler_VolumeFogRT, uv0b);
                float4 col1a = SAMPLE_TEXTURE2D(_VolumeFogRT, sampler_VolumeFogRT, uv1a);
                float4 col1b = SAMPLE_TEXTURE2D(_VolumeFogRT, sampler_VolumeFogRT, uv1b);
                
                half w = 0.4026;
                half w0a = 0.0545;
                half w0b =  0.0545;
                half w1a =  0.2442;
                half w1b =  0.2442;


                half4 result = w * col;
                result += w0a * col0a;
                result += w0b * col0b;
                result += w1a * col1a;
                result += w1b * col1b;

                result = result / (w + w0a + w0b + w1a + w1b);
                return float4(result.rgb, result.a);
            }
            ENDHLSL
        }

        //pass 3
        Pass
        {
            Name "VF_FinalBlur"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment FinalFrag

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

            TEXTURE2D(_VolumeFogRT);
            SAMPLER(sampler_VolumeFogRT);
            TEXTURE2D(_CameraTexture);
            SAMPLER(sampler_CameraTexture);
            
            float4 FinalFrag(v2f i) : SV_Target
            {
                float2 uv = i.uv;

                float4 camColor = SAMPLE_TEXTURE2D(_CameraTexture, sampler_CameraTexture, uv);
                float4 volumeColor = SAMPLE_TEXTURE2D(_VolumeFogRT, sampler_VolumeFogRT, uv);
                
                //return ao;
                float4 finalCol = camColor;
                //finalCol = float4(0.2,1,0.2,1)*camColor;
                finalCol.rgb = lerp( volumeColor,finalCol.rgb, volumeColor.a);
                return finalCol;
            }
            ENDHLSL
        }
        
        //pass 4
        //VF_temporal
        Pass
        {
            Name "VF_temporal"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment TemporalFrag

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "VFTemporal.hlsl"
            
            // TEXTURE2D(_CameraTexture);
            // SAMPLER(sampler_CameraTexture);
            
            float4 TemporalFrag(v2f i) : SV_Target
            {
                float2 uv = i.uv;
                
                
                float4 finalCol = temporal(uv);
                return finalCol;
            }
            ENDHLSL
        }
    }
}