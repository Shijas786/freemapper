import Foundation
import AppKit

// Project management
class ProjectManager: ObservableObject {
    @Published var currentProjectURL: URL?
    @Published var hasUnsavedChanges: Bool = false
    
    struct Project: Codable {
        var name: String
        var version: String = "2.0"
        var layers: [Layer]
        var viewSettings: ProjectViewSettings
        var outputSettings: ProjectOutputSettings
        
        struct ProjectViewSettings: Codable {
            var zoomLevel: Double
            var panX: Double
            var panY: Double
        }
        
        struct ProjectOutputSettings: Codable {
            var selectedScreenIndex: Int
            var resolution: CGSize
        }
    }
    
    func newProject() {
        currentProjectURL = nil
        hasUnsavedChanges = false
        // Reset to defaults
    }
    
    func openProject() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.loadProject(from: url)
            }
        }
    }
    
    func saveProject() {
        if let url = currentProjectURL {
            saveProject(to: url)
        } else {
            saveProjectAs()
        }
    }
    
    func saveProjectAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "AuroraMapper Project.json"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.saveProject(to: url)
                self.currentProjectURL = url
            }
        }
    }
    
    private func loadProject(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let project = try JSONDecoder().decode(Project.self, from: data)
            currentProjectURL = url
            hasUnsavedChanges = false
            // Apply project settings
        } catch {
            print("Failed to load project: \(error)")
        }
    }
    
    private func saveProject(to url: URL) {
        // Implementation for saving
        hasUnsavedChanges = false
    }
    
    func importMedia() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .image]
        panel.allowsMultipleSelection = true
        panel.begin { response in
            if response == .OK {
                // Handle imported media
            }
        }
    }
    
    func importImageFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                // Handle image folder
            }
        }
    }
    
    func import3DObject() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "obj")!]
        panel.begin { response in
            if response == .OK {
                // Handle 3D object
            }
        }
    }
    
    func importFixtures() {
        // Import DMX fixtures
    }
    
    func importSVGLines() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.svg]
        panel.begin { response in
            if response == .OK {
                // Handle SVG
            }
        }
    }
    
    func exportInput() {
        // Export input configuration
    }
    
    func exportOutput() {
        // Export output configuration
    }
    
    func collectExternalResources() {
        // Collect all external media files
    }
    
    func exportProjectTo() {
        // Export complete project bundle
    }
    
    func revealProject() {
        if let url = currentProjectURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
