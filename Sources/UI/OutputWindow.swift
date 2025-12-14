import Cocoa
import MetalKit

class OutputWindowController: NSWindowController {
    
    var mtkView: MTKView!
    var renderer: MetalRenderer
    
    init(screen: NSScreen, renderer: MetalRenderer) {
        self.renderer = renderer
        
        let rect = screen.frame
        let window = NSWindow(contentRect: rect,
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false,
                              screen: screen)
        
        window.level = .mainMenu + 1 // Float above
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .black
        
        super.init(window: window)
        
        // Setup View
        mtkView = MTKView(frame: window.contentView!.bounds, device: renderer.device)
        mtkView.delegate = renderer
        mtkView.autoresizingMask = [.width, .height]
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        window.contentView?.addSubview(mtkView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
    }
}
