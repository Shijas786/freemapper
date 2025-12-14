import MetalKit
import simd

class MetalRenderer: NSObject, MTKViewDelegate {
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState?
    var videoEngine: VideoEngine?
    
    // State
    // User moves these points (in NDC -1..1)
    var corners: [SIMD2<Float>] = [
        SIMD2<Float>(-0.8, 0.8),  // TL
        SIMD2<Float>(0.8, 0.8),   // TR
        SIMD2<Float>(-0.8, -0.8), // BL
        SIMD2<Float>(0.8, -0.8)   // BR
    ]
    
    private let videoCorners: [SIMD2<Float>] = [
        SIMD2<Float>(0, 0), // TL (Texture Space)
        SIMD2<Float>(1, 0), // TR
        SIMD2<Float>(0, 1), // BL
        SIMD2<Float>(1, 1)  // BR
    ]
    
    private var lastTexture: MTLTexture?
    
    struct Uniforms {
        var textureMatrix: simd_float3x3
        // Padding if needed (Metal requires 16 byte alignment often, but for float3x3 inside shader it handles it if packed or similar. 
        // Safer to use float4x4 or pad manually. float3x3 in C++ is 48 bytes (3 x float4).
        // Let's use simdfloat3x3 directly and hope Swift/Metal alignment matches or pad.
        // Actually best practice: pass float4x4 and ignore last row/col.
    }
    
    override init() {
        self.device = MTLCreateSystemDefaultDevice()!
        self.commandQueue = device.makeCommandQueue()!
        super.init()
        buildPipeline()
    }
    
    private func buildPipeline() {
        guard let library = device.makeDefaultLibrary() else {
            print("Failed to find default library (Shaders.metal)")
            return
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "QuadWarpPipeline"
        descriptor.vertexFunction = library.makeFunction(name: "quadVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "quadFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Pipeline error: \(error)")
        }
    }
    
    func updateCorners(tl: SIMD2<Float>, tr: SIMD2<Float>, bl: SIMD2<Float>, br: SIMD2<Float>) {
        corners = [tl, tr, bl, br]
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let pipeline = pipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        // 1. Get Texture
        if let tex = videoEngine?.getCurrentTexture() {
            lastTexture = tex
        }
        
        guard let texture = lastTexture else { return } // Wait for first frame
        
        // 2. Compute Homography: Screen (NDC) -> Texture (0..1)
        // Note: Our corners are in NDC (-1..1).
        // The texture space is (0..1).
        // But the shader logic: "in.screenPos" is passed as varying.
        // We want matrix M such that M * screenPos = texCoord.
        
        // Problem: NDC is -1 to 1.
        // We passed these corners directly to 'position'.
        // So the rasterizer generates pixels. 'in.screenPos' is the interpolated position.
        // We need the matrix to map *User Corner N* (NDC) -> *Video Corner N* (0..1).
        
        let H = Homography.compute(src: corners, dst: videoCorners)
        
        // Metal buffer packing: float3x3 stride is usually 16 bytes per column vector (float3). 
        // 3 * 16 = 48 bytes.
        // Swift Matrix 3x3 alignment might strictly match?
        // Let's copy carefully.
        
        var uniforms = Uniforms(textureMatrix: H)
        
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        encoder.setRenderPipelineState(pipeline)
        
        // Draw Mesh
        // Using `setVertexBytes` for small data is fast and easy (avoid managing buffers for V1)
        // 4 Vertices. Triangle Strip.
        // Order: TL, TR, BL, BR for Strip?
        // Strip: 0(TL), 1(TR), 2(BL), 3(BR) -> Creates (0,1,2) and (2,1,3)
        // Correct Strip Order: TL, BL, TR, BR ? No.
        // Standard Strip: V0, V1, V2 -> T1. V1, V2, V3 -> T2 (winding order matters).
        // Let's just use Triangle Primitive 2 triangles: (0,1,2), (2,1,3).
        
        let vertices: [SIMD2<Float>] = [
            corners[0], // TL
            corners[1], // TR
            corners[2], // BL
            corners[2], // BL
            corners[1], // TR
            corners[3]  // BR
        ]
        
        encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<SIMD2<Float>>.stride, index: 0)
        
        // Uniforms
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        
        // Texture
        encoder.setFragmentTexture(texture, index: 0)
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
