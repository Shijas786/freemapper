#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]]; // Screen Space (-1 to 1)
    float2 uv       [[attribute(1)]]; // Texture Space (0 to 1)
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct Uniforms {
    float opacity;
    float edgeSoftness; // 0.0 to 0.5
};

// -----------------------------------------------------------------------------
// GRID WARP SHADER (Alternative to Homography)
// This explicitly interpolates UVs across the triangle mesh.
// This allows for "Curved" convenience by moving internal mesh points.
// -----------------------------------------------------------------------------
vertex VertexOut gridVertex(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.uv = in.uv; // Pass explicit UVs (no perspective divide needed if mesh is dense enough)
    return out;
}

fragment float4 gridFragment(VertexOut in [[stage_in]],
                             texture2d<float> videoTexture [[texture(0)]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    float4 color = videoTexture.sample(s, in.uv);
    
    // EDGE BLENDING (Simple Linear Fade on edges)
    // Calculate distance to nearest edge
    float distL = in.uv.x;
    float distR = 1.0 - in.uv.x;
    float distT = in.uv.y;
    float distB = 1.0 - in.uv.y;
    
    float minDist = min(min(distL, distR), min(distT, distB));
    
    if (minDist < uniforms.edgeSoftness) {
        float alpha = smoothstep(0.0, uniforms.edgeSoftness, minDist);
        color.a *= alpha;
    }
    
    color.a *= uniforms.opacity;
    
    return color;
}

// -----------------------------------------------------------------------------
// POLYGON MASK SHADER (STENCIL)
// Renders flat color, used to write to Stencil Buffer
// -----------------------------------------------------------------------------
vertex float4 maskVertex(uint vertexID [[vertex_id]],
                         constant float2 *positions [[buffer(0)]]) {
    return float4(positions[vertexID], 0.0, 1.0);
}

fragment float4 maskFragment() {
    return float4(1.0, 1.0, 1.0, 1.0); // Color varies, usually we just care about Stencil write
}

// -----------------------------------------------------------------------------
// TEST PATTERN GENERATORS
// -----------------------------------------------------------------------------
struct PatternUniforms {
    int pattern;        // 0=checkerboard, 1=grid, 2=colorBars, 3=solid, 4=gradient
    float2 resolution;
    float3 color;
};

vertex VertexOut patternVertex(uint vertexID [[vertex_id]],
                               constant float2 *positions [[buffer(0)]]) {
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    // Convert NDC to UV
    out.uv = (positions[vertexID] + 1.0) * 0.5;
    return out;
}

fragment float4 patternFragment(VertexOut in [[stage_in]],
                                constant PatternUniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.uv;
    float2 pixel = uv * uniforms.resolution;
    
    // CHECKERBOARD
    if (uniforms.pattern == 0) {
        float checkSize = 32.0;
        float2 check = floor(pixel / checkSize);
        float checker = fmod(check.x + check.y, 2.0);
        return float4(checker, checker, checker, 1.0);
    }
    
    // GRID
    else if (uniforms.pattern == 1) {
        float gridSize = 64.0;
        float2 grid = fmod(pixel, gridSize);
        float lineWidth = 2.0;
        float isLine = step(grid.x, lineWidth) + step(grid.y, lineWidth);
        isLine = min(isLine, 1.0);
        return float4(isLine, isLine, isLine, 1.0);
    }
    
    // COLOR BARS (SMPTE style)
    else if (uniforms.pattern == 2) {
        float bar = floor(uv.x * 7.0);
        float3 colors[7] = {
            float3(1.0, 1.0, 1.0),  // White
            float3(1.0, 1.0, 0.0),  // Yellow
            float3(0.0, 1.0, 1.0),  // Cyan
            float3(0.0, 1.0, 0.0),  // Green
            float3(1.0, 0.0, 1.0),  // Magenta
            float3(1.0, 0.0, 0.0),  // Red
            float3(0.0, 0.0, 1.0)   // Blue
        };
        return float4(colors[int(bar)], 1.0);
    }
    
    // SOLID COLOR
    else if (uniforms.pattern == 3) {
        return float4(uniforms.color, 1.0);
    }
    
    // GRADIENT
    else if (uniforms.pattern == 4) {
        return float4(uv.x, uv.y, 1.0 - uv.x, 1.0);
    }
    
    return float4(0.0, 0.0, 0.0, 1.0);
}

