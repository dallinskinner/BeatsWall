//
//  ClaudeShaders.metal
//  BeatsWall
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float claudeHash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

/// Fine, static paper grain.
[[ stitchable ]] half4 claudeGrain(float2 position, half4 color, float amount) {
    float noise = claudeHash(floor(position)) - 0.5;
    return half4(color.rgb + half(noise * amount), color.a);
}

/// CRT-style scanlines with a slow rolling brightness band.
[[ stitchable ]] half4 claudeScanlines(float2 position, half4 color, float time, float intensity, float lineSpacing) {
    float line = 0.5 + 0.5 * cos(position.y * 6.2831853 / lineSpacing);
    float roll = 0.5 + 0.5 * sin(position.y * 0.004 - time * 0.9);
    half3 rgb = color.rgb * half(1.0 - intensity * line);
    rgb *= half(0.94 + 0.08 * roll);
    float noise = claudeHash(position + fract(time) * 97.0) - 0.5;
    return half4(rgb + half(noise * 0.025), color.a);
}
