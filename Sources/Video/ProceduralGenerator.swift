import Foundation
import Metal

// Advanced procedural generators inspired by MadMapper
enum GeneratorType: String, CaseIterable {
    // Basic Generators
    case solidColor = "Solid Color"
    case colorPatterns = "Color Patterns"
    case gridGenerator = "Grid Generator"
    case textGenerator = "Text Generator"
    case testCard = "Test Card"
    
    // Materials
    case gradientColor = "Gradient Color"
    case strob = "Strob"
    case shapes = "Shapes"
    case linePatterns = "Line Patterns"
    case madNoise = "MadNoise"
    case sphere = "Sphere"
    
    // Line Patterns
    case lineRepeat = "LineRepeat"
    case squareArray = "SquareArray"
    case siren = "Siren"
    case dunes = "Dunes"
    case barCode = "Bar Code"
    case bricks = "Bricks"
    case clouds = "Clouds"
    case random = "Random"
    case noisyBarcode = "Noisy Barcode"
    case caustics = "Caustics"
    case squareWave = "SquareWave"
    case cubicCircles = "CubicCircles"
    case diagonals = "Diagonals"
}

struct GeneratorParams {
    var type: Int32
    var resolution: SIMD2<Float>
    var time: Float
    
    // Pattern controls
    var cellsX: Float = 1.0
    var cellsY: Float = 1.0
    var lineWidth: Float = 0.1
    var translation: SIMD2<Float> = SIMD2<Float>(0, 0)
    var rotation: Float = 0.0
    var smooth: Float = 0.0
    var repeat: Float = 1.0
    
    // Colors
    var color1: SIMD3<Float> = SIMD3<Float>(1, 1, 1)
    var color2: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    
    // Animation
    var bpmSync: Float = 0.0
    var speed: Float = 1.0
}

class ProceduralGenerator {
    let device: MTLDevice
    var pipelineState: MTLRenderPipelineState?
    private var startTime: CFAbsoluteTime
    
    init(device: MTLDevice) {
        self.device = device
        self.startTime = CFAbsoluteTimeGetCurrent()
        buildPipeline()
    }
    
    private func buildPipeline() {
        guard let library = device.makeDefaultLibrary() else { return }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "generatorVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "generatorFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Generator pipeline error: \(error)")
        }
    }
    
    func generateTexture(type: GeneratorType, width: Int, height: Int, params: GeneratorParams? = nil) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .renderTarget]
        
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        guard let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let pipeline = pipelineState else { return nil }
        
        encoder.setRenderPipelineState(pipeline)
        
        var uniforms = params ?? GeneratorParams(
            type: typeToInt(type),
            resolution: SIMD2<Float>(Float(width), Float(height)),
            time: Float(CFAbsoluteTimeGetCurrent() - startTime)
        )
        
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GeneratorParams>.stride, index: 0)
        
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
    
    private func typeToInt(_ type: GeneratorType) -> Int32 {
        switch type {
        case .solidColor: return 0
        case .colorPatterns: return 1
        case .gridGenerator: return 2
        case .textGenerator: return 3
        case .testCard: return 4
        case .gradientColor: return 5
        case .strob: return 6
        case .shapes: return 7
        case .linePatterns: return 8
        case .madNoise: return 9
        case .sphere: return 10
        case .lineRepeat: return 11
        case .squareArray: return 12
        case .siren: return 13
        case .dunes: return 14
        case .barCode: return 15
        case .bricks: return 16
        case .clouds: return 17
        case .random: return 18
        case .noisyBarcode: return 19
        case .caustics: return 20
        case .squareWave: return 21
        case .cubicCircles: return 22
        case .diagonals: return 23
        }
    }
}
