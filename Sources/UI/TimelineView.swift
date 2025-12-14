import SwiftUI

struct TimelineView: View {
    @ObservedObject var montageManager: MontageManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Timeline header with controls
            TimelineHeader(montageManager: montageManager)
            
            Divider()
            
            // Timeline ruler and tracks
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    VStack(spacing: 0) {
                        // Time ruler
                        TimeRuler(
                            duration: montageManager.selectedMontage?.totalDuration ?? 60.0,
                            currentTime: montageManager.currentTime,
                            zoom: montageManager.timelineZoom,
                            width: geometry.size.width
                        )
                        
                        // Tracks
                        if let montage = montageManager.selectedMontage {
                            TimelineTracks(
                                montage: montage,
                                currentTime: montageManager.currentTime,
                                zoom: montageManager.timelineZoom,
                                onSeek: { time in
                                    montageManager.seek(to: time)
                                }
                            )
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct TimelineHeader: View {
    @ObservedObject var montageManager: MontageManager
    
    var body: some View {
        HStack(spacing: 8) {
            // Playback controls
            HStack(spacing: 4) {
                Button(action: { montageManager.stop() }) {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.borderless)
                .help("Stop")
                
                Button(action: { montageManager.stepBackward() }) {
                    Image(systemName: "backward.frame.fill")
                }
                .buttonStyle(.borderless)
                .help("Previous Frame")
                
                Button(action: {
                    if montageManager.isPlaying {
                        montageManager.pause()
                    } else {
                        montageManager.play()
                    }
                }) {
                    Image(systemName: montageManager.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderless)
                .help(montageManager.isPlaying ? "Pause" : "Play")
                
                Button(action: { montageManager.stepForward() }) {
                    Image(systemName: "forward.frame.fill")
                }
                .buttonStyle(.borderless)
                .help("Next Frame")
            }
            
            Divider()
            
            // Timecode display
            Text(formatTimecode(montageManager.currentTime))
                .font(.system(.body, design: .monospaced))
                .frame(width: 100)
            
            Text("/ \(formatTimecode(montageManager.selectedMontage?.totalDuration ?? 0))")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            
            Divider()
            
            // Frame counter
            Text("Frame: \(montageManager.getCurrentFrame())")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Zoom controls
            HStack(spacing: 4) {
                Button(action: { montageManager.timelineZoom = max(0.1, montageManager.timelineZoom - 0.1) }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                
                Slider(value: $montageManager.timelineZoom, in: 0.1...5.0)
                    .frame(width: 100)
                
                Button(action: { montageManager.timelineZoom = min(5.0, montageManager.timelineZoom + 0.1) }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.borderless)
            }
            
            Toggle("Snap", isOn: $montageManager.snapToFrames)
                .font(.caption)
        }
        .padding(8)
    }
    
    func formatTimecode(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let frames = Int((seconds - Double(Int(seconds))) * 30) // Assuming 30fps
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, secs, frames)
    }
}

struct TimeRuler: View {
    let duration: Double
    let currentTime: Double
    let zoom: Double
    let width: CGFloat
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background
            Rectangle()
                .fill(Color(NSColor.controlBackgroundColor))
                .frame(height: 30)
            
            // Time markers
            Canvas { context, size in
                let pixelsPerSecond = 50.0 * zoom
                let _ = duration * pixelsPerSecond
                
                for second in 0...Int(duration) {
                    let x = CGFloat(Double(second) * pixelsPerSecond)
                    
                    // Major tick every second
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: size.height - 10))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(.gray), lineWidth: 1)
                    
                    // Time label
                    let text = Text("\(second)s")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    context.draw(text, at: CGPoint(x: x + 2, y: 5))
                }
            }
            .frame(width: max(width, CGFloat(duration * 50.0 * zoom)), height: 30)
            
            // Playhead
            Rectangle()
                .fill(Color.cyan)
                .frame(width: 2)
                .offset(x: CGFloat(currentTime * 50.0 * zoom))
        }
    }
}

struct TimelineTracks: View {
    let montage: Montage
    let currentTime: Double
    let zoom: Double
    let onSeek: (Double) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<4) { trackIndex in
                TimelineTrack(
                    trackIndex: trackIndex,
                    clips: montage.clips.filter { $0.track == trackIndex },
                    duration: montage.totalDuration,
                    currentTime: currentTime,
                    zoom: zoom,
                    onSeek: onSeek
                )
                Divider()
            }
        }
    }
}

struct TimelineTrack: View {
    let trackIndex: Int
    let clips: [MontageClip]
    let duration: Double
    let currentTime: Double
    let zoom: Double
    let onSeek: (Double) -> Void
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Track background
            Rectangle()
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .frame(height: 60)
            
            // Clips
            ForEach(clips) { clip in
                ClipView(clip: clip, zoom: zoom)
                    .offset(x: CGFloat(clip.startTime * 50.0 * zoom))
            }
            
            // Playhead
            Rectangle()
                .fill(Color.cyan.opacity(0.3))
                .frame(width: 2)
                .offset(x: CGFloat(currentTime * 50.0 * zoom))
        }
        .frame(width: max(600, CGFloat(duration * 50.0 * zoom)), height: 60)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let time = Double(value.location.x) / (50.0 * zoom)
                    onSeek(time)
                }
        )
    }
}

struct ClipView: View {
    let clip: MontageClip
    let zoom: Double
    
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.blue.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.blue, lineWidth: 2)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(clip.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(formatDuration(clip.duration))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(4)
        }
        .frame(width: CGFloat(clip.duration * 50.0 * zoom), height: 50)
    }
    
    func formatDuration(_ seconds: Double) -> String {
        return String(format: "%.2fs", seconds)
    }
}

// Montage panel for managing montages
struct MontagePanel: View {
    @ObservedObject var montageManager: MontageManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Montages")
                    .font(.subheadline)
                    .bold()
                Spacer()
                Button("+") {
                    let name = "Montage-\(montageManager.montages.count + 1)"
                    let _ = montageManager.createMontage(name: name)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(montageManager.montages) { montage in
                        MontageCard(
                            montage: montage,
                            isSelected: montageManager.selectedMontage?.id == montage.id,
                            onSelect: {
                                montageManager.selectedMontage = montage
                            }
                        )
                    }
                }
            }
            .frame(height: 150)
        }
    }
}

struct MontageCard: View {
    let montage: Montage
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "film")
                    .foregroundColor(.blue)
                Text(montage.name)
                    .font(.caption)
                Spacer()
            }
            
            Text("\(montage.clips.count) clips • \(formatDuration(montage.totalDuration))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(6)
        .background(isSelected ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.1))
        .cornerRadius(4)
        .onTapGesture {
            onSelect()
        }
    }
    
    func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
