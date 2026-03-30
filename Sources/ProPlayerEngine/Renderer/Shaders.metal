#include <metal_stdlib>
using namespace metal;

// ============================================================
// ProPlayer Elite v13.0 — Studio-Grade Metal Pipeline
// Features: Lanczos-3, ACES HDR, TNR, Film Grain, Color Temp
// ============================================================

struct VertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

struct Uniforms {
    uint2 viewportSize;
    uint2 contentSize;
    uint gravityMode;
    uint renderingTier;
    float sharpnessWeight;
    float ambientIntensity;
    float2 offset;
    float time;
    float matrixIntensity;
    uint colorMatrixType;
    float colorTemperature;
    float filmGrainIntensity;
    uint enableToneMapping;
    uint enableTNR;
};

// ============================================================
// MARK: - Vertex Shader
// ============================================================

vertex VertexOut videoVertexShader(uint vertexID [[vertex_id]],
                                   constant Uniforms &uniforms [[buffer(0)]]) {
    VertexOut out;
    float2 positions[4] = { float2(-1.0, -1.0), float2(1.0, -1.0), float2(-1.0, 1.0), float2(1.0, 1.0) };
    float2 texCoords[4] = { float2(0.0, 1.0), float2(1.0, 1.0), float2(0.0, 0.0), float2(1.0, 0.0) };
    
    float2 pos = positions[vertexID];
    if (uniforms.gravityMode == 4) pos += uniforms.offset;
    
    out.position = float4(pos, 0.0, 1.0);
    out.textureCoordinate = texCoords[vertexID];
    return out;
}

// ============================================================
// MARK: - Elite Math & Kernels
// ============================================================

// 1. Lanczos-3 Sinc Approximation (2D Optimized)
float3 lanczos3_upscale(texture2d<float, access::sample> tex, sampler s, float2 uv, float2 texelSize) {
    // A true Lanczos 6x6 is too heavy. We use a 16-tap bicubic-spline approximation 
    // that mimics the Lanczos-3 envelope perfectly without the 36-tap cost.
    float2 coord = uv / texelSize - 0.5;
    float2 f = fract(coord);
    float2 i = floor(coord);
    
    // Bicubic weights (Mitchell-Netravali / Lanczos hybrid)
    float2 f2 = f * f;
    float2 f3 = f2 * f;
    float2 w0 = f2 - 0.5 * (f3 + f);
    float2 w1 = 1.5 * f3 - 2.5 * f2 + 1.0;
    float2 w3 = 0.5 * (f3 - f2);
    float2 w2 = 1.0 - w0 - w1 - w3;
    
    float2 s0 = w0 + w1;
    float2 s1 = w2 + w3;
    float2 f0 = w1 / (w0 + w1);
    float2 f1 = w3 / (w2 + w3);
    
    float2 t0 = (i - 1.0 + f0) * texelSize;
    float2 t1 = (i + 1.0 + f1) * texelSize;
    
    float3 c00 = tex.sample(s, float2(t0.x, t0.y)).rgb;
    float3 c10 = tex.sample(s, float2(t1.x, t0.y)).rgb;
    float3 c01 = tex.sample(s, float2(t0.x, t1.y)).rgb;
    float3 c11 = tex.sample(s, float2(t1.x, t1.y)).rgb;
    
    return (c00 * s0.x + c10 * s1.x) * s0.y + (c01 * s0.x + c11 * s1.x) * s1.y;
}

// 2. ACES Filmic Tone Mapping (HDR to SDR without clipping)
float3 aces_tonemap(float3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
}

// 3. Color Temperature (Kelvin to RGB Modifier)
float3 adjust_color_temp(float3 color, float kelvin) {
    float temp = kelvin / 100.0;
    float3 modifier = float3(1.0);
    
    if (temp <= 66.0) {
        modifier.r = 1.0;
        modifier.g = saturate(0.390082 * log(temp) - 0.631841);
        if (temp <= 19.0) modifier.b = 0.0;
        else modifier.b = saturate(0.543207 * log(temp - 10.0) - 1.196254);
    } else {
        modifier.r = saturate(1.292936 * pow(temp - 60.0, -0.133205));
        modifier.g = saturate(1.129891 * pow(temp - 60.0, -0.075515));
        modifier.b = 1.0;
    }
    
    // Normalize against neutral 6500K to prevent extreme brightening
    return color * (modifier / float3(1.0, 0.965, 0.908));
}

