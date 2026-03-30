import SwiftUI
import AppKit

/// Un bridge para inyectarse en la jerarquía de vistas y obtener acceso nativo a la ventana (NSWindow) subyacente de SwiftUI.
struct FullScreenManagerView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.styleMask.insert(.fullSizeContentView)
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Funciones Helpers para administrar la entrada y salida programática al Full Screen de macOS
struct WindowController {
    
    @MainActor
    static func enterImmersiveFullScreen() {
        // Activate app first — critical for terminal-launched processes
        NSApp.activate(ignoringOtherApps: true)
        
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            // Retry after a short delay — window might not be ready yet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else { return }
                configureAndEnterFullscreen(window)
            }
            return
        }
        
        configureAndEnterFullscreen(window)
    }
    
    @MainActor
    private static func configureAndEnterFullscreen(_ window: NSWindow) {
        // 1. Ensure the window supports native fullscreen (Space creation)
        window.collectionBehavior.insert(.fullScreenPrimary)
        
        // 2. Inyectamos la capacidad de cubrir todo (inclusive detrás de la manzanita)
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        // 3. Make it key and front
        window.makeKeyAndOrderFront(nil)
        
        // 4. Si no estamos ya en Full Screen, ordenamos a macOS crear el Space y transicionar
        if !window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
    }
    
    @MainActor
    static func exitImmersiveFullScreen() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) else { return }
        
        // 1. Si seguimos atrapados en Full Screen, obligamos a macOS a regresar al Desktop
        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
        
        // 2. Restauramos el título nativo para el modo Librería
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            window.styleMask.remove(.fullSizeContentView)
            window.titlebarAppearsTransparent = false
            window.titleVisibility = .visible
        }
    }
}
