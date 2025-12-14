import Foundation
import simd

// Represents a renderable surface (Video) or a Mask
enum LayerType: String, Codable {
    case video // Standard Quad/Mesh
    case mask  // Cutout
}

struct Layer: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var type: LayerType
    var isVisible: Bool = true
    var opacity: Float = 1.0
    var edgeSoftness: Float = 0.0
    
    // Mesh Data
    var rows: Int
    var cols: Int
    var controlPoints: [SIMD2<Float>] // Row-major order
    
    // Initializer for Quad (2x2 Mesh)
    static func createQuad(name: String) -> Layer {
        return Layer(
            name: name,
            type: .video,
            rows: 2,
            cols: 2,
            controlPoints: [
                SIMD2<Float>(-0.5, 0.5),  // TL
                SIMD2<Float>(0.5, 0.5),   // TR
                SIMD2<Float>(-0.5, -0.5), // BL
                SIMD2<Float>(0.5, -0.5)   // BR
            ]
        )
    }
    
    // Initializer for Mask
    static func createMask(name: String) -> Layer {
        // Default Triangle Mask
        return Layer(
            name: name,
            type: .mask,
            rows: 0,
            cols: 0,
            controlPoints: [
                SIMD2<Float>(0.0, 0.5),
                SIMD2<Float>(0.5, -0.5),
                SIMD2<Float>(-0.5, -0.5)
            ]
        )
    }
}
