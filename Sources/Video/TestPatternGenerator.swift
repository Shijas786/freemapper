import Foundation
import Metal
import CoreGraphics

enum TestPattern {
    case checkerboard
    case grid
    case colorBars
    case solidColor(r: Float, g: Float, b: Float)
    case gradient
}

class TestPatternGenerator {
    let device: MTLDevice
    var pipelineState: MTLRenderPipelineState?
    
    init(device: MTLDevice) {
        self.device = device
        buildPipeline()
    }
    
    private func buildPipeline() {
        guard let library = device.makeDefaultLibrary() else { return }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "patternVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "patternFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Pattern pipeline error: \(error)")
        }
    }
    
    func generateTexture(pattern: TestPattern, width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .renderTarget]
        
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        
        // Render pattern to texture
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        guard let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let pipeline = pipelineState else { return nil }
        
        encoder.setRenderPipelineState(pipeline)
        
        // Pattern-specific uniforms
        var uniforms = PatternUniforms(
            pattern: patternType(pattern),
            resolution: SIMD2<Float>(Float(width), Float(height)),
            color: patternColor(pattern)
        )
        
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<PatternUniforms>.stride, index: 0)
        
        // Full-screen quad
        let vertices: [SIMD2<Float>] = [
            SIMD2(-1, -1), SIMD2(1, -1), SIMD2(-1, 1),
            SIMD2(-1, 1), SIMD2(1, -1), SIMD2(1, 1)
        ]
        
        encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<SIMD2<Float>>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return texture
    }
    
    private func patternType(_ pattern: TestPattern) -> Int32 {
        switch pattern {
        case .checkerboard: return 0
        case .grid: return 1
        case .colorBars: return 2
        case .solidColor: return 3
        case .gradient: return 4
        }
    }
    
    private func patternColor(_ pattern: TestPattern) -> SIMD3<Float> {
        switch pattern {
        case .solidColor(let r, let g, let b):
            return SIMD3<Float>(r, g, b)
        default:
            return SIMD3<Float>(1, 1, 1)
        }
    }
    
    struct PatternUniforms {
        var pattern: Int32
        var resolution: SIMD2<Float>
        var color: SIMD3<Float>
    }
}
