import SwiftUI

@main
struct AuroraMapperApp: App {
    @StateObject private var projectManager = ProjectManager()
    @StateObject private var viewSettings = ViewSettings()
    
    var body: some Scene {
        WindowGroup {
            ControlPanel()
                .environmentObject(projectManager)
                .environmentObject(viewSettings)
        }
        .commands {
            // File Menu
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    projectManager.newProject()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Open Project...") {
                    projectManager.openProject()
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Divider()
                
                Button("Save Project") {
                    projectManager.saveProject()
                }
                .keyboardShortcut("s", modifiers: .command)
                
                Button("Save Project As...") {
                    projectManager.saveProjectAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Collect External Resources...") {
                    projectManager.collectExternalResources()
                }
                
                Button("Export Project To...") {
                    projectManager.exportProjectTo()
                }
                
                Button("Reveal Project") {
                    projectManager.revealProject()
                }
                
                Divider()
                
                Menu("Import") {
                    Button("Import Media...") {
                        projectManager.importMedia()
                    }
                    .keyboardShortcut("i", modifiers: .command)
                    
                    Button("Import Image Folder...") {
                        projectManager.importImageFolder()
                    }
                    
                    Button("Import 3D Object...") {
                        projectManager.import3DObject()
                    }
                    
                    Button("Import Fixtures...") {
                        projectManager.importFixtures()
                    }
                    
                    Button("Import SVG Lines...") {
                        projectManager.importSVGLines()
                    }
                }
                
                Menu("Export") {
                    Button("Export Input...") {
                        projectManager.exportInput()
                    }
                    
                    Button("Export Output...") {
                        projectManager.exportOutput()
                    }
                }
            }
            
            // View Menu
            CommandMenu("View") {
                Button(viewSettings.viewMode == .desktop ? "Full Screen Mode" : "Desktop Mode") {
                    viewSettings.toggleFullScreen()
                }
                .keyboardShortcut("u", modifiers: .command)
                
                Divider()
                
                Button("Show Info") {
                    viewSettings.showInfo.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                
                Button("Show Test Pattern") {
                    viewSettings.showTestPattern.toggle()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                
                Toggle("Video Cursor", isOn: $viewSettings.videoCursor)
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                
                Toggle("Laser Cursor", isOn: $viewSettings.laserCursor)
                
                Divider()
                
                Toggle("Highlight Background", isOn: $viewSettings.highlightBackground)
                    .keyboardShortcut("b", modifiers: [.command, .shift])
                
                Toggle("Highlight Selection", isOn: $viewSettings.highlightSelection)
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Zoom to Selected Surface") {
                    viewSettings.zoomToSelectedSurface()
                }
                
                Button("Fit To Window") {
                    viewSettings.fitToWindow()
                }
                .keyboardShortcut("0", modifiers: .command)
                
                Button("Zoom In") {
                    viewSettings.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)
                
                Button("Zoom Out") {
                    viewSettings.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Divider()
                
                Picker("Display Mode", selection: $viewSettings.displayMode) {
                    Text("Dual View").tag(DisplayMode.dualView)
                    Text("Input").tag(DisplayMode.input)
                    Text("Stage").tag(DisplayMode.stage)
                }
                
                Divider()
                
                Toggle("Collapse User Interface", isOn: $viewSettings.collapseUserInterface)
                
                Toggle("Show Editors Panel", isOn: $viewSettings.showEditorsPanel)
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                
                Toggle("Expand Info Panel", isOn: $viewSettings.expandInfoPanel)
                
                Divider()
                
                Toggle("Snap To Objects", isOn: $viewSettings.snapToObjects)
                    .keyboardShortcut("s", modifiers: [.command, .option])
                
                Toggle("Lock Surfaces Movement", isOn: $viewSettings.lockSurfacesMovement)
                    .keyboardShortcut("l", modifiers: [.command, .option])
                
                Button("Reset Locations") {
                    viewSettings.resetLocations()
                }
            }
            
            // Output Menu
            CommandMenu("Output") {
                Button("Import Outputs Setup...") {
                    // Implementation
                }
                
                Button("Export Outputs Setup...") {
                    // Implementation
                }
            }
            
            // Tools Menu
            CommandMenu("Tools") {
                Button("Arm Lasers") {
                    // Implementation
                }
            }
        }
    }
}

