import SwiftUI
import AVFoundation

struct LiveInputsPanel: View {
    @ObservedObject var liveInputManager: LiveInputManager
    let onSelectCamera: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Live Inputs")
                    .font(.subheadline)
                    .bold()
                Spacer()
                Button("+") {
                    liveInputManager.discoverDevices()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            
            // Camera devices grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(liveInputManager.availableDevices, id: \.uniqueID) { device in
                    CameraDeviceCard(
                        device: device,
                        isSelected: liveInputManager.selectedDevice?.uniqueID == device.uniqueID,
                        isRunning: liveInputManager.isRunning && liveInputManager.selectedDevice?.uniqueID == device.uniqueID,
                        onSelect: {
                            onSelectCamera(device.localizedName)
                        }
                    )
                }
            }
            
            // Selected camera info
            if let device = liveInputManager.selectedDevice {
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(device.localizedName)
                        .font(.caption)
                        .bold()
                    
                    HStack {
                        Text("Preview:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Toggle("", isOn: $liveInputManager.isRunning)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .scaleEffect(0.7)
                            .onChange(of: liveInputManager.isRunning) { running in
                                if running {
                                    liveInputManager.startCapture(device: device)
                                } else {
                                    liveInputManager.stopCapture()
                                }
                            }
                    }
                    
                    // Video Format
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Video Format")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $liveInputManager.videoFormat) {
                            Text("3840 × 2160").tag("3840 × 2160")
                            Text("1920 × 1080").tag("1920 × 1080")
                            Text("1280 × 720").tag("1280 × 720")
                            Text("640 × 480").tag("640 × 480")
                        }
                        .labelsHidden()
                        .font(.caption2)
                        .onChange(of: liveInputManager.videoFormat) { format in
                            liveInputManager.setVideoFormat(format)
                        }
                        
                        Toggle("Keep running (uses more CPU)", isOn: $liveInputManager.keepRunning)
                            .font(.caption2)
                    }
                    
                    // Flip controls
                    HStack(spacing: 16) {
                        Button(action: { liveInputManager.toggleFlipHorizontal() }) {
                            Image(systemName: "arrow.left.and.right")
                                .foregroundColor(liveInputManager.flipHorizontal ? .blue : .gray)
                        }
                        .buttonStyle(.borderless)
                        .help("Flip Horizontal")
                        
                        Button(action: { liveInputManager.toggleFlipVertical() }) {
                            Image(systemName: "arrow.up.and.down")
                                .foregroundColor(liveInputManager.flipVertical ? .blue : .gray)
                        }
                        .buttonStyle(.borderless)
                        .help("Flip Vertical")
                    }
                    .font(.caption)
                    
                    // Color Profile
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Color Profile")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $liveInputManager.colorProfile) {
                            Text("Auto").tag("Auto")
                            Text("sRGB").tag("sRGB")
                            Text("Display P3").tag("Display P3")
                            Text("Rec. 709").tag("Rec. 709")
                        }
                        .labelsHidden()
                        .font(.caption2)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
        }
    }
}

struct CameraDeviceCard: View {
    let device: AVCaptureDevice
    let isSelected: Bool
    let isRunning: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: deviceIcon)
                .font(.title2)
                .foregroundColor(isRunning ? .green : .gray)
            
            Text(shortName)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.1))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onSelect()
        }
    }
    
    var deviceIcon: String {
        let name = device.localizedName.lowercased()
        if name.contains("macbook") || name.contains("facetime") {
            return "video.fill"
        } else if name.contains("camera") {
            return "camera.fill"
        } else {
            return "video.circle.fill"
        }
    }
    
    var shortName: String {
        let name = device.localizedName
        if name.contains("MacBook Pro Camera") {
            return "MacBook\nCamera"
        } else if name.contains("Video-Output") {
            return "Video\nOutput"
        }
        return name
    }
}
