import SwiftUI
import MetalKit

class MappingViewModel: ObservableObject {
    @Published var screens: [NSScreen] = NSScreen.screens
    @Published var selectedScreenIndex: Int = 0
    @Published var isOutputActive: Bool = false
    
    @Published var layers: [Layer] = []
    @Published var selectedLayerID: UUID?
    @Published var selectedPointIndex: Int?
    
    var renderer = MetalRenderer()
    var outputWindowController: OutputWindowController?
    var videoEngine = VideoEngine()
    
    init() {
        renderer.videoEngine = videoEngine
        
        // Create default layer
        layers.append(Layer.createQuad(name: "Surface 1"))
        selectedLayerID = layers[0].id
        
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
        renderer.updateLayers(layers)
    }
    
    func addLayer(type: LayerType) {
        let newLayer: Layer
        switch type {
        case .video:
            newLayer = Layer.createQuad(name: "Surface \(layers.filter { $0.type == .video }.count + 1)")
        case .mask:
            newLayer = Layer.createMask(name: "Mask \(layers.filter { $0.type == .mask }.count + 1)")
        }
        layers.append(newLayer)
        selectedLayerID = newLayer.id
        updateRenderer()
    }
    
    func deleteSelectedLayer() {
        guard let id = selectedLayerID else { return }
        layers.removeAll { $0.id == id }
        selectedLayerID = layers.first?.id
        updateRenderer()
    }
    
    func updateLayerPoint(layerID: UUID, pointIndex: Int, newPosition: SIMD2<Float>) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        guard pointIndex < layers[index].controlPoints.count else { return }
        layers[index].controlPoints[pointIndex] = newPosition
        updateRenderer()
    }
    
    func convertMeshToGrid(layerID: UUID, rows: Int, cols: Int) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        guard layers[index].type == .video else { return }
        
        // Get current bounds
        let currentPoints = layers[index].controlPoints
        guard currentPoints.count == 4 else { return }
        
        let tl = currentPoints[0]
        let tr = currentPoints[1]
        let bl = currentPoints[2]
        let br = currentPoints[3]
        
        // Generate grid
        var newPoints: [SIMD2<Float>] = []
        for r in 0..<rows {
            let vLerp = Float(r) / Float(rows - 1)
            for c in 0..<cols {
                let hLerp = Float(c) / Float(cols - 1)
                
                // Bilinear interpolation
                let top = tl * (1 - hLerp) + tr * hLerp
                let bottom = bl * (1 - hLerp) + br * hLerp
                let point = top * (1 - vLerp) + bottom * vLerp
                
                newPoints.append(point)
            }
        }
        
        layers[index].rows = rows
        layers[index].cols = cols
        layers[index].controlPoints = newPoints
        updateRenderer()
    }
    
    func savePreset(to url: URL) {
        let preset = Preset(name: "AuroraMapper Preset", layers: layers)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(preset)
            try data.write(to: url)
        } catch {
            print("Save error: \(error)")
        }
    }
    
    func loadPreset(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let preset = try JSONDecoder().decode(Preset.self, from: data)
            layers = preset.layers
            selectedLayerID = layers.first?.id
            updateRenderer()
        } catch {
            print("Load error: \(error)")
        }
    }
}

struct ControlPanel: View {
    @StateObject var vm = MappingViewModel()
    
    var body: some View {
        HSplitView {
            // Left Sidebar
            VStack(alignment: .leading, spacing: 16) {
                Text("AuroraMapper v2").font(.title2).bold()
                
                Divider()
                
                // Video Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Video Input").font(.headline)
                    Button("Load Video") { vm.loadVideo() }
                        .buttonStyle(.borderedProminent)
                }
                
                Divider()
                
                // Output Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output Display").font(.headline)
                    Picker("Screen", selection: $vm.selectedScreenIndex) {
                        ForEach(0..<vm.screens.count, id: \.self) { i in
                            Text(vm.screens[i].localizedName)
                        }
                    }
                    
                    Button(vm.isOutputActive ? "Stop Output" : "Start Output") {
                        vm.toggleOutput()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(vm.isOutputActive ? .red : .green)
                }
                
                Divider()
                
                // Layers Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Layers").font(.headline)
                    
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(vm.layers) { layer in
                                LayerRow(layer: layer, 
                                       isSelected: vm.selectedLayerID == layer.id,
                                       onSelect: { vm.selectedLayerID = layer.id })
                            }
                        }
                    }
                    .frame(height: 150)
                    
