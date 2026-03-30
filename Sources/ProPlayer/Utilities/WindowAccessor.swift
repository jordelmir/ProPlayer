import SwiftUI
import AppKit

/// Interceptor nativo para forzar el comportamiento Immersive Fullscreen en Apple Silicon (M1)
/// ELYSIUM STAFF+ PROTOCOL v14.0
struct WindowAccessor: NSViewRepresentable {

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            
            // CRITICAL: Activate the app when launched from terminal
            // Without this, the app runs behind the IDE and can NEVER enter fullscreen
            NSApp.activate(ignoringOtherApps: true)
            
            // 1. Forzar que la ventana sea elegible para su propio 'Space' nativo
            window.collectionBehavior.insert(.fullScreenPrimary)
            
            // 2. Interceptar el botón verde (Zoom Button) e inyectar el Toggle nativo
            if let zoomButton = window.standardWindowButton(.zoomButton) {
                zoomButton.action = #selector(NSWindow.toggleFullScreen(_:))
                zoomButton.target = window
            }
            
            // 3. Estética inmersiva: Fondo transparente y ocultar título
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            
            // 4. Make it the key window
            window.makeKeyAndOrderFront(nil)
        }
        
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    /// Aplica la configuración de ventana inmersiva de ProPlayer
    func immersiveMacWindow() -> some View {
        self.background(WindowAccessor())
    }
}
