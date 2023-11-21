
#version 450

layout(constant_id = 4) const uint _2 = 0u;

struct _22
{
    float _m0;
    float _m1;
    float _m2;
    float _m3;
};

const float _102[4] = float[](-0.01171875, 0.00390625, 0.01171875, -0.00390625);

layout(set = 1, binding = 1, std140) uniform _16_18
{
    float _m0;
    float _m1;
    float _m2;
    float _m3;
} _18;

layout(set = 0, binding = 0, std140) uniform _23_25
{
    vec4 _m0;
    uint _m1;
    uint _m2;
    int _m3;
    int _m4;
    ivec4 _m5;
    uvec4 _m6;
    _22 _m7;
} _25;

layout(set = 2, binding = 0) uniform sampler2D _tex;

layout(location = 0) in vec4 _10;
layout(location = 0) out vec4 _12;
vec4 _14;
vec4 _15;
float _120;
uint _124;
vec3 _130 = vec3(255.0);

void _28()
{
    vec2 _42 = (-vec2(_18._m1, _18._m2)) + vec2(1.0);
    _14 = vec4(_42.x, _42.y, _14.z, _14.w);
    _14.w = (-_18._m3) + 1.0;
    vec3 _63 = _14.xyw * vec3(_18._m0, _18._m0, _18._m0);
    _14 = vec4(_63.x, _63.y, _63.z, _14.w);
    _15 = texture(_tex, _10.xy);
    vec3 _75 = (-_14.xyz) + _15.xyz;
    _14 = vec4(_75.x, _75.y, _75.z, _14.w);
    _12.w = _15.w;
    vec3 _85 = max(_14.xyz, vec3(0.0));
    _12 = vec4(_85.x, _85.y, _85.z, _12.w);
}

void main()
{
    vec3 _126 = vec3(0.0);
    _28();
    if (_2 != 0u)
    {
        _120 = _102[((uint(gl_FragCoord.x) & 1u) << 1u) | (uint(gl_FragCoord.y) & 1u)];
        _124 = (_2 >> 0u) & 3u;
        switch (_124)
        {
            case 1u:
            {
                _126 = vec3(_120 * 2.0);
                _130 = vec3(15.0);
                break;
            }
            case 2u:
            {
                _126 = vec3(_120);
                _130 = vec3(31.0);
                break;
            }
            case 3u:
            {
                _126 = vec3(_120, _120 * 0.5, _120);
                _130 = vec3(31.0, 63.0, 31.0);
                break;
            }
        }
        vec3 _157 = _12.xyz + _126;
        _12 = vec4(_157.x, _157.y, _157.z, _12.w);
        vec3 _166 = round(_12.xyz * _130) / _130;
        _12 = vec4(_166.x, _166.y, _166.z, _12.w);
    }
}