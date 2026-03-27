import SwiftUI
import CoreVideo
import Combine
import MetalKit
import ProPlayerEngine

struct MetalPlayerView: NSViewRepresentable {
    @ObservedObject var engine: PlayerEngine
    
    func makeNSView(context: Context) -> MTKView {
        let renderer = MetalVideoRenderer()
        context.coordinator.renderer = renderer
        
        // Link the engine's frame extractor output to the renderer's input
        context.coordinator.setupObservation(for: engine, renderer: renderer)
        
        return renderer.mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    @MainActor
    class Coordinator: NSObject {
        var renderer: MetalVideoRenderer?
        private var cancellable: AnyCancellable?
        
        func setupObservation(for engine: PlayerEngine, renderer: MetalVideoRenderer) {
            cancellable = engine.frameExtractor.$currentPixelBuffer
                .receive(on: DispatchQueue.main) // Ensure we update on main actor
                .sink { [weak renderer] buffer in
                    renderer?.currentPixelBuffer = buffer
                }
        }
    }
}
