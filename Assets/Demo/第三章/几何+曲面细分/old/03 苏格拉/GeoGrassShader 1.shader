Shader "Unlit/GeoGrassShaderNew"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _GroundColor ("GroundColor", Color) = (1,1,1,1)
        _GrassColor ("GrassColor", Color) = (1,1,1,1)
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

        _SpecularPower("SpecularPower",float) = 40
        _SpecularHeight("SpecularHeight",Range(-3,3))=0
        _SpecularColor("SpecularColor",Color)=(0,1,0,1)

        _StylizedMap("StylizedMap", 2D) = "white" {}
        _StylizedRamp("StylizedRamp", 2D) = "white" {}
        _StylizedScale("StylizedScale", float) = 1.0
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
            Name "GrassPass"
            Tags
            {
                //URP管线只允许一个pass
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom
            #define TESSELLATION_ON 1
            #pragma require tessellation tessHW
            #pragma hull HS
            #pragma domain DS
            #define ASE_FIXED_TESSELLATION


            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

            #define BLANDE_SEGMENTS 3


            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

            // make fog work
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

            CBUFFER_START(UnityPerMaterial)
            #ifdef TESSELLATION_ON
            float _TessPhongStrength;
            float _TessValue;
            float _TessMin;
            float _TessMax;
            float _TessEdgeLength;
            float _TessMaxDisp;
            #endif
            CBUFFER_END

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
            SAMPLER(_JBLMap);
            TEXTURE2D(sampler_JBLMap);
            float _JBLScale;
            float _SpecularPower;
            float _SpecularHeight;
            float4 _SpecularColor;

            TEXTURE2D(_StylizedMap);
            SAMPLER(sampler_StylizedMap);
            TEXTURE2D(_StylizedRamp);
            SAMPLER(sampler_StylizedRamp);
            float _StylizedScale;

            struct appdata
            {
                float4 pos : POSITION;
                float4 uv : TEXCOORD0;
                float4 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 color :COLOR;
                //uint instanceID : SV_InstanceID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct vertOut
            {
                float4 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 normal : TEXCOORD1;
                float4 tangent : TEXCOORD2;
                float4 color :TEXCOORD3;
                float3 normalWS : TEXCOORD4;
                float3 posWS : TEXCOORD5;
                // clipPos : SV_POSITION;
                //uint instanceID : SV_InstanceID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            //有些硬件不支持曲面细分着色器，定义了该宏就能够在不支持的硬件上不会变粉，也不会报错
            #ifdef UNITY_CAN_COMPILE_TESSELLATION


            #endif

            //记录每条边的细分因子
            struct TessellationFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            TessellationFactors TessellationFunction(InputPatch<vertOut, 3> v)
            {
                TessellationFactors o;
                o.edge[0] = _MyEdgeTess;
                o.edge[1] = _MyEdgeTess;
                o.edge[2] = _MyEdgeTess;
                o.inside = _MyInsideTess;
                return o;
            }

            [domain("tri")] //拓扑的类型
            [partitioning("integer")] //曲面细分的拆分模式，还有 fraction模式
            //triangle_cw 顶点顺时针为正面，triangle_ccw 顶点逆时针为正面，line 只针对line的细分
            [outputtopology("triangle_cw")]
            //control point 的数目，同时也是 hull shander的执行次数。
            [outputcontrolpoints(3)]
            //让系统执行 TessellationFunction 函数
            [patchconstantfunc("TessellationFunction")]
            //硬件最大的细分因子
            //[maxtessfactor(64.0f)]
            vertOut HS(InputPatch<vertOut, 3> p, uint i:SV_OutputControlPointID)
            {
                return p[i];
            }

            vertOut VertexFunction(vertOut v)
            {
                vertOut o = (vertOut)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float div7 = 256.0 / float(1);
                float4 posterize7 = (floor(float4(0, 0, 0, 0) * div7) / div7);

                #ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
                #else
                float3 defaultVertexValue = float3(0, 0, 0);
                #endif
                float3 vertexValue = posterize7.rgb;
                #ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
                #else
                v.pos.xyz += vertexValue;
                #endif
                v.normal = v.normal;

                float3 positionWS = TransformObjectToWorld(v.pos.xyz);
                float4 positionCS = TransformWorldToHClip(positionWS);

                #if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
				o.worldPos = positionWS;
                #endif
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
				VertexPositionInputs vertexInput = (VertexPositionInputs)0;
				vertexInput.positionWS = positionWS;
				vertexInput.positionCS = positionCS;
				o.shadowCoord = GetShadowCoord( vertexInput );
                #endif
                #ifdef ASE_FOG
				o.fogFactor = ComputeFogFactor( positionCS.z );
                #endif
                o.pos = positionCS;
                return o;
            }

            //曲面细分
            [domain("tri")]
            vertOut DS(TessellationFactors patchTess, const OutputPatch<vertOut, 3> triangles,
                       float3 baryCoords:SV_DomainLocation)
            {
                vertOut dout;
                UNITY_TRANSFER_INSTANCE_ID(triangles[0], dout);
                //UNITY_SETUP_INSTANCE_ID(triangles[1]);


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

                //dout.instanceID = triangles[0].instanceID;
                //UNITY_SETUP_INSTANCE_ID(triangles[1]);
                UNITY_TRANSFER_INSTANCE_ID(triangles[0], dout);
                // UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(dout);

                //------为啥要新建一个结构体才可以传递
                vertOut o;
                UNITY_SETUP_INSTANCE_ID(triangles[0]);
                UNITY_TRANSFER_INSTANCE_ID(triangles[0], o);
                //UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(dout);
                o.pos = dout.pos;
                o.uv = dout.uv;
                o.normal = dout.normal;
                o.tangent = dout.tangent;
                o.color = dout.color;
                //o.pos = TransformObjectToHClip(dout.pos);

                return o;
            }


            //生成随机数
            float rand(float3 co)
            {
                co = TransformObjectToWorld(co);
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
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                //UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.pos = float4(v.pos.xyz, 1);
                o.uv.xy = TRANSFORM_TEX(v.uv.xy, _MainTex);
                o.normal = (v.normal);
                o.tangent = (v.tangent);
                o.color = v.color;
                //o.pos = TransformObjectToHClip(o.pos);
                return o;
            }

            ///根据风力，计算顶点的世界坐标偏移
            ///positionWS - 顶点的世界坐标
            ///grassUpWS - 草的生长方向
            ///windDir - 是风的方向，应该为单位向量
            ///windStrength - 风力强度,范围(0~1)
            ///vertexLocalHeight - 顶点在草面片空间中的高度
            float3 applyWind(float3 positionWS, float3 grassUpWS,
                             float3 windDir, float windStrength,
                             float vertexLocalHeight, out float3 newNormalWS)
            {
                //根据风力，计算草弯曲角度，从0到90度
                float rad = windStrength * PI * 0.9 / 2;


                //得到wind与grassUpWS的正交向量
                windDir = normalize(windDir - dot(windDir, grassUpWS) * grassUpWS);

                float x, y; //弯曲后,x为单位球在wind方向计量，y为grassUp方向计量
                sincos(rad, x, y);

                //offset表示grassUpWS这个位置的顶点，在风力作用下，会偏移到windedPos位置
                float3 windedPos = x * windDir + y * grassUpWS;
                newNormalWS = normalize(grassUpWS + windDir * x);

                //加上世界偏移
                return positionWS + (windedPos - grassUpWS) * vertexLocalHeight;
            }

            //获取 交给 光栅化的顶点
            vertOut GetVertex(float4 pos, float3 normal, float4 uv, float4 color,
                              float3 windDir, float windStrength, vertOut IN)
            {
                vertOut output = (vertOut)0;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, output);
                //UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);


                float3 posWS = TransformObjectToWorld(pos.xyz);
                float3 normalWS = TransformObjectToWorldNormal(normal);

                float3 newNormalWS;
                posWS = applyWind(posWS, normalWS,
                                  windDir, windStrength, pos.y, newNormalWS);

                output.pos = TransformWorldToHClip(posWS);
                output.posWS = posWS;
                output.normalWS = newNormalWS;
                output.uv = uv;
                output.uv.zw = TRANSFORM_TEX(uv.zw, _GrassTex);
                output.color = float4(color.rgb, 1);
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
            void geom(triangle vertOut IN[3]:SV_POSITION, inout TriangleStream<vertOut> triangle_stream)
            {
                vertOut o = (vertOut)1;
                UNITY_TRANSFER_INSTANCE_ID(IN[0], o);
                UNITY_SETUP_INSTANCE_ID(IN[0]);
                //uint ID = o.instanceID;

                float4 pos = (IN[0].pos + IN[1].pos + IN[2].pos) / 3;
                float4x4 tangentToLocal = GetTangentToLocal(
                    (IN[0].tangent + IN[1].tangent + IN[2].tangent) / 3,
                    (IN[0].normal + IN[1].normal + IN[2].normal) / 3);

                float ramdom = rand(pos);

                //弯曲（curvature）
                float forward = rand(pos.yyz) * _BladeForward;

                // //与草地的交互
                // float3 posWS = TransformObjectToWorld(pos);
                // float dis = distance(_PositionMoving, posWS);
                // float radius = 1 - saturate(dis / _Radius);
                // float3 f = normalize(posWS - _PositionMoving.xyz);
                // float3 up = float3(0, 1, 0);
                // float3 left = cross(up, f);
                // //o.color = float4(left,1) ;
                // float4x4 sphereMatrix = AngleAxis3x3(saturate(radius * _Strength) * HALF_PI,
                //                                      float3(left.x, left.z, left.y));
                float4x4 sphereMatrix = AngleAxis3x3(0, float3(0, 0, 0));

                //绕xz旋转
                float4x4 bendRoationMatrix = AngleAxis3x3(
                    rand(pos.zzx) * _GrassRotationRandom * HALF_PI,
                    float3(-1, 0, 0));
                //绕y轴旋转
                float4x4 rotationMatrix = AngleAxis3x3(ramdom * TWO_PI * _GrassRotationRandom2, float3(0, 0, 1));
                float4x4 formationMatrix = mul(tangentToLocal,
                                               mul(sphereMatrix, mul(rotationMatrix, bendRoationMatrix)));
                // formationMatrix = 
                //                              mul(sphereMatrix, mul(rotationMatrix, bendRoationMatrix));                             
                float4 normalWS = mul(tangentToLocal, float4(0, 0, 1, 0));
                //o.color = normalWS;
                //normalWS = mul(normalWS,unity_WorldToObject);

                //*****************************************//
                float time = _Time.y;
                float3 windDir = normalize(_WindDirAndStrength.xyz);

                //风力强度，范围0~40 m/s
                float windStrength = _WindDirAndStrength.w;

                //生成一个扰动。扰动的频率，可以与风力挂钩，一般来说风力越强，抖动越厉害。
                float2 noiseUV = (TransformObjectToWorld(pos).xz * _NoiseMap_ST.xy + _NoiseMap_ST.zw - time) / 40;
                //noiseUV = IN[0].uv.xy;
                //float noiseValue = SAMPLE_TEXTURE2D(_NoiseMap,sampler_NoiseMap,uv).r;
                float noiseValue = SAMPLE_TEXTURE2D_LOD(_NoiseMap, sampler_NoiseMap, noiseUV, 0).r;

                noiseValue = sin(noiseValue * windStrength);

                //将扰动再加到风力上
                windStrength = noiseValue * _WindNoiseStrength;

                //归一化后到0~1区间
                windStrength = saturate(windStrength / 50);
                o.color = windStrength;

                //*********************************************//


                for (int i = 0; i < BLANDE_SEGMENTS; i++)
                {
                    float t = i / (float)BLANDE_SEGMENTS;
                    float segmentHeight = _GrassHight * t;
                    float segmentWidth = _GrassWidth * (1 - t);

                    float segmentForward = pow(t, _BladeCurve) * forward;

                    o = GetVertex(
                        pos + mul(formationMatrix, float3(segmentWidth, segmentForward, segmentHeight)),
                        normalWS, float4(0, 0, 0, t),
                        o.color, windDir, windStrength, o);
                    //UNITY_TRANSFER_INSTANCE_ID(IN[0], o);
                    triangle_stream.Append(o);

                    o = GetVertex(
                        pos + mul(formationMatrix, float3(-segmentWidth, segmentForward, segmentHeight)),
                        normalWS, float4(0, 0, 1, t),
                        o.color, windDir, windStrength, o);
                    //UNITY_TRANSFER_INSTANCE_ID(IN[1], o);
                    triangle_stream.Append(o);
                }

                o = GetVertex(pos + mul(formationMatrix, float3(0, forward, _GrassHight)),
                              normalWS, float4(0, 0, 0.5, 1),
                              o.color, windDir, windStrength, o);
                //UNITY_TRANSFER_INSTANCE_ID(IN[2], o);
                triangle_stream.Append(o);
            }

            float4 frag(vertOut i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                //return i.color;
                //return float4(i.normalWS,1);
                //UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( i );

                //对_MainTex纹理和_AlphaTex纹理进行采样
                float2 posWSUV = (i.posWS.xz) * (1 / _StylizedScale);
                //return float4(posWSUV.x,posWSUV.y,0,1);
                float3 stylizedColor =
                    SAMPLE_TEXTURE2D(_StylizedMap, sampler_StylizedMap, posWSUV).rgb;
                //stylizedColor = SRGBToLinear(stylizedColor); 
                //float3 stylizedColor = SAMPLE_TEXTURE2D(_StylizedRamp,sampler_StylizedMap,float2(stylized,1.5));

                //对_MainTex纹理和_AlphaTex纹理进行采样
                float4 texColor = SAMPLE_TEXTURE2D(_GrassTex, sampler_GrassTex, i.uv.zw);
                //将法线归一化
                float3 worldNormal = normalize(i.normalWS);
                //得到环境光
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                //shadow
                float4 SHADOW_COORDS = TransformWorldToShadowCoord(i.posWS);
                Light mainLight = GetMainLight(SHADOW_COORDS);
                //得到视角向量
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                float3 halfDir = normalize(viewDir + normalize(mainLight.direction));

                //Diffuse 漫反射颜色
                float NdotL = max(0.2, dot(worldNormal, normalize(mainLight.direction)));
                float3 diffuse = texColor * _MainLightColor * _GrassColor.rgb;
                diffuse = lerp(diffuse * NdotL, stylizedColor, 0.7);
                //diffuse = stylizedColor;
                //return float4(diffuse,1);

                //高光
                float specular = dot(halfDir, worldNormal);
                specular = pow(specular, _SpecularPower);
                //specular = smoothstep(0.2,0.8,specular);
                //return float4(worldNormal,1);
                specular = saturate(lerp(_SpecularHeight, specular, i.uv.w));
                //return specular;


                //自阴影
                float c = smoothstep(-0.5, 0.5, i.uv.w);
                float3 finColor = diffuse * c + specular * _SpecularColor.rgb;
                return float4(finColor, 1);
            }
            ENDHLSL
        }

    }
}