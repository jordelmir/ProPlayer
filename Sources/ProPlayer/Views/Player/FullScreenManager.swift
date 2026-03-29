import SwiftUI
import AppKit

/// Un bridge para inyectarse en la jerarquía de vistas y obtener acceso nativo a la ventana (NSWindow) subyacente de SwiftUI.
struct FullScreenManagerView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            // Configurar agresivamente las representaciones de ventana para permitir que 
            // la aplicación dibuje sobre el Safe Area de la Barra de Menú (Manzanita).
            if let window = view.window {
                // Al insertar .fullSizeContentView le decimos a macOS que el contenido puede existir debajo de la barra de título/menú
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
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else { return }
        
        // 1. Inyectamos la capacidad de cubrir todo (inclusive detrás de la manzanita)
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        // 2. Si no estamos ya en Full Screen, ordenamos a macOS crear el Space y transicionar
        if !window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
    }
    
    @MainActor
    static func exitImmersiveFullScreen() {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else { return }
        
        // 1. Restauramos el título nativo para el modo Librería (evitando que choque con el Safe Area)
        window.styleMask.remove(.fullSizeContentView)
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        
        // 2. Si seguimos atrapados en Full Screen, obligamos a macOS a regresar al Desktop
        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
    }
}
