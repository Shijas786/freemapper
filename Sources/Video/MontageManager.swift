import Foundation
import AVFoundation
import Metal

// Montage system for timeline-based video composition
struct MontageClip: Identifiable, Codable {
    var id = UUID()
    var name: String
    var sourceURL: URL?
    var startTime: Double // In seconds
    var duration: Double
    var trimStart: Double = 0.0
    var trimEnd: Double = 0.0
    var track: Int = 0
    
    var endTime: Double {
        return startTime + duration
    }
}

struct Montage: Identifiable, Codable {
    var id = UUID()
    var name: String
    var clips: [MontageClip]
    var totalDuration: Double
    var frameRate: Double = 30.0
    var resolution: CGSize = CGSize(width: 1920, height: 1080)
    
    mutating func addClip(_ clip: MontageClip) {
        clips.append(clip)
        updateDuration()
    }
    
    mutating func removeClip(id: UUID) {
        clips.removeAll { $0.id == id }
        updateDuration()
    }
    
    mutating func updateDuration() {
        totalDuration = clips.map { $0.endTime }.max() ?? 0.0
    }
    
    func getClipsAt(time: Double) -> [MontageClip] {
        return clips.filter { clip in
            time >= clip.startTime && time < clip.endTime
        }.sorted { $0.track < $1.track }
    }
}

class MontageManager: ObservableObject {
    @Published var montages: [Montage] = []
    @Published var selectedMontage: Montage?
    @Published var currentTime: Double = 0.0
    @Published var isPlaying: Bool = false
    @Published var playbackSpeed: Double = 1.0
    
    // Timeline settings
    @Published var timelineZoom: Double = 1.0
    @Published var timelineScroll: Double = 0.0
    @Published var snapToFrames: Bool = true
    
    private var displayLink: CVDisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    
    func createMontage(name: String) -> Montage {
        let montage = Montage(
            name: name,
            clips: [],
            totalDuration: 0.0
        )
        montages.append(montage)
        selectedMontage = montage
        return montage
    }
    
    func deleteMontage(id: UUID) {
        montages.removeAll { $0.id == id }
        if selectedMontage?.id == id {
            selectedMontage = montages.first
        }
    }
    
    func addClipToMontage(montageId: UUID, clip: MontageClip) {
        guard let index = montages.firstIndex(where: { $0.id == montageId }) else { return }
        montages[index].addClip(clip)
        selectedMontage = montages[index]
    }
    
    func play() {
        isPlaying = true
        startPlayback()
    }
    
    func pause() {
        isPlaying = false
        stopPlayback()
    }
    
    func stop() {
        isPlaying = false
        currentTime = 0.0
        stopPlayback()
    }
    
    func seek(to time: Double) {
        currentTime = max(0, min(time, selectedMontage?.totalDuration ?? 0))
    }
    
    func stepForward() {
        guard let montage = selectedMontage else { return }
        let frameDuration = 1.0 / montage.frameRate
        seek(to: currentTime + frameDuration)
    }
    
    func stepBackward() {
        guard let montage = selectedMontage else { return }
        let frameDuration = 1.0 / montage.frameRate
        seek(to: currentTime - frameDuration)
    }
    
    private func startPlayback() {
        lastFrameTime = CACurrentMediaTime()
        
        // Use a timer for playback (simplified version)
        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isPlaying else {
                timer.invalidate()
                return
            }
            
            let currentFrameTime = CACurrentMediaTime()
            let deltaTime = currentFrameTime - self.lastFrameTime
            self.lastFrameTime = currentFrameTime
            
            self.currentTime += deltaTime * self.playbackSpeed
            
            if let montage = self.selectedMontage, self.currentTime >= montage.totalDuration {
                self.currentTime = 0.0 // Loop
            }
        }
    }
    
    private func stopPlayback() {
        // Timer will be invalidated automatically
    }
    
    func getCurrentFrame() -> Int {
        guard let montage = selectedMontage else { return 0 }
        return Int(currentTime * montage.frameRate)
    }
    
    func setCurrentFrame(_ frame: Int) {
        guard let montage = selectedMontage else { return }
        currentTime = Double(frame) / montage.frameRate
    }
    
    func exportMontage(montage: Montage, to url: URL, completion: @escaping (Bool) -> Void) {
        // Implementation for exporting montage as video
        // This would use AVAssetExportSession
        completion(true)
    }
}

// Montage renderer - renders the current frame of a montage
class MontageRenderer {
    let device: MTLDevice
    private var videoEngines: [UUID: VideoEngine] = [:]
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    func renderFrame(montage: Montage, time: Double) -> MTLTexture? {
        let clips = montage.getClipsAt(time: time)
        
        guard !clips.isEmpty else { return nil }
        
        // For now, return the texture from the top clip
        // In a full implementation, this would composite multiple clips
        if let topClip = clips.first,
           let sourceURL = topClip.sourceURL {
            
            // Get or create video engine for this clip
            if videoEngines[topClip.id] == nil {
                let engine = VideoEngine()
                engine.load(url: sourceURL)
                videoEngines[topClip.id] = engine
            }
            
            // Seek to the correct time within the clip
            let clipTime = time - topClip.startTime + topClip.trimStart
            videoEngines[topClip.id]?.seek(to: clipTime)
            
            return videoEngines[topClip.id]?.getCurrentTexture()
        }
        
        return nil
    }
    
    func cleanup() {
        videoEngines.removeAll()
    }
}
