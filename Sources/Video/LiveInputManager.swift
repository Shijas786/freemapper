import AVFoundation
import Metal
import CoreVideo

class LiveInputManager: NSObject, ObservableObject {
    @Published var availableDevices: [AVCaptureDevice] = []
    @Published var selectedDevice: AVCaptureDevice?
    @Published var isRunning: Bool = false
    @Published var videoFormat: String = "1920 × 1080"
    @Published var keepRunning: Bool = false
    @Published var flipHorizontal: Bool = false
    @Published var flipVertical: Bool = false
    @Published var colorProfile: String = "Auto"
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var textureCache: CVMetalTextureCache?
    private let device: MTLDevice
    private var currentTexture: MTLTexture?
    
    private let sessionQueue = DispatchQueue(label: "com.auromapper.camera")
    
    init(device: MTLDevice) {
        self.device = device
        super.init()
        
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        discoverDevices()
    }
    
    func discoverDevices() {
        // Discover all video input devices
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .externalUnknown,
                .deskViewCamera
            ],
            mediaType: .video,
            position: .unspecified
        )
        
        availableDevices = discoverySession.devices
        
        // Select default device (usually MacBook Pro Camera)
        if selectedDevice == nil {
            selectedDevice = availableDevices.first
        }
    }
    
    func startCapture(device: AVCaptureDevice) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.stopCapture()
            
            let session = AVCaptureSession()
            
            do {
                // Add input
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                }
                
                // Configure session preset based on selected format
                session.sessionPreset = self.getSessionPreset()
                
                // Add output
                let output = AVCaptureVideoDataOutput()
                output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferMetalCompatibilityKey as String: true
                ]
                output.setSampleBufferDelegate(self, queue: self.sessionQueue)
                
                if session.canAddOutput(output) {
                    session.addOutput(output)
                }
                
                self.videoOutput = output
                self.captureSession = session
                
                session.startRunning()
                
                DispatchQueue.main.async {
                    self.isRunning = true
                    self.selectedDevice = device
                }
                
            } catch {
                print("Camera error: \(error)")
            }
        }
    }
    
    func stopCapture() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            self?.captureSession = nil
            self?.videoOutput = nil
            
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }
    }
    
    func getCurrentTexture() -> MTLTexture? {
        return currentTexture
    }
    
    private func getSessionPreset() -> AVCaptureSession.Preset {
        switch videoFormat {
        case "3840 × 2160": return .hd4K3840x2160
        case "1920 × 1080": return .hd1920x1080
        case "1280 × 720": return .hd1280x720
        case "640 × 480": return .vga640x480
        default: return .hd1920x1080
        }
    }
    
    func setVideoFormat(_ format: String) {
        videoFormat = format
        if isRunning, let device = selectedDevice {
            startCapture(device: device)
        }
    }
    
    func toggleFlipHorizontal() {
        flipHorizontal.toggle()
    }
    
    func toggleFlipVertical() {
        flipVertical.toggle()
    }
}

extension LiveInputManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let cache = textureCache else { return }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var cvTexture: CVMetalTexture?
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
            currentTexture = CVMetalTextureGetTexture(cvt)
        }
    }
}