                    HStack {
                        Menu("Add Layer") {
                            Button("Video Surface") { vm.addLayer(type: .video) }
                            Button("Mask") { vm.addLayer(type: .mask) }
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Delete", role: .destructive) {
                            vm.deleteSelectedLayer()
                        }
                        .buttonStyle(.bordered)
                        .disabled(vm.selectedLayerID == nil)
                    }
                }
                
                Divider()
                
                // Layer Properties
                if let selectedID = vm.selectedLayerID,
                   let layerIndex = vm.layers.firstIndex(where: { $0.id == selectedID }) {
                    LayerProperties(layer: $vm.layers[layerIndex], 
                                  onUpdate: vm.updateRenderer,
                                  onConvertToGrid: { rows, cols in
                        vm.convertMeshToGrid(layerID: selectedID, rows: rows, cols: cols)
                    })
                }
                
                Spacer()
                
                // Preset Management
                HStack {
                    Button("Save") {
                        let panel = NSSavePanel()
                        panel.allowedContentTypes = [.json]
                        panel.nameFieldStringValue = "preset.json"
                        panel.begin { response in
                            if response == .OK, let url = panel.url {
                                vm.savePreset(to: url)
                            }
                        }
                    }
                    
                    Button("Load") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.json]
                        panel.begin { response in
                            if response == .OK, let url = panel.url {
                                vm.loadPreset(from: url)
                            }
                        }
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(minWidth: 250, maxWidth: 300)
            
            // Editor Canvas
            GeometryReader { geo in
                ZStack {
                    Color.black.opacity(0.9)
                    
                    if let selectedID = vm.selectedLayerID,
                       let layer = vm.layers.first(where: { $0.id == selectedID }) {
                        
                        MeshEditor(layer: layer,
                                 canvasSize: geo.size,
                                 onPointUpdate: { index, newPos in
                            vm.updateLayerPoint(layerID: selectedID, pointIndex: index, newPosition: newPos)
                        })
                    }
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
    }
}

struct LayerRow: View {
    let layer: Layer
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: layer.type == .video ? "video.fill" : "scissors")
                .foregroundColor(layer.type == .video ? .blue : .orange)
            
            Text(layer.name)
                .font(.system(.body, design: .monospaced))
            
            Spacer()
            
            if !layer.isVisible {
                Image(systemName: "eye.slash")
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
        .cornerRadius(4)
        .onTapGesture { onSelect() }
    }
}

struct LayerProperties: View {
    @Binding var layer: Layer
    let onUpdate: () -> Void
    let onConvertToGrid: (Int, Int) -> Void
    
    @State private var gridRows = 3
    @State private var gridCols = 3
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Properties").font(.headline)
            
            TextField("Name", text: $layer.name)
                .textFieldStyle(.roundedBorder)
                .onChange(of: layer.name) { _ in onUpdate() }
            
            Toggle("Visible", isOn: $layer.isVisible)
                .onChange(of: layer.isVisible) { _ in onUpdate() }
            
            if layer.type == .video {
                VStack(alignment: .leading) {
                    Text("Opacity: \(Int(layer.opacity * 100))%")
                        .font(.caption)
                    Slider(value: $layer.opacity, in: 0...1)
                        .onChange(of: layer.opacity) { _ in onUpdate() }
                }
                
                VStack(alignment: .leading) {
                    Text("Edge Softness: \(Int(layer.edgeSoftness * 100))%")
                        .font(.caption)
                    Slider(value: $layer.edgeSoftness, in: 0...0.5)
                        .onChange(of: layer.edgeSoftness) { _ in onUpdate() }
                }
                
                Divider()
                
                Text("Mesh Grid").font(.subheadline).bold()
                Text("Current: \(layer.rows)×\(layer.cols)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Stepper("Rows: \(gridRows)", value: $gridRows, in: 2...10)
                    Stepper("Cols: \(gridCols)", value: $gridCols, in: 2...10)
                }
                .font(.caption)
                
                Button("Convert to \(gridRows)×\(gridCols) Grid") {
                    onConvertToGrid(gridRows, gridCols)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical)
    }
}