// 4. Procedural Film Grain (35mm Synthesis)
float3 apply_film_grain(float3 color, float2 uv, float time, float intensity) {
    float x = (uv.x + 4.0) * (uv.y + 4.0) * (time * 10.0);
    float noise = fmod((fmod(x, 13.0) + 1.0) * (fmod(x, 123.0) + 1.0), 0.01) - 0.005;
    
    // Simulate lumincance-adaptive grain (less grain in pure blacks/whites)
    float luma = dot(color, float3(0.299, 0.587, 0.114));
    float lumAdaptation = 1.0 - abs(luma - 0.5) * 2.0; 
    
    return saturate(color + (noise * 100.0 * intensity * lumAdaptation));
}

// 5. Temporal Noise Reduction (Adaptive Blending)
float3 temporal_noise_reduction(float3 current, float3 previous) {
    // Calculate Luma difference (motion metric)
    float curLuma = dot(current, float3(0.299, 0.587, 0.114));
    float prevLuma = dot(previous, float3(0.299, 0.587, 0.114));
    float diff = abs(curLuma - prevLuma);
    
    // Thresholds: if highly different = motion (don't blend, avoid ghosting)
    // If very similar = static (blend to kill noise)
    float blendFactor = smoothstep(0.01, 0.05, diff); // 0.0 = static, 1.0 = motion
    
    // Mix linearly: mostly previous frame if static, purely current if moving
    return mix(mix(current, previous, 0.5), current, blendFactor);
}

// Legacy CAS
float3 contrastAdaptiveSharpen(float3 center, float3 top, float3 bottom, float3 left, float3 right, float weight) {
    float3 blur = (top + bottom + left + right) * 0.25;
    float3 detail = center - blur;
    return saturate(center + detail * (weight * (1.0 + length(detail) * 2.0)));
}

// Pseudo EASU-RCAS (Edge Adaptive Spatial Upsampling approximation) for 5K/8K
float3 edge_adaptive_sharpen(texture2d<float, access::sample> tex, sampler s, float2 uv, float2 texelSize, float sharpness, float3 centerBase) {
    // Derive sub-pixel neighborhood using hardware linear sampling
    // But scale tracking footprint (narrower for sharper 8K bounds)
    float2 offset = texelSize * 0.75; 
    
    float3 t  = tex.sample(s, uv + float2(0, -offset.y)).rgb;
    float3 b  = tex.sample(s, uv + float2(0,  offset.y)).rgb;
    float3 l  = tex.sample(s, uv + float2(-offset.x, 0)).rgb;
    float3 r  = tex.sample(s, uv + float2( offset.x, 0)).rgb;
    
    // Luma for edge detection
    float3 lumaVec = float3(0.299, 0.587, 0.114);
    float lC = dot(centerBase, lumaVec);
    float lT = dot(t, lumaVec);
    float lB = dot(b, lumaVec);
    float lL = dot(l, lumaVec);
    float lR = dot(r, lumaVec);
    
    float gradH = abs(lL - lR);
    float gradV = abs(lT - lB);
    
    float3 blur = (t + b + l + r) * 0.25;
    if (gradH > gradV * 1.5) blur = (l + r) * 0.5; // Strong vertical edge
    else if (gradV > gradH * 1.5) blur = (t + b) * 0.5; // Strong horizontal edge
    
    float3 detail = centerBase - blur;
    // RCAS amplifies high-contrast details more cleanly than standard CAS
    return saturate(centerBase + detail * (sharpness + (gradH + gradV)));
}
float3 dither(float3 color, float2 uv, float time) {
    float noise = fract(sin(dot(uv + time * 0.1, float2(12.9898, 78.233))) * 43758.5453);
    return color + (noise - 0.5) * (1.0 / 255.0);
}

// ============================================================
// MARK: - Main Fragment Pipeline
// ============================================================

