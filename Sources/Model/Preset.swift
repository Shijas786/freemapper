import Foundation
import simd

struct Preset: Codable {
    var name: String
    var layers: [Layer]
    
    struct Corner: Codable {
        var x: Float
        var y: Float
    }
}
