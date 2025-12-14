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

// -----------------------------------------------------------------------------
// ADVANCED PROCEDURAL GENERATORS (MadMapper-style)
// -----------------------------------------------------------------------------
struct GeneratorParams {
    int type;
    float2 resolution;
    float time;
    float cellsX;
    float cellsY;
    float lineWidth;
    float2 translation;
    float rotation;
    float smooth;
    float repeat;
    float3 color1;
    float3 color2;
    float bpmSync;
    float speed;
};

// Noise functions
float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

vertex VertexOut generatorVertex(uint vertexID [[vertex_id]],
                                 constant float2 *positions [[buffer(0)]]) {
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = (positions[vertexID] + 1.0) * 0.5;
    return out;
}

fragment float4 generatorFragment(VertexOut in [[stage_in]],
                                  constant GeneratorParams &p [[buffer(0)]]) {
    float2 uv = in.uv;
    float2 pixel = uv * p.resolution;
    
    // Apply transformation
    float2 center = float2(0.5, 0.5);
    uv -= center;
    float c = cos(p.rotation);
    float s = sin(p.rotation);
    uv = float2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
    uv += center + p.translation;
    
    // 0: Solid Color
    if (p.type == 0) {
        return float4(p.color1, 1.0);
    }
    
    // 1: Color Patterns (Checkerboard with colors)
    else if (p.type == 1) {
        float2 cell = floor(uv * float2(p.cellsX, p.cellsY));
        float checker = fmod(cell.x + cell.y, 2.0);
        float3 color = mix(p.color1, p.color2, checker);
        return float4(color, 1.0);
    }
    
    // 2: Grid Generator
    else if (p.type == 2) {
        float2 grid = fmod(uv * float2(p.cellsX, p.cellsY), 1.0);
        float line = step(grid.x, p.lineWidth) + step(grid.y, p.lineWidth);
        line = min(line, 1.0);
        float3 color = mix(p.color2, p.color1, line);
        return float4(color, 1.0);
    }
    
    // 5: Gradient Color
    else if (p.type == 5) {
        float3 color = mix(p.color1, p.color2, uv.x);
        return float4(color, 1.0);
    }
    
    // 6: Strob (Flash effect)
    else if (p.type == 6) {
        float flash = step(0.5, fract(p.time * p.speed));
        float3 color = mix(p.color2, p.color1, flash);
        return float4(color, 1.0);
    }
    
    // 7: Shapes (Circle)
    else if (p.type == 7) {
        float dist = length(uv - float2(0.5, 0.5));
        float circle = smoothstep(0.3, 0.3 - p.smooth, dist);
        float3 color = mix(p.color1, p.color2, circle);
        return float4(color, 1.0);
    }
    
    // 11: LineRepeat
    else if (p.type == 11) {
        float lines = fmod(uv.y * p.cellsY + p.time * p.speed, 1.0);
        float line = smoothstep(p.lineWidth, p.lineWidth + p.smooth, lines);
        float3 color = mix(p.color1, p.color2, line);
        return float4(color, 1.0);
    }
    
    // 12: SquareArray
    else if (p.type == 12) {
        float2 cell = fmod(uv * float2(p.cellsX, p.cellsY), 1.0);
        float2 center = abs(cell - 0.5);
        float square = max(center.x, center.y);
        square = smoothstep(0.3, 0.3 - p.smooth, square);
        float3 color = mix(p.color2, p.color1, square);
        return float4(color, 1.0);
    }
    
    // 13: Siren (Rotating gradient)
    else if (p.type == 13) {
        float angle = atan2(uv.y - 0.5, uv.x - 0.5);
        float siren = fract((angle / 6.28318) * p.repeat + p.time * p.speed);
        float3 color = mix(p.color1, p.color2, siren);
        return float4(color, 1.0);
    }
    
    // 14: Dunes (Sine waves)
    else if (p.type == 14) {
        float wave = sin(uv.x * p.cellsX + p.time * p.speed) * 0.5 + 0.5;
        float3 color = mix(p.color1, p.color2, wave);
        return float4(color, 1.0);
    }
    
    // 15: Bar Code
    else if (p.type == 15) {
        float bar = step(0.5, fract(uv.x * p.cellsX));
        float3 color = mix(p.color2, p.color1, bar);
        return float4(color, 1.0);
    }
    
    // 16: Bricks
    else if (p.type == 16) {
        float2 brick = uv * float2(p.cellsX, p.cellsY);
        brick.x += step(1.0, fmod(brick.y, 2.0)) * 0.5;
        float2 brickId = floor(brick);
        float2 brickUV = fract(brick);
        float mortar = step(brickUV.x, p.lineWidth) + step(brickUV.y, p.lineWidth);
        mortar = min(mortar, 1.0);
        float3 color = mix(p.color1, p.color2, mortar);
        return float4(color, 1.0);
    }
    
    // 17: Clouds (FBM Noise)
    else if (p.type == 17) {
        float cloud = fbm(uv * p.cellsX + p.time * p.speed * 0.1);
        float3 color = mix(p.color1, p.color2, cloud);
        return float4(color, 1.0);
    }
    
    // 18: Random
    else if (p.type == 18) {
        float2 cell = floor(uv * float2(p.cellsX, p.cellsY));
        float rnd = hash(cell + floor(p.time * p.speed));
        float3 color = mix(p.color1, p.color2, rnd);
        return float4(color, 1.0);
    }
    
    // 19: Noisy Barcode
    else if (p.type == 19) {
        float bar = step(0.5, fract(uv.x * p.cellsX + noise(uv * 10.0) * 0.1));
        float3 color = mix(p.color2, p.color1, bar);
        return float4(color, 1.0);
    }
    
    // 20: Caustics (Water-like)
    else if (p.type == 20) {
        float2 p1 = uv * p.cellsX + p.time * p.speed * 0.1;
        float caustic = sin(p1.x + sin(p1.y)) + sin(p1.y + sin(p1.x));
        caustic = caustic * 0.25 + 0.5;
        float3 color = mix(p.color1, p.color2, caustic);
        return float4(color, 1.0);
    }
    
    // 21: SquareWave
    else if (p.type == 21) {
        float wave = step(0.5, fract(uv.y * p.cellsY + p.time * p.speed));
        float3 color = mix(p.color1, p.color2, wave);
        return float4(color, 1.0);
    }
    
    // 22: CubicCircles
    else if (p.type == 22) {
        float2 cell = fmod(uv * float2(p.cellsX, p.cellsY), 1.0);
        float dist = length(cell - 0.5);
        float circle = fract(dist * p.repeat - p.time * p.speed);
        circle = smoothstep(0.5, 0.5 - p.smooth, circle);
        float3 color = mix(p.color2, p.color1, circle);
        return float4(color, 1.0);
    }
    
    // 23: Diagonals
    else if (p.type == 23) {
        float diag = fract((uv.x + uv.y) * p.cellsX);
        float line = step(0.5, diag);
        float3 color = mix(p.color1, p.color2, line);
        return float4(color, 1.0);
    }
    
    // 9: MadNoise
    else if (p.type == 9) {
        float n = noise(uv * p.cellsX + p.time * p.speed * 0.1);
        float3 color = mix(p.color1, p.color2, n);
        return float4(color, 1.0);
    }
    
    // 10: Sphere
    else if (p.type == 10) {
        float2 centered = (uv - 0.5) * 2.0;
        float dist = length(centered);
        float sphere = sqrt(max(0.0, 1.0 - dist * dist));
        float3 color = mix(p.color2, p.color1 * sphere, step(dist, 1.0));
        return float4(color, 1.0);
    }
    
    return float4(0.0, 0.0, 0.0, 1.0);
}

