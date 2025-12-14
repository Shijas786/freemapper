import Foundation
import Metal
import AVFoundation

enum InputSource {
    case video(url: URL)
    case testPattern(TestPattern)
    case proceduralGenerator(GeneratorType, params: GeneratorParams?)
    case liveCamera(deviceName: String)
    case solidColor(r: Float, g: Float, b: Float)
    case none
}

class InputManager {
    private var videoEngine: VideoEngine?
    private var patternGenerator: TestPatternGenerator
    private var proceduralGenerator: ProceduralGenerator
    private var liveInputManager: LiveInputManager
    private let device: MTLDevice
    
    private(set) var currentSource: InputSource = .none
    private var cachedPatternTexture: MTLTexture?
    
    init(device: MTLDevice) {
        self.device = device
        self.patternGenerator = TestPatternGenerator(device: device)
        self.proceduralGenerator = ProceduralGenerator(device: device)
        self.liveInputManager = LiveInputManager(device: device)
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
            
        case .proceduralGenerator(let type, let params):
            cachedPatternTexture = proceduralGenerator.generateTexture(
                type: type,
                width: 1920,
                height: 1080,
                params: params
            )
            videoEngine = nil
            
        case .liveCamera(let deviceName):
            // Find and start the camera device
            if let device = liveInputManager.availableDevices.first(where: { $0.localizedName == deviceName }) {
                liveInputManager.startCapture(device: device)
            }
            videoEngine = nil
            cachedPatternTexture = nil
            
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
            liveInputManager.stopCapture()
        }
    }
    
    func getCurrentTexture() -> MTLTexture? {
        switch currentSource {
        case .video:
            return videoEngine?.getCurrentTexture()
        case .liveCamera:
            return liveInputManager.getCurrentTexture()
        case .testPattern, .solidColor, .proceduralGenerator:
            return cachedPatternTexture
        case .none:
            return nil
        }
    }
    
    func getSourceName() -> String {
        switch currentSource {
        case .video(let url):
            return url.lastPathComponent
        case .liveCamera(let deviceName):
            return deviceName
        case .testPattern(let pattern):
            switch pattern {
            case .checkerboard: return "Checkerboard"
            case .grid: return "Grid"
            case .colorBars: return "Color Bars"
            case .solidColor: return "Solid Color"
            case .gradient: return "Gradient"
            }
        case .proceduralGenerator(let type, _):
            return type.rawValue
        case .solidColor:
            return "Solid Color"
        case .none:
            return "No Input"
        }
    }
    
    func getLiveInputManager() -> LiveInputManager {
        return liveInputManager
    }
}
