#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform float uCurvature;
uniform float uVignette;
uniform float uScanlines;
uniform float uGlow;
uniform float uBezelN;
uniform float uBezelInset;
uniform float uAspect;
uniform float uWidth;
uniform float uHeight;
uniform float uColorR;
uniform float uColorG;
uniform float uColorB;

out vec4 fragColor;

// 1-D Gaussian kernel (binomial [1 4 6 4 1]) for the phosphor bloom.
float gauss(int i) {
    if (i == -2 || i == 2) return 1.0;
    if (i == -1 || i == 1) return 4.0;
    return 6.0;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 p = vec2(fragCoord.x / uWidth, fragCoord.y / uHeight) * 2.0 - 1.0;

    // Curvature (barrel): sample the source inward toward the centre.
    float r2 = dot(p, p);
    float k = 1.0 + uCurvature * r2;
    vec2 srcUV = (p / k + 1.0) * 0.5;

    vec3 col = texture(uTexture, srcUV).rgb;
    vec3 theme = vec3(uColorR, uColorG, uColorB);

    // Screen glow: 30..60 / 255 (tune.py's edge + (center - edge) * (1 - r2)).
    float glowAmt = 0.1176 + 0.1176 * (1.0 - clamp(r2, 0.0, 1.0));
    col += theme * glowAmt;

    // Phosphor bloom: 5x5 Gaussian blur of the source, blended (soft CRT glow).
    vec2 texel = vec2(1.0 / uWidth, 1.0 / uHeight);
    vec3 bloom = vec3(0.0);
    for (int i = -2; i <= 2; i++) {
        for (int j = -2; j <= 2; j++) {
            float w = gauss(i) * gauss(j);
            bloom += texture(uTexture, srcUV + vec2(float(i), float(j)) * texel).rgb * w;
        }
    }
    bloom /= 256.0;
    col = mix(col, bloom, uGlow);

    // Vignette.
    col *= 1.0 - uVignette * clamp(r2, 0.0, 1.0);

    // Scanlines (every third row).
    if (mod(fragCoord.y, 3.0) < 1.0) {
        col *= 1.0 - uScanlines;
    }

    // Bezel (superellipse mask — the "bent black bars").
    float a = 1.0 - uBezelInset;
    float ax = a;
    float ay = a;
    float canvasAspect = uWidth / uHeight;
    if (uAspect > canvasAspect) {
        ay = ax * canvasAspect / uAspect;
    } else {
        ax = ay * uAspect / canvasAspect;
    }
    float e = pow(abs(p.x) / ax, uBezelN) + pow(abs(p.y) / ay, uBezelN);
    if (e > 1.0) {
        col = vec3(0.0);
    }

    fragColor = vec4(col, 1.0);
}
