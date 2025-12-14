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
