import SwiftUI
import MetalKit

class MappingViewModel: ObservableObject {
    @Published var screens: [NSScreen] = NSScreen.screens
    @Published var selectedScreenIndex: Int = 0
    @Published var isOutputActive: Bool = false
    
    // Corners in Normalized Coordinates (0..1 relative to canvas, mapped to -1..1 for Metal)
    @Published var cornerTL: CGPoint = CGPoint(x: 0.1, y: 0.1)
    @Published var cornerTR: CGPoint = CGPoint(x: 0.9, y: 0.1)
    @Published var cornerBL: CGPoint = CGPoint(x: 0.1, y: 0.9)
    @Published var cornerBR: CGPoint = CGPoint(x: 0.9, y: 0.9)
    
    var renderer = MetalRenderer()
    var outputWindowController: OutputWindowController?
    var videoEngine = VideoEngine()
    
    init() {
        renderer.videoEngine = videoEngine
        updateRenderer()
    }
    
    func loadVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .quickTimeMovie, .mpeg4Movie]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.videoEngine.load(url: url)
            }
        }
    }
    
    func toggleOutput() {
        if isOutputActive {
            outputWindowController?.close()
            outputWindowController = nil
            isOutputActive = false
        } else {
            reloadScreens()
            let screen = screens.indices.contains(selectedScreenIndex) ? screens[selectedScreenIndex] : NSScreen.main!
            outputWindowController = OutputWindowController(screen: screen, renderer: renderer)
            outputWindowController?.show()
            isOutputActive = true
        }
    }
    
    func reloadScreens() {
        screens = NSScreen.screens
    }
    
    func updateRenderer() {
        // Map 0..1 UI coordinates to -1..1 NDC
        // Y is usually flipped in UI vs Metal? 
        // SwiftUI: (0,0) TopLeft.
        // Metal NDC: (-1, 1) TopLeft.
        // x: 0 -> -1, 1 -> 1  => x * 2 - 1
        // y: 0 -> 1, 1 -> -1  => (1 - y) * 2 - 1  OR  1 - 2y
        
        let tl = SIMD2<Float>(Float(cornerTL.x * 2 - 1), Float(1 - cornerTL.y * 2))
        let tr = SIMD2<Float>(Float(cornerTR.x * 2 - 1), Float(1 - cornerTR.y * 2))
        let bl = SIMD2<Float>(Float(cornerBL.x * 2 - 1), Float(1 - cornerBL.y * 2))
        let br = SIMD2<Float>(Float(cornerBR.x * 2 - 1), Float(1 - cornerBR.y * 2))
        
        renderer.updateCorners(tl: tl, tr: tr, bl: bl, br: br)
    }
    
    func savePreset() {
        // JSON saving logic using Preset struct
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                // ... Implementation
            }
        }
    }
}

struct ControlPanel: View {
    @StateObject var vm = MappingViewModel()
    
    var body: some View {
        HSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 20) {
                Text("AuroraMapper v1").font(.headline)
                
                Divider()
                
                Text("Video Input").font(.subheadline)
                Button("Load Video") { vm.loadVideo() }
                
                Divider()
                
                Text("Output Display").font(.subheadline)
                Picker("Screen", selection: $vm.selectedScreenIndex) {
                    ForEach(0..<vm.screens.count, id: \.self) { i in
                        Text(vm.screens[i].localizedName)
                    }
                }
                
                Button(vm.isOutputActive ? "Stop Output" : "Start Output") {
                    vm.toggleOutput()
                }
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 200, maxWidth: 250)
            
            // Editor Canvas
            ZStack {
                Color.gray.opacity(0.2)
                
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    
                    // Connecting Lines
                    Path { path in
                        path.move(to: p(vm.cornerTL, w, h))
                        path.addLine(to: p(vm.cornerTR, w, h))
                        path.addLine(to: p(vm.cornerBR, w, h))
                        path.addLine(to: p(vm.cornerBL, w, h))
                        path.closeSubpath()
                    }
                    .stroke(Color.blue, lineWidth: 2)
                    
                    // Handles
                    Handle(pos: $vm.cornerTL, w: w, h: h, onChange: vm.updateRenderer)
                    Handle(pos: $vm.cornerTR, w: w, h: h, onChange: vm.updateRenderer)
                    Handle(pos: $vm.cornerBL, w: w, h: h, onChange: vm.updateRenderer)
                    Handle(pos: $vm.cornerBR, w: w, h: h, onChange: vm.updateRenderer)
                }
                .padding(20)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    func p(_ point: CGPoint, _ w: CGFloat, _ h: CGFloat) -> CGPoint {
        return CGPoint(x: point.x * w, y: point.y * h)
    }
}

struct Handle: View {
    @Binding var pos: CGPoint
    let w: CGFloat
    let h: CGFloat
    let onChange: () -> Void
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 12, height: 12)
            .shadow(radius: 2)
            .position(x: pos.x * w, y: pos.y * h) // Position is absolute in ZStack
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newX = max(0, min(1, value.location.x / w))
                        let newY = max(0, min(1, value.location.y / h))
                        pos = CGPoint(x: newX, y: newY)
                        onChange()
                    }
            )
    }
}