struct MeshEditor: View {
    let layer: Layer
    let canvasSize: CGSize
    let onPointUpdate: (Int, SIMD2<Float>) -> Void
    
    var body: some View {
        ZStack {
            // Draw mesh lines
            if layer.type == .video && layer.rows > 0 && layer.cols > 0 {
                MeshLines(layer: layer, canvasSize: canvasSize)
                    .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
            } else if layer.type == .mask {
                MaskOutline(layer: layer, canvasSize: canvasSize)
                    .stroke(Color.orange, lineWidth: 2)
            }
            
            // Draw control points
            ForEach(0..<layer.controlPoints.count, id: \.self) { index in
                ControlPointHandle(
                    position: layer.controlPoints[index],
                    canvasSize: canvasSize,
                    color: layer.type == .video ? .white : .orange,
                    onDrag: { newPos in
                        onPointUpdate(index, newPos)
                    }
                )
            }
        }
    }
}

struct MeshLines: Shape {
    let layer: Layer
    let canvasSize: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = canvasSize.width
        let h = canvasSize.height
        
        // Horizontal lines
        for r in 0..<layer.rows {
            for c in 0..<(layer.cols - 1) {
                let p1 = toScreen(layer.controlPoints[r * layer.cols + c], w, h)
                let p2 = toScreen(layer.controlPoints[r * layer.cols + c + 1], w, h)
                path.move(to: p1)
                path.addLine(to: p2)
            }
        }
        
        // Vertical lines
        for c in 0..<layer.cols {
            for r in 0..<(layer.rows - 1) {
                let p1 = toScreen(layer.controlPoints[r * layer.cols + c], w, h)
                let p2 = toScreen(layer.controlPoints[(r + 1) * layer.cols + c], w, h)
                path.move(to: p1)
                path.addLine(to: p2)
            }
        }
        
        return path
    }
    
    func toScreen(_ ndc: SIMD2<Float>, _ w: CGFloat, _ h: CGFloat) -> CGPoint {
        return CGPoint(x: CGFloat((ndc.x + 1) * 0.5) * w,
                      y: CGFloat((1 - ndc.y) * 0.5) * h)
    }
}

struct MaskOutline: Shape {
    let layer: Layer
    let canvasSize: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = canvasSize.width
        let h = canvasSize.height
        
        guard !layer.controlPoints.isEmpty else { return path }
        
        let first = toScreen(layer.controlPoints[0], w, h)
        path.move(to: first)
        
        for i in 1..<layer.controlPoints.count {
            let p = toScreen(layer.controlPoints[i], w, h)
            path.addLine(to: p)
        }
        
        path.closeSubpath()
        
        return path
    }
    
    func toScreen(_ ndc: SIMD2<Float>, _ w: CGFloat, _ h: CGFloat) -> CGPoint {
        return CGPoint(x: CGFloat((ndc.x + 1) * 0.5) * w,
                      y: CGFloat((1 - ndc.y) * 0.5) * h)
    }
}

struct ControlPointHandle: View {
    let position: SIMD2<Float>
    let canvasSize: CGSize
    let color: Color
    let onDrag: (SIMD2<Float>) -> Void
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(Color.black, lineWidth: 1))
            .position(toScreen(position))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newPos = toNDC(value.location)
                        onDrag(newPos)
                    }
            )
    }
    
    func toScreen(_ ndc: SIMD2<Float>) -> CGPoint {
        return CGPoint(x: CGFloat((ndc.x + 1) * 0.5) * canvasSize.width,
                      y: CGFloat((1 - ndc.y) * 0.5) * canvasSize.height)
    }
    
    func toNDC(_ screen: CGPoint) -> SIMD2<Float> {
        let x = Float(screen.x / canvasSize.width) * 2 - 1
        let y = 1 - Float(screen.y / canvasSize.height) * 2
        return SIMD2<Float>(x, y)
    }
}
