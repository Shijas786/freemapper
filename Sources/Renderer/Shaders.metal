#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]]; // User-defined corner in NDC (-1 to 1)
};

struct VertexOut {
    float4 position [[position]];
    float2 screenPos; // Passed to frag for inverse mapping
};

struct Uniforms {
    float3x3 textureMatrix; // Maps Screen Space -> Texture Space (Inverse Homography)
};

vertex VertexOut quadVertex(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.screenPos = in.position; // Standard NDC
    return out;
}

fragment float4 quadFragment(VertexOut in [[stage_in]],
                             texture2d<float> videoTexture [[texture(0)]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    // Perspective correction: Map Screen(x,y) back to Texture(u,v) using Homography
    float3 texCoordProj = uniforms.textureMatrix * float3(in.screenPos, 1.0);
    
    // Perspective divide
    float2 uv = texCoordProj.xy / texCoordProj.z;
    
    // Check bounds (optional, if we render strictly inside the geometry this acts as cropping)
    // But since we render the geometry defined by user, we should be strictly inside.
    // However, math might drift slightly, so clamp.
    
    // Flip Y if needed (AVFoundation textures are often top-down or bottom-up depending on origin)
    // We assume standard 0..1 UV where (0,0) is top-left.
    
    return videoTexture.sample(s, uv);
}