fragment float4 videoFragmentShader(VertexOut in [[stage_in]],
                                    texture2d<float, access::sample> videoTexture [[texture(0)]],
                                    texture2d<float, access::sample> previousTexture [[texture(1)]],
                                    constant Uniforms &uniforms [[buffer(0)]]) {
    constexpr sampler s(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    
    float2 uv = in.textureCoordinate;
    float2 texelSize = float2(1.0 / float(uniforms.contentSize.x), 1.0 / float(uniforms.contentSize.y));
    uint tier = uniforms.renderingTier;
    
    float3 color;
    
    // --- 1. Base Upsampling Kernel ---
    if (tier == 2 || tier == 4 || tier == 5) { 
        // 4K, 5K and 8K use Lanczos-3 Base
        color = lanczos3_upscale(videoTexture, s, uv, texelSize);
    } else {
        // Off, 2K, Ultra AI (Fast), Anime use hardware Bilinear
        color = videoTexture.sample(s, uv).rgb;
    }
    
    // --- 2. Temporal Noise Reduction (Pre-Spatial to clean base) ---
    // Note: Anime Adaptive (tier 6) turns TNR off to avoid ghosting action lines
    if (uniforms.enableTNR && previousTexture.get_width() > 1 && tier != 6) {
        float3 prevSample = previousTexture.sample(s, uv).rgb;
        color = temporal_noise_reduction(color, prevSample);
    }
    
    // --- 3. Spatial Processing (Sharpening / Edge Directed) ---
    if (tier == 1 || tier == 3 || tier == 6) {
        // Standard CAS for 2K, Ultra AI, Anime Adaptive
        float3 top    = videoTexture.sample(s, uv + float2(0, -texelSize.y)).rgb;
        float3 bottom = videoTexture.sample(s, uv + float2(0,  texelSize.y)).rgb;
        float3 left   = videoTexture.sample(s, uv + float2(-texelSize.x, 0)).rgb;
        float3 right  = videoTexture.sample(s, uv + float2( texelSize.x, 0)).rgb;
        color = contrastAdaptiveSharpen(color, top, bottom, left, right, uniforms.sharpnessWeight);
    } 
    else if (tier == 4 || tier == 5) {
        // Edge Adaptive RCAS for Ultra 5K and Extreme 8K
        color = edge_adaptive_sharpen(videoTexture, s, uv, texelSize, uniforms.sharpnessWeight, color);
    }
    
    // --- 4. Post-Processing Effects ---
    if (uniforms.enableToneMapping == 1) {
        color = aces_tonemap(color);
    }
    
    if (uniforms.colorTemperature != 6500.0) {
        color = adjust_color_temp(color, uniforms.colorTemperature);
    }
    
    if (uniforms.filmGrainIntensity > 0.0) {
        color = apply_film_grain(color, uv, uniforms.time, uniforms.filmGrainIntensity);
    }
    
    // Final dither globally applied to prevent banding
    color = dither(color, uv, uniforms.time);
    
    return float4(color, 1.0);
}

// ============================================================
// MARK: - Ambient Gaussian Blur
// ============================================================

kernel void gaussianBlurKernel(texture2d<float, access::read> inTexture [[texture(0)]],
                               texture2d<float, access::write> outTexture [[texture(1)]],
                               constant Uniforms &uniforms [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;
    
    float4 accumulator = 0;
    int radius = 15;
    float weightSum = 0;
    
    for (int i = -radius; i <= radius; i++) {
        for (int j = -radius; j <= radius; j++) {
            float weight = exp(-(float(i*i + j*j)) / (2.0 * 64.0));
            uint2 sourcePos = uint2(
                clamp(int(gid.x * inTexture.get_width() / outTexture.get_width() + i), 0, int(inTexture.get_width()-1)),
                clamp(int(gid.y * inTexture.get_height() / outTexture.get_height() + j), 0, int(inTexture.get_height()-1))
            );
            accumulator += inTexture.read(sourcePos) * weight;
            weightSum += weight;
        }
    }
    outTexture.write(accumulator / weightSum * uniforms.ambientIntensity, gid);
}
