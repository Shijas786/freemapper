import Foundation
import simd

struct Preset: Codable {
    var name: String
    var corners: [Corner]
    
    struct Corner: Codable {
        var x: Float
        var y: Float
    }
    
    static func from(corners: [SIMD2<Float>]) -> Preset {
        return Preset(name: "Untitled", corners: corners.map { Corner(x: $0.x, y: $0.y) })
    }
    
    func toSimd() -> [SIMD2<Float>] {
        return corners.map { SIMD2<Float>($0.x, $0.y) }
    }
}
