import SwiftUI
import MetalKit

class MappingViewModel: ObservableObject {
    @Published var screens: [NSScreen] = NSScreen.screens
    @Published var selectedScreenIndex: Int = 0
    @Published var isOutputActive: Bool = false
    
    @Published var layers: [Layer] = []
    @Published var selectedLayerID: UUID?
    @Published var selectedPointIndex: Int?
    
    // Input Management
    @Published var currentInputSource: String = "No Input"
    
    // Resolution
    @Published var outputResolution: CGSize = CGSize(width: 1920, height: 1080)
    
    var renderer = MetalRenderer()
    var outputWindowController: OutputWindowController?
    var inputManager: InputManager
    var montageManager = MontageManager()
    
    init() {
        inputManager = InputManager(device: renderer.device)
        renderer.inputManager = inputManager
        
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
                self.inputManager.setSource(.video(url: url))
                self.currentInputSource = url.lastPathComponent
            }
        }
    }
    
    func setTestPattern(_ pattern: TestPattern) {
        inputManager.setSource(.testPattern(pattern))
        currentInputSource = inputManager.getSourceName()
    }
    
    func setGenerator(_ type: GeneratorType) {
        inputManager.setSource(.proceduralGenerator(type, params: nil))
        currentInputSource = type.rawValue
    }
    
    func setSolidColor(r: Float, g: Float, b: Float) {
        inputManager.setSource(.solidColor(r: r, g: g, b: b))
        currentInputSource = "Solid Color"
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
        
        let currentPoints = layers[index].controlPoints
        guard currentPoints.count == 4 else { return }
        
        let tl = currentPoints[0]
        let tr = currentPoints[1]
        let bl = currentPoints[2]
        let br = currentPoints[3]
        
        var newPoints: [SIMD2<Float>] = []
        for r in 0..<rows {
            let vLerp = Float(r) / Float(rows - 1)
            for c in 0..<cols {
                let hLerp = Float(c) / Float(cols - 1)
                
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
            // Left Sidebar (MadMapper-style)
            VStack(alignment: .leading, spacing: 12) {
                Text("AuroraMapper Pro").font(.title3).bold()
                
                Divider()
                
                // Media Instances Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Media Instances").font(.headline)
                    
                    Text(vm.currentInputSource)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Menu("📁 Media Sources") {
                        Button("Load Video File...") { vm.loadVideo() }
                        
                        Divider()
                        
                        // Generators
                        Menu("⚙️ Generators") {
                            Button("Solid Color") { vm.setGenerator(.solidColor) }
                            Button("Color Patterns") { vm.setGenerator(.colorPatterns) }
                            Button("Grid Generator") { vm.setGenerator(.gridGenerator) }
                            Button("Test Card") { vm.setGenerator(.testCard) }
                        }
                        
                        // Materials
                        Menu("🎨 Materials") {
                            Button("Gradient Color") { vm.setGenerator(.gradientColor) }
                            Button("Strob") { vm.setGenerator(.strob) }
                            Button("Shapes") { vm.setGenerator(.shapes) }
                            Button("Line Patterns") { vm.setGenerator(.linePatterns) }
                            Button("MadNoise") { vm.setGenerator(.madNoise) }
                            Button("Sphere") { vm.setGenerator(.sphere) }
                        }
                        
                        Divider()
                        
                        // Line Patterns
                        Menu("📊 Line Patterns") {
                            Button("LineRepeat") { vm.setGenerator(.lineRepeat) }
                            Button("SquareArray") { vm.setGenerator(.squareArray) }
                            Button("Siren") { vm.setGenerator(.siren) }
                            Button("Dunes") { vm.setGenerator(.dunes) }
                            Button("Bar Code") { vm.setGenerator(.barCode) }
                            Button("Bricks") { vm.setGenerator(.bricks) }
                            Button("Clouds") { vm.setGenerator(.clouds) }
                            Button("Random") { vm.setGenerator(.random) }
                            Button("Noisy Barcode") { vm.setGenerator(.noisyBarcode) }
                            Button("Caustics") { vm.setGenerator(.caustics) }
                            Button("SquareWave") { vm.setGenerator(.squareWave) }
                            Button("CubicCircles") { vm.setGenerator(.cubicCircles) }
                            Button("Diagonals") { vm.setGenerator(.diagonals) }
                        }
                        
                        Divider()
                        
                        // Test Patterns
                        Menu("🔲 Test Patterns") {
                            Button("Checkerboard") { vm.setTestPattern(.checkerboard) }
                            Button("Grid") { vm.setTestPattern(.grid) }
                            Button("Color Bars") { vm.setTestPattern(.colorBars) }
                            Button("Gradient") { vm.setTestPattern(.gradient) }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Divider()
                
                // Resolution
                VStack(alignment: .leading, spacing: 6) {
                    Text("Resolution").font(.subheadline).bold()
                    Text("\(Int(vm.outputResolution.width)) × \(Int(vm.outputResolution.height))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Menu("Presets") {
                        Button("1920 × 1080 (Full HD)") { vm.outputResolution = CGSize(width: 1920, height: 1080) }
                        Button("2560 × 1440 (2K)") { vm.outputResolution = CGSize(width: 2560, height: 1440) }
                        Button("3840 × 2160 (4K)") { vm.outputResolution = CGSize(width: 3840, height: 2160) }
                        Button("1024 × 768 (XGA)") { vm.outputResolution = CGSize(width: 1024, height: 768) }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                
                Divider()
                
                // Output
                VStack(alignment: .leading, spacing: 6) {
                    Text("Output").font(.subheadline).bold()
                    Picker("", selection: $vm.selectedScreenIndex) {
                        ForEach(0..<vm.screens.count, id: \.self) { i in
                            Text(vm.screens[i].localizedName).tag(i)
                        }
                    }
                    .labelsHidden()
                    
                    Button(vm.isOutputActive ? "■ Stop" : "▶ Start") {
                        vm.toggleOutput()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(vm.isOutputActive ? .red : .green)
                    .font(.caption)
                }
                
                Divider()
                
                // Surfaces
                VStack(alignment: .leading, spacing: 6) {
                    Text("Surfaces").font(.subheadline).bold()
                    
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(vm.layers) { layer in
                                LayerRow(layer: layer, 
                                       isSelected: vm.selectedLayerID == layer.id,
                                       onSelect: { vm.selectedLayerID = layer.id })
                            }
                        }
                    }
                    .frame(height: 120)
                    
                    HStack(spacing: 4) {
                        Menu("+ Add") {
                            Button("Video Surface") { vm.addLayer(type: .video) }
                            Button("Mask") { vm.addLayer(type: .mask) }
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        
                        Button("Delete") {
                            vm.deleteSelectedLayer()
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        .disabled(vm.selectedLayerID == nil)
                    }
                }
                
                Divider()
                
                // Properties
                if let selectedID = vm.selectedLayerID,
                   let layerIndex = vm.layers.firstIndex(where: { $0.id == selectedID }) {
                    LayerProperties(layer: $vm.layers[layerIndex], 
                                  onUpdate: vm.updateRenderer,
                                  onConvertToGrid: { rows, cols in
                        vm.convertMeshToGrid(layerID: selectedID, rows: rows, cols: cols)
                    })
                }
                
                Spacer()
                
                // Presets
                HStack(spacing: 4) {
                    Button("💾") {
                        let panel = NSSavePanel()
                        panel.allowedContentTypes = [.json]
                        panel.nameFieldStringValue = "preset.json"
                        panel.begin { response in
                            if response == .OK, let url = panel.url {
                                 vm.savePreset(to: url)
                            }
                        }
                    }
                    .help("Save Preset")
                    
                    Button("📂") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.json]
                        panel.begin { response in
                            if response == .OK, let url = panel.url {
                                vm.loadPreset(from: url)
                            }
                        }
                    }
                    .help("Load Preset")
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
            .padding(12)
            .frame(minWidth: 220, maxWidth: 260)
            .background(Color(NSColor.windowBackgroundColor))
            
            // Center: Stage
            GeometryReader { geo in
                ZStack {
                    Color.black.opacity(0.95)
                    
                    VStack {
                        HStack {
                            Text("STAGE")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                            Spacer()
                            Text(vm.currentInputSource)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(8)
                        
                        Spacer()
                    }
                    
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
        .frame(minWidth: 1200, minHeight: 800)
    }
}

// Supporting Views (LayerRow, LayerProperties, MeshEditor, etc. - keeping previous implementations)
struct LayerRow: View {
    let layer: Layer
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: layer.type == .video ? "video.fill" : "scissors")
                .foregroundColor(layer.type == .video ? .blue : .orange)
                .frame(width: 16)
                .font(.caption)
            
            Text(layer.name)
                .font(.system(.caption, design: .monospaced))
            
            Spacer()
            
            if !layer.isVisible {
                Image(systemName: "eye.slash")
                    .foregroundColor(.gray)
                    .font(.caption2)
            }
        }
        .padding(6)
        .background(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
        .cornerRadius(3)
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Properties").font(.caption).bold()
            
            TextField("", text: $layer.name)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .onChange(of: layer.name) { _ in onUpdate() }
            
            Toggle("Visible", isOn: $layer.isVisible)
                .font(.caption)
                .onChange(of: layer.isVisible) { _ in onUpdate() }
            
            if layer.type == .video {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Opacity: \(Int(layer.opacity * 100))%")
                        .font(.caption2)
                    Slider(value: $layer.opacity, in: 0...1)
                        .onChange(of: layer.opacity) { _ in onUpdate() }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Edge: \(Int(layer.edgeSoftness * 100))%")
                        .font(.caption2)
                    Slider(value: $layer.edgeSoftness, in: 0...0.5)
                        .onChange(of: layer.edgeSoftness) { _ in onUpdate() }
                }
                
                Text("Mesh: \(layer.rows)×\(layer.cols)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Stepper("R:\(gridRows)", value: $gridRows, in: 2...10)
                        .font(.caption2)
                    Stepper("C:\(gridCols)", value: $gridCols, in: 2...10)
                        .font(.caption2)
                }
                
                Button("Convert") {
                    onConvertToGrid(gridRows, gridCols)
                }
                .buttonStyle(.bordered)
                .font(.caption2)
            }
        }
    }
}

struct MeshEditor: View {
    let layer: Layer
    let canvasSize: CGSize
    let onPointUpdate: (Int, SIMD2<Float>) -> Void
    
    var body: some View {
        ZStack {
            if layer.type == .video && layer.rows > 0 && layer.cols > 0 {
                MeshLines(layer: layer, canvasSize: canvasSize)
                    .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
            } else if layer.type == .mask {
                MaskOutline(layer: layer, canvasSize: canvasSize)
                    .stroke(Color.orange, lineWidth: 2)
            }
            
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
        
        for r in 0..<layer.rows {
            for c in 0..<(layer.cols - 1) {
                let p1 = toScreen(layer.controlPoints[r * layer.cols + c], w, h)
                let p2 = toScreen(layer.controlPoints[r * layer.cols + c + 1], w, h)
                path.move(to: p1)
                path.addLine(to: p2)
            }
        }
        
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
            .frame(width: 8, height: 8)
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
