import Foundation
import Metal
import AVFoundation

enum InputSource {
    case video(url: URL)
    case testPattern(TestPattern)
    case solidColor(r: Float, g: Float, b: Float)
    case none
}

class InputManager {
    private var videoEngine: VideoEngine?
    private var patternGenerator: TestPatternGenerator
    private let device: MTLDevice
    
    private(set) var currentSource: InputSource = .none
    private var cachedPatternTexture: MTLTexture?
    
    init(device: MTLDevice) {
        self.device = device
        self.patternGenerator = TestPatternGenerator(device: device)
    }
    
    func setSource(_ source: InputSource) {
        currentSource = source
        
        switch source {
        case .video(let url):
            if videoEngine == nil {
                videoEngine = VideoEngine()
            }
            videoEngine?.load(url: url)
            cachedPatternTexture = nil
            
        case .testPattern(let pattern):
            // Generate pattern texture (1920x1080 default)
            cachedPatternTexture = patternGenerator.generateTexture(
                pattern: pattern,
                width: 1920,
                height: 1080
            )
            videoEngine = nil
            
        case .solidColor(let r, let g, let b):
            cachedPatternTexture = patternGenerator.generateTexture(
                pattern: .solidColor(r: r, g: g, b: b),
                width: 256,
                height: 256
            )
            videoEngine = nil
            
        case .none:
            videoEngine = nil
            cachedPatternTexture = nil
        }
    }
    
    func getCurrentTexture() -> MTLTexture? {
        switch currentSource {
        case .video:
            return videoEngine?.getCurrentTexture()
        case .testPattern, .solidColor:
            return cachedPatternTexture
        case .none:
            return nil
        }
    }
    
    func getSourceName() -> String {
        switch currentSource {
        case .video(let url):
            return url.lastPathComponent
        case .testPattern(let pattern):
            switch pattern {
            case .checkerboard: return "Checkerboard"
            case .grid: return "Grid"
            case .colorBars: return "Color Bars"
            case .solidColor: return "Solid Color"
            case .gradient: return "Gradient"
            }
        case .solidColor:
            return "Solid Color"
        case .none:
            return "No Input"
        }
    }
}
