Shader "Unlit/GeoGrassShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _GroundColor ("GroundColor", Color) = (1,1,1,1)
        [HDR]_GrassColor ("GrassColor", Color) = (1,1,1,1)
        _GrassWidth ("GrassWidth", float) = 0.2
        _GrassHight ("GrassHight", float) = 1
        _GrassHightRandom ("GrassHightRandom", Range(0,1)) = 0.5
        _GrassMove ("GrassMove", float) = 0.2
        _GrassRotationRandom("GrassRotationRandom",Range(0,1)) = 0.2
        _GrassRotationRandom2("GrassRotationRandom2",Range(0,1)) = 0.2
        _GrassTex ("GrassTex", 2D) = "white" {} //草的颜色贴图

        _NoiseMap("WaveNoiseMap", 2D) = "white" {}
        _WindDirAndStrength("WindDirAndStrength",Vector) = (1,1,0,2)
        _WindNoiseStrength("WindNoiseStrength",float) = 10

        //曲面细分
        _MyEdgeTess("MyEdgeTess",float) = 3.0
        _MyInsideTess("MyInsideTess",float) = 3.0

        //曲面率
        _BladeForward("BladeForward",float) = 0.5
        _BladeCurve("BladeCurve",float) = 2

        //草的交互
        _Radius ("Radius",float) = 2
        _Strength ("Strength",float) = 2
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Cull Off
        //ZWrite on

        Pass
        {
            Name "GroundPass"
            Tags
            {
                //URP管线只允许一个pass
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma multi_compile_fwdbase
            #pragma vertex vert
            #pragma fragment frag

            // make fog work
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            //#include <Lighting.cginc>

            float4 _GroundColor;
            float4 _GrassColor;
            float _GrassWidth;
            float _GrassHight;
            float _GrassRotationRandom;
            float _GrassHightRandom;
            TEXTURE2D(_MainTex); //内部会声明一个 texture2D    的属性
            SAMPLER(sampler_MainTex); //内部会声明一个 SamplerState 的属性

            struct appdata
            {
                float4 pos : POSITION;
                float4 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float3 tangent : TANGENT;
                float4 color :COLOR;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 color :TEXCOORD2;
                float3 tangent : TEXCOORD3;
            };

            //顶点着色器
            //直接将从网格得到的数据传给传入几何着色器的结构体 v2g
            v2f vert(appdata v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.pos);
                o.uv = v.uv;
                o.normal = TransformObjectToWorldNormal(v.normal);
                o.tangent = TransformObjectToWorldDir(v.tangent);
                o.color = v.color;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                return float4(_GroundColor.xyz, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "GrassPass"
            Tags
            {
                //URP管线只允许一个pass
                "LightMode" = "SRPDefaultUnlit"
            }

            HLSLPROGRAM
            #pragma target 4.0
            #pragma multi_compile_fwdbase

            #pragma vertex vert
            #pragma fragment frag

            #pragma geometry geom

            #pragma hull HS
            #pragma domain DS

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

            #define BLANDE_SEGMENTS 3

            // make fog work
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            float4 _GroundColor;
            float4 _GrassColor;
            float _GrassWidth;
            float _GrassHight;
            float _GrassMove;
            float _GrassRotationRandom;
            float _GrassRotationRandom2;
            float _GrassHightRandom;
            float4 _MainTex_ST;
            float4 _GrassTex_ST;
            float4 _NoiseMap_ST;
            float _MyEdgeTess;
            float _MyInsideTess;
            float4 _WindDirAndStrength;
            float _WindNoiseStrength;
            float _BladeForward;
            float _BladeCurve;
            float4 _PositionMoving;
            float _Radius;
            float _Strength;
            TEXTURE2D(_MainTex); //内部会声明一个 texture2D    的属性
            SAMPLER(sampler_MainTex); //内部会声明一个 SamplerState 的属性
            TEXTURE2D(_GrassTex);
            SAMPLER(sampler_GrassTex);
            TEXTURE2D(_NoiseMap);
            SAMPLER(sampler_NoiseMap);

            struct appdata
            {
                float4 pos : POSITION;
                float4 uv : TEXCOORD0;
                float4 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 color :COLOR;
            };

            struct vertOut
            {
                float4 uv : TEXCOORD0;
                float4 pos : POSITION;
                float3 normal : TEXCOORD1;
                float4 tangent : TEXCOORD2;
                float4 color :TEXCOORD3;
            };

            struct g2f
            {
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 color :TEXCOORD2;
                float4 tangent : TEXCOORD3;
                float3 posWS : TEXCOORD4;
            };

            //有些硬件不支持曲面细分着色器，定义了该宏就能够在不支持的硬件上不会变粉，也不会报错
            #ifdef UNITY_CAN_COMPILE_TESSELLATION


            #endif

            //记录每条边的细分因子
            struct PatchTess
            {
                float EdgeTess[3]:SV_TessFactor;
                float InsideTess:SV_InsideTessFactor;
            };

            //Hull shader
            PatchTess ConstantHS(InputPatch<vertOut, 3> patch, uint patchID:SV_PrimitiveID)
            {
                PatchTess pt;
                pt.EdgeTess[0] = _MyEdgeTess;
                pt.EdgeTess[1] = _MyEdgeTess;
                pt.EdgeTess[2] = _MyEdgeTess;
                pt.InsideTess = _MyInsideTess;
                return pt;
            }

            struct HullOut
            {
                float4 uv : TEXCOORD0;
                float4 pos : POSITION;
                float3 normal : TEXCOORD1;
                float4 tangent : TEXCOORD2;
                float4 color :TEXCOORD3;
            };

            [domain("tri")] //拓扑的类型
            [partitioning("integer")] //曲面细分的拆分模式，还有 fraction模式

            //triangle_cw 顶点顺时针为正面，triangle_ccw 顶点逆时针为正面，line 只针对line的细分
            [outputtopology("triangle_cw")]

            //control point 的数目，同时也是 hull shander的执行次数。
            [outputcontrolpoints(3)]
            //让系统执行 ConstantHS 函数
            [patchconstantfunc("ConstantHS")]

            //硬件最大的细分因子
            [maxtessfactor(64.0f)]

            HullOut HS(InputPatch<vertOut, 3> p, uint i:SV_OutputControlPointID)
            {
                HullOut hout;
                hout.pos = p[i].pos;
                hout.uv = p[i].uv;
                hout.normal = p[i].normal;
                hout.tangent = p[i].tangent;
                hout.color = p[i].color;
                return hout;
            }

            struct DomainOut
            {
                float4 uv : TEXCOORD0;
                float4 pos : POSITION;
                float3 normal : TEXCOORD1;
                float4 tangent : TEXCOORD2;
                float4 color :TEXCOORD3;
            };

            [domain("tri")]
            vertOut DS(PatchTess patchTess, float3 baryCoords:SV_DomainLocation,
                       const OutputPatch<HullOut, 3> triangles)
            {
                vertOut dout;
                //搞不懂的重心空间切换
                float3 p = triangles[0].pos * baryCoords.x +
                    triangles[1].pos * baryCoords.y +
                    triangles[2].pos * baryCoords.z;

                dout.pos = float4(p, 1);
                dout.uv = triangles[0].uv * baryCoords.x +
                    triangles[1].uv * baryCoords.y +
                    triangles[2].uv * baryCoords.z;
                dout.normal = triangles[0].normal * baryCoords.x +
                    triangles[1].normal * baryCoords.y +
                    triangles[2].normal * baryCoords.z;
                dout.tangent = triangles[0].tangent * baryCoords.x +
                    triangles[1].tangent * baryCoords.y +
                    triangles[2].tangent * baryCoords.z;
                dout.color = triangles[0].color * baryCoords.x +
                    triangles[1].color * baryCoords.y +
                    triangles[2].color * baryCoords.z;

                return dout;
            }


            //生成随机数
            float rand(float3 co)
            {
                return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
            }

            //旋转矩阵
            float4x4 AngleAxis3x3(float angle, float3 axis)
            {
                float c, s;
                sincos(angle, s, c);

                float t = 1 - c;
                float x = axis.x;
                float y = axis.y;
                float z = axis.z;

                return float4x4(
                    t * x * x + c, t * x * y - s * z, t * x * z + s * y, 0,
                    t * x * y + s * z, t * y * y + c, t * y * z - s * x, 0,
                    t * x * z - s * y, t * y * z + s * x, t * z * z + c, 0,
                    0, 0, 0, 1
                );
            }


            //顶点着色器
            //直接将从网格得到的数据传给传入几何着色器的结构体 v2g
            vertOut vert(appdata v)
            {
                vertOut o;
                o.pos = float4(v.pos.xyz, 1);
                o.uv.xy = TRANSFORM_TEX(v.uv.xy, _MainTex);
                o.normal = v.normal;
                o.tangent = v.tangent;
                o.color = v.color;
                return o;
            }

            ///根据风力，计算顶点的世界坐标偏移
            ///positionWS - 顶点的世界坐标
            ///grassUpWS - 草的生长方向
            ///windDir - 是风的方向，应该为单位向量
            ///windStrength - 风力强度,范围(0~1)
            ///vertexLocalHeight - 顶点在草面片空间中的高度
            float3 applyWind(float3 positionWS, float3 grassUpWS, float3 windDir, float windStrength,
                             float vertexLocalHeight)
            {
                //根据风力，计算草弯曲角度，从0到90度
                float rad = windStrength * PI * 0.9 / 2;


                //得到wind与grassUpWS的正交向量
                windDir = normalize(windDir - dot(windDir, grassUpWS) * grassUpWS);

                float x, y; //弯曲后,x为单位球在wind方向计量，y为grassUp方向计量
                sincos(rad, x, y);

                //offset表示grassUpWS这个位置的顶点，在风力作用下，会偏移到windedPos位置
                float3 windedPos = x * windDir + y * grassUpWS;

                //加上世界偏移
                return positionWS + (windedPos - grassUpWS) * vertexLocalHeight;
            }

            //获取 交给 光栅化的顶点
            g2f GetVertex(float4 pos, float3 normal, float4 uv, float4 color, float3 windDir, float windStrength)
            {
                g2f output;

                float3 posWS = TransformObjectToWorld(pos.xyz);
                float3 normalWS = TransformObjectToWorldNormal(normal);

                posWS = applyWind(posWS, normalWS,
                                  windDir, windStrength, pos.y);

                output.pos = TransformWorldToHClip(posWS);
                output.posWS = posWS;
                output.normalWS = normalWS;
                output.uv = uv;
                output.uv.zw = TRANSFORM_TEX(uv.zw, _GrassTex);
                output.color = color;
                output.tangent = 1;

                return output;
            }

            //获取 交给 光栅化的顶点
            float4x4 GetTangentToLocal(float4 tangent, float3 normal)
            {
                float3 binormal = cross(normal, tangent) * tangent.w;

                float4x4 m = float4x4(
                    tangent.x, binormal.x, normal.x, 0,
                    tangent.y, binormal.y, normal.y, 0,
                    tangent.z, binormal.z, normal.z, 0,
                    0, 0, 0, 1
                );

                return m;
            }

            //获取 交给 光栅化的顶点
            float4x4 GetMoveMaterial(float x, float y, float z)
            {
                float4x4 m = float4x4(
                    1, 0, 0, x,
                    0, 1, 0, y,
                    0, 0, 1, z,
                    0, 0, 0, 1
                );

                return m;
            }

            //几何着色器
            [maxvertexcount(BLANDE_SEGMENTS*2+1)]
            void geom(triangle vertOut IN[3]:SV_POSITION, inout TriangleStream<g2f> triangle_stream)
            {
                g2f o;

                o.color = _GrassColor;
                float4 pos = (IN[0].pos + IN[1].pos + IN[2].pos) / 3;
                float4x4 tangentToLocal = GetTangentToLocal(
                    (IN[0].tangent + IN[1].tangent + IN[2].tangent) / 3,
                    (IN[0].normal + IN[1].normal + IN[2].normal) / 3);

                float ramdom = rand(pos);

                //弯曲（curvature）
                float forward = rand(pos.yyz) * _BladeForward;

                //与草地的交互
                float3 posWS = TransformObjectToWorld(pos);
                float dis = distance(_PositionMoving, posWS);
                float radius = 1 - saturate(dis / _Radius);
                float3 f = normalize(posWS-_PositionMoving.xyz);
                float3 up = float3(0, 1, 0);
                float3 left = cross(up, f);
                //o.color = float4(left,1) ;
                float4x4 sphereMatrix = AngleAxis3x3(saturate(radius * _Strength)*HALF_PI, float3(left.x,left.z,left.y));

                float4x4 bendRoationMatrix = AngleAxis3x3(
                    rand(pos.zzx) * _GrassRotationRandom * HALF_PI,
                    float3(-1, 0, 0));
                float4x4 rotationMatrix = AngleAxis3x3(ramdom * TWO_PI * _GrassRotationRandom2, float3(0, 0, 1));
                float4x4 formationMatrix = mul(tangentToLocal,
                                               mul(sphereMatrix, mul(rotationMatrix, bendRoationMatrix)));
                float4 normalWS = mul(formationMatrix, float4(0, 1, 0, 1));

                //*****************************************//
                float time = _Time.y;
                float3 windDir = normalize(_WindDirAndStrength.xyz);

                //风力强度，范围0~40 m/s
                float windStrength = _WindDirAndStrength.w;

                //生成一个扰动。扰动的频率，可以与风力挂钩，一般来说风力越强，抖动越厉害。
                float2 noiseUV = (TransformObjectToWorld(pos).xz - time) / 30;
                //noiseUV = IN[0].uv.xy;
                //float noiseValue = SAMPLE_TEXTURE2D(_NoiseMap,sampler_NoiseMap,uv).r;
                float noiseValue = SAMPLE_TEXTURE2D_LOD(_NoiseMap, sampler_NoiseMap, noiseUV, 0).g;
                noiseValue = sin(noiseValue * windStrength);

                //将扰动再加到风力上
                windStrength = noiseValue * _WindNoiseStrength;

                //归一化后到0~1区间
                windStrength = saturate(windStrength / 40);
                //o.color = windStrength;
                //*********************************************//

                for (int i = 0; i < BLANDE_SEGMENTS; i++)
                {
                    float t = i / (float)BLANDE_SEGMENTS;
                    float segmentHeight = _GrassHight * t;
                    float segmentWidth = _GrassWidth * (1 - t);

                    float segmentForward = pow(t, _BladeCurve) * forward;

                    o = GetVertex(pos + mul(formationMatrix, float3(segmentWidth, segmentForward, segmentHeight)),
                                  normalWS, float4(0, 0, 0, t),
                                  o.color, windDir, windStrength);
                    triangle_stream.Append(o);

                    o = GetVertex(pos + mul(formationMatrix, float3(-segmentWidth, segmentForward, segmentHeight)),
                                  normalWS, float4(0, 0, 1, t),
                                  o.color, windDir, windStrength);
                    triangle_stream.Append(o);
                }


                o = GetVertex(pos + mul(formationMatrix, float3(0, forward, _GrassHight)),
                              normalWS, float4(0, 0, 0.5, 1),
                              o.color, windDir, windStrength);
                triangle_stream.Append(o);
            }

            float4 frag(g2f i) : SV_Target
            {
                //对_MainTex纹理和_AlphaTex纹理进行采样
                float3 texColor = SAMPLE_TEXTURE2D(_GrassTex, sampler_GrassTex, i.uv.zw).rgb;
                texColor = lerp(0,texColor.rgb,i.uv.w);

                //将法线归一化
                float3 worldNormal = normalize(i.normalWS);

                //得到环境光
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                //得到世界空间下光照方向
                float3 worldLightDir = normalize(_MainLightPosition.xyz - i.posWS);

                //Diffuse 漫反射颜色
                float NdotL = saturate(dot(worldNormal, worldLightDir));
                float3 diffuse = texColor * NdotL * _MainLightColor;

                float3 finColor = diffuse + ambient;
                finColor = texColor + ambient;

                //shadow
                float4 SHADOW_COORDS = TransformWorldToShadowCoord(i.posWS);
                Light mainLight = GetMainLight(SHADOW_COORDS);
                half shadow = mainLight.shadowAttenuation * 0.5 + 0.5;

                //return NdotL;
                //return i.color;
                //return float4(lerp(float3(0,0,0),float3(1,1,1),shadow),1);
                return float4(_GrassColor.rgb * finColor * shadow, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowPass"
            Tags
            {
                //URP管线只允许一个pass
                "LightMode" = "ShadowCaster"
            }

            HLSLPROGRAM
            #pragma target 4.0
            #pragma multi_compile_fwdbase

            #pragma vertex vert
            #pragma fragment frag

            #pragma geometry geom

            #pragma hull HS
            #pragma domain DS

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

            #define BLANDE_SEGMENTS 3

            // make fog work
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            float4 _GroundColor;
            float4 _GrassColor;
            float _GrassWidth;
            float _GrassHight;
            float _GrassMove;
            float _GrassRotationRandom;
            float _GrassRotationRandom2;
            float _GrassHightRandom;
            float4 _MainTex_ST;
            float4 _GrassTex_ST;
            float4 _NoiseMap_ST;
            float _MyEdgeTess;
            float _MyInsideTess;
            float4 _WindDirAndStrength;
            float _WindNoiseStrength;
            float _BladeForward;
            float _BladeCurve;

            // 以下三个 uniform 在 URP shadows.hlsl 相关代码中可以看到没有放到 CBuffer 块中，所以我们只要在 定义为不同的 uniform 即可
            float3 _LightDirection;
            // float4 _ShadowBias; // x: depth bias, y: normal bias
            // float4 _MainLightShadowParams;  // (x: shadowStrength, y: 1.0 if soft shadows, 0.0 otherwise)


            TEXTURE2D(_MainTex); //内部会声明一个 texture2D    的属性
            SAMPLER(sampler_MainTex); //内部会声明一个 SamplerState 的属性
            TEXTURE2D(_GrassTex);
            SAMPLER(sampler_GrassTex);
            TEXTURE2D(_NoiseMap);
            SAMPLER(sampler_NoiseMap);

            struct appdata
            {
                float4 pos : POSITION;
                float4 uv : TEXCOORD0;
                float4 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 color :COLOR;
            };

            struct vertOut
            {
                float4 uv : TEXCOORD0;
                float4 pos : POSITION;
                float3 normal : TEXCOORD1;
                float4 tangent : TEXCOORD2;
                float4 color :TEXCOORD3;
            };

            struct g2f
            {
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 color :TEXCOORD2;
                float4 tangent : TEXCOORD3;
                float3 posWS : TEXCOORD4;
            };

            //有些硬件不支持曲面细分着色器，定义了该宏就能够在不支持的硬件上不会变粉，也不会报错
            #ifdef UNITY_CAN_COMPILE_TESSELLATION


            #endif

            //记录每条边的细分因子
            struct PatchTess
            {
                float EdgeTess[3]:SV_TessFactor;
                float InsideTess:SV_InsideTessFactor;
            };

            //Hull shader
            PatchTess ConstantHS(InputPatch<vertOut, 3> patch, uint patchID:SV_PrimitiveID)
            {
                PatchTess pt;
                pt.EdgeTess[0] = _MyEdgeTess;
                pt.EdgeTess[1] = _MyEdgeTess;
                pt.EdgeTess[2] = _MyEdgeTess;
                pt.InsideTess = _MyInsideTess;
                return pt;
            }

            struct HullOut
            {
                float4 uv : TEXCOORD0;
                float4 pos : POSITION;
                float3 normal : TEXCOORD1;
                float4 tangent : TEXCOORD2;
                float4 color :TEXCOORD3;
            };

            [domain("tri")] //拓扑的类型
            [partitioning("integer")] //曲面细分的拆分模式，还有 fraction模式

            //triangle_cw 顶点顺时针为正面，triangle_ccw 顶点逆时针为正面，line 只针对line的细分
            [outputtopology("triangle_cw")]

            //control point 的数目，同时也是 hull shander的执行次数。
            [outputcontrolpoints(3)]
            //让系统执行 ConstantHS 函数
            [patchconstantfunc("ConstantHS")]

            //硬件最大的细分因子
            [maxtessfactor(64.0f)]

            HullOut HS(InputPatch<vertOut, 3> p, uint i:SV_OutputControlPointID)
            {
                HullOut hout;
                hout.pos = p[i].pos;
                hout.uv = p[i].uv;
                hout.normal = p[i].normal;
                hout.tangent = p[i].tangent;
                hout.color = p[i].color;
                return hout;
            }

            struct DomainOut
            {
                float4 uv : TEXCOORD0;
                float4 pos : POSITION;
                float3 normal : TEXCOORD1;
                float4 tangent : TEXCOORD2;
                float4 color :TEXCOORD3;
            };

            [domain("tri")]
            vertOut DS(PatchTess patchTess, float3 baryCoords:SV_DomainLocation,
                       const OutputPatch<HullOut, 3> triangles)
            {
                vertOut dout;
                //搞不懂的重心空间切换
                float3 p = triangles[0].pos * baryCoords.x +
                    triangles[1].pos * baryCoords.y +
                    triangles[2].pos * baryCoords.z;

                dout.pos = float4(p, 1);
                dout.uv = triangles[0].uv * baryCoords.x +
                    triangles[1].uv * baryCoords.y +
                    triangles[2].uv * baryCoords.z;
                dout.normal = triangles[0].normal * baryCoords.x +
                    triangles[1].normal * baryCoords.y +
                    triangles[2].normal * baryCoords.z;
                dout.tangent = triangles[0].tangent * baryCoords.x +
                    triangles[1].tangent * baryCoords.y +
                    triangles[2].tangent * baryCoords.z;
                dout.color = triangles[0].color * baryCoords.x +
                    triangles[1].color * baryCoords.y +
                    triangles[2].color * baryCoords.z;

                return dout;
            }


            //生成随机数
            float rand(float3 co)
            {
                return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
            }

            //旋转矩阵
            float4x4 AngleAxis3x3(float angle, float3 axis)
            {
                float c, s;
                sincos(angle, s, c);

                float t = 1 - c;
                float x = axis.x;
                float y = axis.y;
                float z = axis.z;

                return float4x4(
                    t * x * x + c, t * x * y - s * z, t * x * z + s * y, 0,
                    t * x * y + s * z, t * y * y + c, t * y * z - s * x, 0,
                    t * x * z - s * y, t * y * z + s * x, t * z * z + c, 0,
                    0, 0, 0, 1
                );
            }


            //顶点着色器
            //直接将从网格得到的数据传给传入几何着色器的结构体 v2g
            vertOut vert(appdata v)
            {
                vertOut o;
                o.pos = v.pos;
                o.uv.xy = TRANSFORM_TEX(v.uv.xy, _MainTex);
                o.normal = v.normal;
                o.tangent = v.tangent;
                o.color = v.color;
                return o;
            }

            ///根据风力，计算顶点的世界坐标偏移
            ///positionWS - 顶点的世界坐标
            ///grassUpWS - 草的生长方向
            ///windDir - 是风的方向，应该为单位向量
            ///windStrength - 风力强度,范围(0~1)
            ///vertexLocalHeight - 顶点在草面片空间中的高度
            float3 applyWind(float3 positionWS, float3 grassUpWS, float3 windDir, float windStrength,
                             float vertexLocalHeight)
            {
                //根据风力，计算草弯曲角度，从0到90度
                float rad = windStrength * PI * 0.9 / 2;


                //得到wind与grassUpWS的正交向量
                windDir = normalize(windDir - dot(windDir, grassUpWS) * grassUpWS);

                float x, y; //弯曲后,x为单位球在wind方向计量，y为grassUp方向计量
                sincos(rad, x, y);

                //offset表示grassUpWS这个位置的顶点，在风力作用下，会偏移到windedPos位置
                float3 windedPos = x * windDir + y * grassUpWS;

                //加上世界偏移
                return positionWS + (windedPos - grassUpWS) * vertexLocalHeight;
            }

            //获取 交给 光栅化的顶点
            g2f GetVertex(float4 pos, float3 normal, float4 uv, float4 color, float3 windDir, float windStrength)
            {
                g2f output;


                float3 posWS = TransformObjectToWorld(pos.xyz);
                float3 normalWS = TransformObjectToWorldNormal(normal);

                posWS = ApplyShadowBias(posWS, TransformObjectToWorldNormal(normalWS), _LightDirection * 5);

                posWS = applyWind(posWS, normalWS, windDir, windStrength, pos.y);

                output.pos = TransformWorldToHClip(posWS);
                output.posWS = posWS;
                output.normalWS = normalWS;
                output.uv = uv;
                output.uv.zw = TRANSFORM_TEX(uv.zw, _GrassTex);
                output.color = color;
                output.tangent = 1;

                return output;
            }

            //获取 交给 光栅化的顶点
            float4x4 GetTangentToLocal(float4 tangent, float3 normal)
            {
                float3 binormal = cross(normal, tangent) * tangent.w;

                float4x4 m = float4x4(
                    tangent.x, binormal.x, normal.x, 0,
                    tangent.y, binormal.y, normal.y, 0,
                    tangent.z, binormal.z, normal.z, 0,
                    0, 0, 0, 1
                );

                return m;
            }

            //获取 交给 光栅化的顶点
            float4x4 GetMoveMaterial(float x, float y, float z)
            {
                float4x4 m = float4x4(
                    1, 0, 0, x,
                    0, 1, 0, y,
                    0, 0, 1, z,
                    0, 0, 0, 1
                );

                return m;
            }

            //几何着色器
            [maxvertexcount(BLANDE_SEGMENTS*2+1)]
            void geom(triangle vertOut IN[3]:SV_POSITION, inout TriangleStream<g2f> triangle_stream)
            {
                g2f o;

                o.color = _GrassColor;
                float4 pos = (IN[0].pos + IN[1].pos + IN[2].pos) / 3;
                float4x4 tangentToLocal = GetTangentToLocal(
                    (IN[0].tangent + IN[1].tangent + IN[2].tangent) / 3,
                    (IN[0].normal + IN[1].normal + IN[2].normal) / 3);

                float ramdom = rand(pos);

                //弯曲（curvature）
                float forward = rand(pos.yyz) * _BladeForward;

                float4x4 bendRoationMatrix = AngleAxis3x3(
                    rand(pos.zzx) * _GrassRotationRandom * HALF_PI,
                    float3(-1, 0, 0));
                float4x4 rotationMatrix = AngleAxis3x3(ramdom * TWO_PI * _GrassRotationRandom2, float3(0, 0, 1));
                float4x4 formationMatrix = mul(tangentToLocal, mul(rotationMatrix, bendRoationMatrix));
                float4 normalWS = float4(0, 1 + ramdom * 0.1, 0, 1);

                //*****************************************//
                float time = _Time.y;
                float3 windDir = normalize(_WindDirAndStrength.xyz);

                //风力强度，范围0~40 m/s
                float windStrength = _WindDirAndStrength.w;

                //生成一个扰动。扰动的频率，可以与风力挂钩，一般来说风力越强，抖动越厉害。
                float2 noiseUV = (TransformObjectToWorld(pos).xz - time) / 30;
                //noiseUV = IN[0].uv.xy;
                //float noiseValue = SAMPLE_TEXTURE2D(_NoiseMap,sampler_NoiseMap,uv).r;
                float noiseValue = SAMPLE_TEXTURE2D_LOD(_NoiseMap, sampler_NoiseMap, noiseUV, 0).g;
                noiseValue = sin(noiseValue * windStrength);

                //将扰动再加到风力上
                windStrength = noiseValue * _WindNoiseStrength;

                //归一化后到0~1区间
                windStrength = saturate(windStrength / 40);
                o.color = windStrength;
                //*********************************************//

                for (int i = 0; i < BLANDE_SEGMENTS; i++)
                {
                    float t = i / (float)BLANDE_SEGMENTS;
                    float segmentHeight = _GrassHight * t;
                    float segmentWidth = _GrassWidth * (1 - t);

                    float segmentForward = pow(t, _BladeCurve) * forward;

                    o = GetVertex(pos + mul(formationMatrix, float3(segmentWidth, segmentForward, segmentHeight)),
                                  normalWS, float4(0, 0, 0, t),
                                  o.color, windDir, windStrength);
                    triangle_stream.Append(o);

                    o = GetVertex(pos + mul(formationMatrix, float3(-segmentWidth, segmentForward, segmentHeight)),
                                  normalWS, float4(0, 0, 1, t),
                                  o.color, windDir, windStrength);
                    triangle_stream.Append(o);
                }


                o = GetVertex(pos + mul(formationMatrix, float3(0, forward, _GrassHight)),
                              normalWS, float4(0, 0, 0.5, 1),
                              o.color, windDir, windStrength);
                triangle_stream.Append(o);

                o = GetVertex(IN[0].pos,
                              IN[0].normal, IN[0].uv,
                              o.color, 0, 0);
                triangle_stream.Append(o);
                o = GetVertex(IN[1].pos,
                              IN[1].normal, IN[1].uv,
                              o.color, 0, 0);
                triangle_stream.Append(o);
                o = GetVertex(IN[2].pos,
                              IN[2].normal, IN[2].uv,
                              o.color, 0, 0);
                triangle_stream.Append(o);
            }

            float4 frag(g2f i) : SV_Target
            {
                return float4(_GroundColor.rgb, 1);
            }
            ENDHLSL
        }

    }
}