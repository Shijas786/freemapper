import MetalKit
import simd

class MetalRenderer: NSObject, MTKViewDelegate {
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var gridPipeline: MTLRenderPipelineState?
    var maskPipeline: MTLRenderPipelineState?
    
    // Depth/Stencil State for Masking
    var maskWriteState: MTLDepthStencilState? // Writes 1 to stencil
    var maskReadState: MTLDepthStencilState?  // Reads stencil (Draw only where != 1, or == 0)
    
    var videoEngine: VideoEngine?
    
    // DATA
    var layers: [Layer] = []
    
    struct GridUniforms {
        var opacity: Float
        var edgeSoftness: Float
    }
    
    struct VertexIn {
        var position: SIMD2<Float>
        var uv: SIMD2<Float>
    }
    
    override init() {
        self.device = MTLCreateSystemDefaultDevice()!
        self.commandQueue = device.makeCommandQueue()!
        super.init()
        buildPipeline()
    }
    
    private func buildPipeline() {
        guard let library = device.makeDefaultLibrary() else { return }
        
        // 1. Grid Pipeline
        let gridDesc = MTLRenderPipelineDescriptor()
        gridDesc.label = "Grid Pipeline"
        gridDesc.vertexFunction = library.makeFunction(name: "gridVertex")
        gridDesc.fragmentFunction = library.makeFunction(name: "gridFragment")
        gridDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Alpha Blending
        gridDesc.colorAttachments[0].isBlendingEnabled = true
        gridDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        gridDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        // Stencil Support
        gridDesc.depthAttachmentPixelFormat = .invalid // No depth needed
        gridDesc.stencilAttachmentPixelFormat = .stencil8
        
        // 2. Mask Pipeline
        let maskDesc = MTLRenderPipelineDescriptor()
        maskDesc.label = "Mask Pipeline"
        maskDesc.vertexFunction = library.makeFunction(name: "maskVertex")
        maskDesc.fragmentFunction = library.makeFunction(name: "maskFragment")
        maskDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        maskDesc.colorAttachments[0].writeMask = [] // Don't write color, only Stencil
        maskDesc.stencilAttachmentPixelFormat = .stencil8
        
        do {
            gridPipeline = try device.makeRenderPipelineState(descriptor: gridDesc)
            maskPipeline = try device.makeRenderPipelineState(descriptor: maskDesc)
        } catch { print("Pipeline Error: \(error)") }
        
        // 3. Stencil States
        let maskWriteDesc = MTLDepthStencilDescriptor()
        let writeStencil = MTLStencilDescriptor()
        writeStencil.stencilCompareFunction = .always
        writeStencil.stencilFailureOperation = .keep
        writeStencil.depthFailureOperation = .keep
        writeStencil.depthStencilPassOperation = .replace // Write Ref value
        maskWriteDesc.frontFaceStencil = writeStencil
        maskWriteState = device.makeDepthStencilState(descriptor: maskWriteDesc)
        
        let maskReadDesc = MTLDepthStencilDescriptor()
        let readStencil = MTLStencilDescriptor()
        readStencil.stencilCompareFunction = .notEqual // Draw where stencil != Ref
        readStencil.stencilFailureOperation = .keep
        readStencil.depthFailureOperation = .keep
        readStencil.depthStencilPassOperation = .keep
        maskReadDesc.frontFaceStencil = readStencil
        maskReadState = device.makeDepthStencilState(descriptor: maskReadDesc)
    }
    
    func updateLayers(_ newLayers: [Layer]) {
        self.layers = newLayers
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let gridPSO = gridPipeline,
              let maskPSO = maskPipeline else { return }
        
        // Need Stencil Load Action Clear
        descriptor.stencilAttachment.loadAction = .clear
        descriptor.stencilAttachment.storeAction = .dontCare
        descriptor.stencilAttachment.clearStencil = 0
        
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        
        // --- PASS 1: RENDER MASKS ---
        let maskLayers = layers.filter { $0.isVisible && $0.type == .mask }
        if !maskLayers.isEmpty {
            encoder.setRenderPipelineState(maskPSO)
            encoder.setDepthStencilState(maskWriteState)
            encoder.setStencilReferenceValue(1) // Write 1s
            
            for mask in maskLayers {
                // Triangulate Polygon Fan (Center + Points) or just Triangle Strip?
                // For simplicity v2: Treats control points as a raw triangle list or strip.
                // Assuming simple convex shapes (Triangle Fan-able) or user provides triangles.
                // Let's assume GL_TRIANGLE_STRIP behavior for the points.
                let pts = mask.controlPoints
                if pts.count >= 3 {
                    encoder.setVertexBytes(pts, length: pts.count * MemoryLayout<SIMD2<Float>>.stride, index: 0)
                    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: pts.count)
                }
            }
        }
        
        // --- PASS 2: RENDER VIDEO SURFACES ---
        let videoLayers = layers.filter { $0.isVisible && $0.type == .video }
        
        if let videoTex = videoEngine?.getCurrentTexture() {
            encoder.setRenderPipelineState(gridPSO)
            // Masking Logic: Draw only where Stencil != 1 (i.e. 0). 
            // So Masks "Cut out".
            encoder.setDepthStencilState(maskReadState)
            encoder.setStencilReferenceValue(1) 
            
            encoder.setFragmentTexture(videoTex, index: 0)
            
            for layer in videoLayers {
                // Generate Mesh Geometry from Grid
                // Rows/Cols to Triangle Strip
                // We need to generate UVs alongside Positions
                
                // Simple Tessellation for Grid
                // For a 2x2 grid (1 Quad), we have 2 rows, 2 cols of points.
                // Iterate (row) 0..<rows-1
                //   Iterate (col) 0..<cols
                //     Push Current (r, c)
                //     Push Next (r+1, c)
                // This creates a standard strip.
                // Need degenerate triangles to jump rows if > 1 strip? 
                // Or just draw Primitives per strip. Let's draw prim per row.
                
                for r in 0..<(layer.rows - 1) {
                    var strip: [VertexIn] = []
                    for c in 0..<layer.cols {
                        // Top Point
                        let p1 = layer.controlPoints[r * layer.cols + c]
                        let uv1 = SIMD2<Float>(Float(c) / Float(layer.cols - 1), Float(r) / Float(layer.rows - 1))
                        
                        // Bottom Point
                        let p2 = layer.controlPoints[(r + 1) * layer.cols + c]
                        let uv2 = SIMD2<Float>(Float(c) / Float(layer.cols - 1), Float(r + 1) / Float(layer.rows - 1))
                        
                        strip.append(VertexIn(position: p1, uv: uv1))
                        strip.append(VertexIn(position: p2, uv: uv2))
                    }
                    
                    var uniforms = GridUniforms(opacity: layer.opacity, edgeSoftness: layer.edgeSoftness)
                    
                    encoder.setVertexBytes(strip, length: strip.count * MemoryLayout<VertexIn>.stride, index: 0)
                    // Must index fragment bytes consistently. In shader I put buffer(0). 
                    // Wait, shader Grid has buffer(0) for Uniforms.
                    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GridUniforms>.stride, index: 0)
                    
                    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: strip.count)
                }
            }
        }
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
