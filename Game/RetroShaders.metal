#include <metal_stdlib>
using namespace metal;

struct RetroUniforms {
    float4x4 inverseProjection;
    float4x4 cameraToWorld;
    float4 fog;
    float4 style;
    float4 viewport;
};

struct FullscreenVertex { float4 position [[position]]; };
vertex FullscreenVertex nocturneFullscreen(uint id [[vertex_id]]) {
    const float2 positions[3] = {float2(-1,-1), float2(3,-1), float2(-1,3)};
    return { float4(positions[id], 0, 1) };
}

float2 retroUV(float2 pixel, constant RetroUniforms& u) {
    float block = max(1.0f, floor(u.viewport.x / u.style.x));
    return (floor(pixel / block) * block + block * 0.5f) / u.viewport.xy;
}

float4 shadeRetro(texture2d<float, access::sample> color, float z,
                  constant RetroUniforms& u, float2 pixel) {
    constexpr sampler point(coord::normalized, address::clamp_to_edge, filter::nearest);
    constexpr sampler soft(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 size = u.viewport.xy;
    float block = max(1.0f, floor(size.x / u.style.x));
    float2 cell = floor(pixel / block);
    float2 uv = (cell * block + block * 0.5f) / size;
    float3 rgb = max(float3(0), color.sample(point, uv).rgb);
    float4 view = u.inverseProjection * float4(uv.x * 2 - 1, 1 - uv.y * 2, z, 1);
    float distance = 250;
    float3 world = float3(0, 20, 0);
    if (abs(view.w) > 0.00001f) {
        view /= view.w;
        distance = min(250.0f, length(view.xyz));
        world = (u.cameraToWorld * float4(view.xyz, 1)).xyz;
    }
    // Low banks of smoke vary in world space, not a flat red screen overlay.
    float banks = 0.5f + 0.5f * sin(world.x * 0.22f + sin(world.z * 0.19f));
    float low = 1.0f - smoothstep(0.6f, 5.0f, world.y);
    float density = u.fog.w * (0.8f + banks * low * 1.1f);
    float fogAmount = 1.0f - exp(-max(0.0f, distance - u.style.w) * density);
    rgb = mix(rgb, u.fog.rgb, min(0.97f, fogAmount));

    // Small, bounded bright-pass glow. No full-resolution blur intermediates.
    float3 glow = float3(0);
    const float2 offsets[4] = {float2(-3,0), float2(3,0), float2(0,-3), float2(0,3)};
    for (uint i = 0; i < 4; ++i) {
        float3 neighbor = color.sample(soft, uv + offsets[i] * block / size).rgb;
        glow += max(neighbor - 0.7f, 0.0f);
    }
    rgb += glow * 0.085f * (1.0f - fogAmount * 0.75f);
    float2 centered = uv * 2 - 1;
    rgb *= 1.0f - 0.18f * saturate(dot(centered, centered) * 0.5f);

    // Stable ordered dither + film-like coarse grain, leaving the SwiftUI HUD sharp.
    const float bayer[16] = {0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5};
    uint2 c = uint2(cell);
    float dither = (bayer[(c.y & 3u) * 4u + (c.x & 3u)] / 16.0f - 0.5f) / 31.0f;
    float grain = fract(sin(dot(cell, float2(12.9898f,78.233f))) * 43758.5453f) - 0.5f;
    rgb = pow(saturate(rgb), float3(1.0f / 2.2f));
    rgb = saturate(floor((rgb + dither + grain * 0.014f) * 31.0f + 0.5f) / 31.0f);
    // Return linear light; the native render attachment handles its own encoding.
    return float4(pow(rgb, float3(2.2f)), 1);
}

fragment float4 nocturneRetroDepth(FullscreenVertex in [[stage_in]],
    texture2d<float> color [[texture(0)]], depth2d<float> depth [[texture(1)]],
    constant RetroUniforms& u [[buffer(0)]]) {
    constexpr sampler point(coord::normalized, address::clamp_to_edge, filter::nearest);
    return shadeRetro(color, depth.sample(point, retroUV(in.position.xy, u)), u, in.position.xy);
}

fragment float4 nocturneRetroColorDepth(FullscreenVertex in [[stage_in]],
    texture2d<float> color [[texture(0)]], texture2d<float> depth [[texture(1)]],
    constant RetroUniforms& u [[buffer(0)]]) {
    constexpr sampler point(coord::normalized, address::clamp_to_edge, filter::nearest);
    return shadeRetro(color, depth.sample(point, retroUV(in.position.xy, u)).r, u, in.position.xy);
}

fragment float4 nocturneCopy(FullscreenVertex in [[stage_in]], texture2d<float> color [[texture(0)]],
                            constant RetroUniforms& u [[buffer(0)]]) {
    constexpr sampler linear(coord::normalized, address::clamp_to_edge, filter::linear);
    return color.sample(linear, in.position.xy / u.viewport.xy);
}
