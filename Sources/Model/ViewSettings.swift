import Foundation

// View modes and display options
enum ViewMode {
    case desktop
    case fullScreen
}

enum DisplayMode {
    case dualView
    case input
    case stage
}

class ViewSettings: ObservableObject {
    @Published var viewMode: ViewMode = .desktop
    @Published var displayMode: DisplayMode = .dualView
    
    // View options
    @Published var showInfo: Bool = false
    @Published var showTestPattern: Bool = false
    @Published var videoCursor: Bool = false
    @Published var laserCursor: Bool = false
    @Published var highlightBackground: Bool = false
    @Published var highlightSelection: Bool = true
    
    // View controls
    @Published var zoomLevel: CGFloat = 1.0
    @Published var panOffset: CGPoint = .zero
    @Published var snapToObjects: Bool = true
    @Published var lockSurfacesMovement: Bool = false
    
    // UI visibility
    @Published var showEditorsPanel: Bool = true
    @Published var expandInfoPanel: Bool = true
    @Published var collapseUserInterface: Bool = false
    
    func zoomToSelectedSurface() {
        // Implementation for zoom to selected
        zoomLevel = 1.5
    }
    
    func fitToWindow() {
        zoomLevel = 1.0
        panOffset = .zero
    }
    
    func zoomIn() {
        zoomLevel = min(zoomLevel * 1.2, 5.0)
    }
    
    func zoomOut() {
        zoomLevel = max(zoomLevel / 1.2, 0.2)
    }
    
    func resetLocations() {
        panOffset = .zero
        zoomLevel = 1.0
    }
    
    func toggleFullScreen() {
        viewMode = viewMode == .desktop ? .fullScreen : .desktop
    }
}
