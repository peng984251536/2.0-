Shader "URP/VolumeFog_Shader"
{
    Properties
    {
        //        _MainTex("MainTex",2D) = "while"{}
        _BaseColor("outline color",color) = (1,1,1,1)

        //        _SRef("Stencil Ref", Float) = 1
        //        [Enum(UnityEngine.Rendering.CompareFunction)] _SComp("Stencil Comp", Float) = 8
        //        [Enum(UnityEngine.Rendering.StencilOp)] _SOp("Stencil Op", Float) = 2
    }

    HLSLINCLUDE
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
    ENDHLSL

    Subshader
    {
        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward" "RenderType" = "Opaque" "Queue" = "Geometry"
            }

            //Blend SrcAlpha OneMinusSrcAlpha
            ZTest On
            ZWrite Off
            ZTest Always
            Cull Front

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

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex: POSITION;
                float3 normal:NORMAL;
                float2 uv :TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex: SV_POSITION;
                float2 uv:TEXCOORD0;
                float3 viewDir:TEXCOORD1;
                float3 posWS:TEXCOORD2;
                float3 normalWS:TEXCOORD3;
            };

            TEXTURE3D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);
            TEXTURE3D(_DetailNoiseTex);
            SAMPLER(sampler_DetailNoiseTex);
            TEXTURE2D(_blueNoiseTex);
            SAMPLER(sampler_blueNoiseTex);
            TEXTURE2D(_shape2NoiseTex);
            SAMPLER(sampler_shape2NoiseTex);
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D_X(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            float4 _CameraDepthTexture_ST;
            //half4 _BaseColor;

            //shapeParams
            float3 _shapeScale;
            float3 _shapeOffset;
            float4 _shapeNoiseWeights;
            //Params
            float3 _boundsMin;
            float3 _boundsMax;
            float _rayOffsetStrength;
            float _timeScale;
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
            #define numStepsLight _lightMarchParams.x
            #define lightAbsorptionTowardSun _lightMarchParams.y
            #define darknessThreshold _lightMarchParams.z
            #define lightMarchScale _lightMarchParams.w


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
                float time = _Time.x * _timeScale;
                float3 size = _boundsMax - _boundsMin;
                float3 boundsCentre = (_boundsMin + _boundsMax) * .5;
                float3 uvw = (size * .5 + rayPos) * baseScale;
                float3 shapeSamplePos = uvw + _shapeOffset * offsetSpeed +
                    float3(time, time * 0.1, time * 0.2) *
                    baseSpeed;
                shapeSamplePos = uvw * _shapeScale + _shapeOffset * offsetSpeed;

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
                //return ;
                //形状噪声（shape noise）的加权和,大概意思是控制噪声的比重
                //我觉得还不到smoothstep好用
                float baseShapeDensity = shapeNoise * heightGradient;
                //return baseShapeDensity;

                //云整体形状，防止重复度太高
                float2 shape2ScalePos = uvw.xz * _shape2Scale.xz + _shape2Offset.xz * offsetSpeed;
                float modelNoise = SAMPLE_TEXTURE2D(_shape2NoiseTex, sampler_shape2NoiseTex, shape2ScalePos).b;
                modelNoise = 1-smoothstep(_smoothMin2, _smoothMax2, modelNoise);
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
                    float3 detailSamplePos = uvw * _detailNoiseScale + _detailOffset * offsetSpeed;
                    //+ float3(time * .4, -time, time * 0.1) * _detailSpeed;
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

            // Calculate proportion of light that reaches the given point from the lightsource
            //光线衰减函数
            float lightmarch(float3 position)
            {
                float3 dirToLight = normalize(_MainLightPosition.xyz);
                float dstInsideBox = rayBoxDst(_boundsMin, _boundsMax, position, 1 / dirToLight).y;

                float stepSize = dstInsideBox / numStepsLight;
                float totalDensity = 0;
                numStepsLight = min(numStepsLight, 10);

                //[unroll(20)]
                for (int step = 0; step < numStepsLight; step ++)
                {
                    position += dirToLight * stepSize;
                    totalDensity += max(0, sampleDensity(position) * stepSize);
                }

                float transmittance = exp(-totalDensity * lightAbsorptionTowardSun);
                return darknessThreshold + transmittance * (1 - darknessThreshold);
            }

            v2f vert(appdata v)
            {
                v2f o;
                //v.vertex.xyz += _Width * normalize(v.vertex.xyz);

                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.posWS = TransformObjectToWorld(v.vertex.xyz);
                o.viewDir = normalize(o.posWS.xyz - _WorldSpaceCameraPos.xyz);
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                //float4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float2 screenUV = (i.vertex.xy / _ScreenParams.xy);
                float3 baseColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture,
                                                    sampler_CameraOpaqueTexture, screenUV).r;
                i.viewDir = normalize(i.posWS - _WorldSpaceCameraPos.xyz);
                //return float4( i.viewDir,1);


                // Depth and cloud container intersection info:
                float nonlin_depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture,
                                                        sampler_CameraDepthTexture, screenUV).r;
                float depth = LinearEyeDepth(nonlin_depth, _ProjectionParams);
                float2 rayToContainerInfo = rayBoxDst(_boundsMin, _boundsMax,
                                                      _WorldSpaceCameraPos.xyz, 1 / i.viewDir);
                float depth2 = (i.vertex.z + 1) * 0.5;
                float dstToBox = rayToContainerInfo.x;
                float dstInsideBox = rayToContainerInfo.y;


                // 
                float randomOffset = SAMPLE_TEXTURE2D(_blueNoiseTex, sampler_blueNoiseTex, screenUV).r;
                randomOffset = _rayOffsetStrength * (randomOffset * 0.7 + 0.3);
                float dstTravelled = randomOffset;
                float dstLimit = min(i.vertex.w - dstToBox, dstInsideBox); //步近最远距离
                dstLimit = max(1,dstInsideBox) ;
                float3 rayPos = _WorldSpaceCameraPos.xyz;
                float3 entryPoint = rayPos + normalize(i.viewDir) * dstToBox; //开始位置


                // March through volume:
                float transmittance = 1;
                float lightEnergy = 0;
                float stepSize = _timeScale;


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


                [unroll(100)]
                for (int n = 0; dstLimit > dstTravelled; n++)
                {
                    // if(dstLimit<((dstTravelled)))
                    //     break;

                    rayPos = entryPoint + i.viewDir * (dstTravelled);
                    //return float4(entryPoint, 1);
                    float density = sampleDensity(rayPos);
                    //return density;

                    if (density > 0)
                    {
                        //float lightTransmittance = lightmarch(rayPos);
                        //lightEnergy += lightTransmittance;
                        //lightEnergy += density * stepSize * transmittance * lightTransmittance * phaseVal;
                        //transmittance *= exp(-density * stepSize * lightAbsorptionThroughCloud);
                        transmittance *= exp(-density * stepSize);


                        // Exit early if T is close to zero as further samples won't affect the result much
                        if (transmittance < 0.01)
                        {
                            break;
                        }
                    }
                    dstTravelled += stepSize;
                }

                return transmittance;
                return transmittance + lightEnergy * lightMarchScale;
                //transmittance = smoothstep(0, 1, transmittance);
                //return float4(0, 0, 0, 1 - transmittance);
                return float4(lerp(0, baseColor.rgb, transmittance), transmittance);
                //return float4(transmittance.rgb, 0.9);
            }
            ENDHLSL
        }
    }
}