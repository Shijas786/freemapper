import AVFoundation
import Metal
import CoreVideo

class VideoEngine: NSObject {
    private var player: AVPlayer?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var textureCache: CVMetalTextureCache?
    
    var isPlaying: Bool { player?.rate != 0 && player?.error == nil }
    
    override init() {
        super.init()
        setupTextureCache()
    }
    
    private func setupTextureCache() {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
    }
    
    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        
        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: settings)
        item.add(videoOutput!)
        
        player = AVPlayer(playerItem: item)
        player?.actionAtItemEnd = .none
        
        // Loop
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemDidReachEnd),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: item)
        
        player?.play()
    }
    
    @objc private func playerItemDidReachEnd(notification: Notification) {
        if let item = notification.object as? AVPlayerItem {
            item.seek(to: .zero, completionHandler: nil)
        }
    }
    
    func getCurrentTexture() -> MTLTexture? {
        guard let output = videoOutput, let cache = textureCache else { return nil }
        
        let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
        
        if output.hasNewPixelBuffer(forItemTime: itemTime) {
            if let pixelBuffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
                // Convert to Metal Texture
                var cvTexture: CVMetalTexture?
                let width = CVPixelBufferGetWidth(pixelBuffer)
                let height = CVPixelBufferGetHeight(pixelBuffer)
                
                let result = CVMetalTextureCacheCreateTextureFromImage(
                    kCFAllocatorDefault,
                    cache,
                    pixelBuffer,
                    nil,
                    .bgra8Unorm,
                    width,
                    height,
                    0,
                    &cvTexture
                )
                
                if result == kCVReturnSuccess, let cvt = cvTexture {
                    return CVMetalTextureGetTexture(cvt)
                }
            }
        }
        return nil // Return last known texture? Ideally we cache last known to avoid black flicker.
    }
}
