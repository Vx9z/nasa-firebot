#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform float uWidth;
uniform float uHeight;
uniform float uRadius;

out vec4 fragColor;

// Kawase-style blur: sample at increasing offsets with decreasing weights.
// Cheap but smooth — approximates a wide Gaussian with a few diagonal taps.
void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = vec2(fragCoord.x / uWidth, fragCoord.y / uHeight);
    vec2 texel = vec2(1.0 / uWidth, 1.0 / uHeight);

    vec3 col = texture(uTexture, uv).rgb;
    float total = 1.0;
    for (int i = 1; i <= 8; i++) {
        float o = float(i) * uRadius;
        float w = 1.0 / float(i + 1);
        col += texture(uTexture, uv + vec2(o, o) * texel).rgb * w;
        col += texture(uTexture, uv + vec2(-o, o) * texel).rgb * w;
        col += texture(uTexture, uv + vec2(o, -o) * texel).rgb * w;
        col += texture(uTexture, uv + vec2(-o, -o) * texel).rgb * w;
        total += w * 4.0;
    }
    fragColor = vec4(col / total, 1.0);
}
