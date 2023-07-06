//#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

float3 GetAddLight(float2 uv,float3 normal,float3 viewDir,float3 posWS)
{
    half3 colorAdd = half3(0, 0, 0);
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, posWS);
        //1.
        // float4 lightPositionWS = _AdditionalLightsPosition[lightIndex];
        // float3 lightVec = lightPositionWS - positionWS;
        // // 表面到光线的距离
        // float d = length(lightVec);
        // // 光的衰弱
        // float att = 1.0f / dot(0.1, float3(1.0f, d, d * d));
        //
        // colorAdd += light.color * att;

        //2.毫无根据，乱来的方法
        //colorAdd += IndirectColor * light.distanceAttenuation*30;

        //3.出处：           //  // https://zhuanlan.zhihu.com/p/368888374
        //  //range是光源的有效范围
        //  float4 lightPositionWS = _AdditionalLightsPosition[lightIndex];
        //  float3 lightPosition = lightPositionWS.xyz;
        //  //float range = lightPositionWS.w;//不是Matrix
        //  float3 lightVector = lightPosition - positionWS;
        //  //lightRangeSqr =  -1.0 * lightRangeSqr / 0.36;//http://www.kittehface.com/2020/05/light-universal-render-pipeline-to.html
        //  float range = 6;//搞了很久，没法搞到官方 urp 管线下的 lit range.......^@^&T^!!^*^!^!! 
        // float rangeSqr = range * range;
        //  float3 lightDir = normalize(lightVector);
        //  float distanceToLightSqr = dot(lightVector,lightVector);
        //  //距离衰减系数
        //  //float atten = _AdditionalLightsAttenuation[lightIndex];
        //  float atten = DistanceAtten(distanceToLightSqr,rangeSqr);//自定义方法
        //  //float atten = DistanceAttenuation(distanceToLightSqr,rangeSqr);//官方方法
        //  //高光项
        //  //half3 specular =  BlinnPhongSpecular(viewDir,normal,lightDir,property.shininess) * property.specularColor;
        //  //漫反射项
        //  //half3 diffuse = LambertDiffuse(normal,lightDir) * property.diffuseColor;
        //  colorAdd += IndirectColor*atten;


        //4.依赖light.distanceAttenuation，但好像没什么卵用
        // //    float3 lightVector =      lightPositionOrDirection.xyz - worldPos * lightPositionOrDirection.w;
        //     float3 lightDirection = normalize(lightVector);
        //     float diffuse = saturate(dot(N, lightDirection));
        //
        //     float rangeFade = dot(lightVector, lightVector) * light.distanceAttenuation;
        //     rangeFade = saturate(1.0 - rangeFade * rangeFade);
        //     rangeFade *= rangeFade;
        //
        //     float distanceSqr = max(dot(lightVector, lightVector), 0.00001);
        //     diffuse *= rangeFade / distanceSqr;
        //     colorAdd += IndirectColor*diffuse;

        //5.use BRDF Struct（暂时）
        BRDFData brdfData;
        BRDFData brdfDataClearCoat = (BRDFData)0;

        bool specularHighlightsOff = false;
        colorAdd += LightingPhysicallyBased(brdfData, brdfDataClearCoat,
                                            light,
                                            normal, viewDir,
                                            surfaceData.clearCoatMask, specularHighlightsOff);

        return colorAdd;
    }
}
