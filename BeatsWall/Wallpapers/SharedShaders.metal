//
//  SharedShaders.metal
//  BeatsWall
//
//  Effects any collection can use through `ShaderLibrary`.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1));
    float d = hash21(i + float2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int octave = 0; octave < 5; octave++) {
        value += amplitude * valueNoise(p);
        p = p * 2.03 + 17.1;
        amplitude *= 0.5;
    }
    return value;
}

/// Fine, static paper grain.
[[ stitchable ]] half4 grain(float2 position, half4 color, float amount) {
    float noise = hash21(floor(position)) - 0.5;
    return half4(color.rgb + half(noise * amount) * color.a, color.a);
}

/// CRT-style scanlines with a slow rolling brightness band.
[[ stitchable ]] half4 scanlines(float2 position, half4 color, float time, float intensity, float lineSpacing) {
    float line = 0.5 + 0.5 * cos(position.y * 6.2831853 / lineSpacing);
    float roll = 0.5 + 0.5 * sin(position.y * 0.004 - time * 0.9);
    half3 rgb = color.rgb * half(1.0 - intensity * line);
    rgb *= half(0.94 + 0.08 * roll);
    float noise = hash21(position + fract(time) * 97.0) - 0.5;
    return half4(rgb + half(noise * 0.025), color.a);
}

/// Worn VHS playback: color bleed, per-line jitter and a rolling tracking band.
/// `intensity` 0...1 scales every artifact.
[[ stitchable ]] half4 vhs(float2 position, SwiftUI::Layer layer, float time, float intensity, float2 size) {
    float bandY = fract(time * 0.11) * size.y * 1.4 - size.y * 0.2;
    float band = exp(-pow((position.y - bandY) / (size.y * 0.035), 2.0));
    float line = floor(position.y / 3.0);
    float jitter = (hash21(float2(line, floor(time * 24.0))) - 0.5) * (0.6 + intensity * 7.0);
    float2 p = position + float2(jitter + band * (6.0 + 22.0 * intensity), 0.0);

    float shift = 1.5 + intensity * 7.0;
    half4 center = layer.sample(p);
    half red = layer.sample(p + float2(shift, 0.0)).r;
    half blue = layer.sample(p - float2(shift, 0.0)).b;
    half4 color = half4(red, center.g, blue, center.a);

    float noise = hash21(position + fract(time) * 91.0);
    color.rgb += half(band * (noise - 0.35) * 0.6);
    color.rgb *= half(0.9 + 0.1 * cos(position.y * 3.14159));
    color.rgb += half((noise - 0.5) * 0.05);
    return color;
}

/// Fisheye bulge. `strength` around 0.1–0.3. Corners stay in place so nothing samples off-screen.
[[ stitchable ]] float2 barrel(float2 position, float2 size, float strength) {
    float2 uv = position / size * 2.0 - 1.0;
    float r2 = dot(uv, uv);
    uv *= 1.0 - strength * (1.0 - r2 * 0.5);
    return (uv + 1.0) * 0.5 * size;
}

/// Swirling gas clouds. `flow` should be an integrated phase so speed changes stay smooth.
[[ stitchable ]] half4 nebula(float2 position, half4 color, float2 size, float flow, float energy, half4 colorA, half4 colorB, half4 colorC) {
    float2 uv = position / size.y;
    float2 q = float2(fbm(uv * 1.6 + flow * 0.05), fbm(uv * 1.6 + float2(5.2, 1.3) - flow * 0.04));
    float n = fbm(uv * 2.2 + q * 1.8 + flow * 0.02);
    half3 gas = mix(colorA.rgb, colorB.rgb, half(smoothstep(0.3, 0.75, n)));
    gas = mix(gas, colorC.rgb, half(smoothstep(0.5, 0.95, q.x * n * 1.7)));
    float density = smoothstep(0.28, 0.8, n);
    float brightness = (0.4 + 0.9 * n * n) * (0.75 + 0.6 * energy);
    return half4(mix(color.rgb, gas * half(brightness), half(density)), color.a);
}

/// Skateboard grip tape: dark grit with occasional glinting grains. Keeps the shape's alpha.
[[ stitchable ]] half4 gripTape(float2 position, half4 color, float scale, float time, float glint) {
    float2 cell = floor(position / scale);
    float grit = hash21(cell);
    float mottling = valueNoise(position / (scale * 9.0));
    float luminance = 0.09 + 0.07 * grit + 0.05 * mottling;
    float sparkle = step(0.988, hash21(cell + 7.3)) * (0.5 + 0.5 * sin(time * 7.0 + grit * 60.0));
    luminance += sparkle * (0.15 + 0.7 * glint);
    return half4(half3(luminance) * color.a, color.a);
}
