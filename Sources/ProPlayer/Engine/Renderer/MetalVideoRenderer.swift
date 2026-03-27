import Foundation
import Metal
import MetalKit
import CoreVideo

/// A high-performance metal renderer that bypasses AVPlayerLayer.
/// Takes CVPixelBuffers extracted at precise vsync intervals and renders them using custom shaders.
@MainActor
public final class MetalVideoRenderer: NSObject, MTKViewDelegate, ObservableObject {
    public let mtkView: MTKView
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var textureCache: CVMetalTextureCache?
    
    // Pipeline State
    private var renderPipelineState: MTLRenderPipelineState?
    
    // The current frame to render
    public var currentPixelBuffer: CVPixelBuffer? {
        didSet {
            // Only force a draw if the view is paused or manually driven.
            // If CVDisplayLink is driving this, we might rely on MTKView's standard loop
            // or explicitly call draw() from the DisplayLink callback.
            mtkView.setNeedsDisplay(mtkView.bounds)
        }
    }
    
    public override init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            fatalError("[MetalVideoRenderer] Fatal: Metal is unsupported.")
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.mtkView = MTKView(frame: .zero, device: device)
        
        super.init()
        
        self.mtkView.delegate = self
        self.mtkView.framebufferOnly = true
        self.mtkView.colorPixelFormat = .bgra8Unorm // Standard SDR format (expand to RGB10 for HDR later)
        self.mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        self.mtkView.enableSetNeedsDisplay = true
        self.mtkView.isPaused = true // We drive the render loop explicitly via CVDisplayLink
        
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        setupPipeline()
    }
    
    private func setupPipeline() {
        let bundle = Bundle.module
        guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
            print("[MetalVideoRenderer] Warning: Could not find Shaders.metal in Bundle.module. Using fallback.")
            return
        }
        
        let vertexFunction = library.makeFunction(name: "videoVertexShader")
        let fragmentFunction = library.makeFunction(name: "videoFragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "ProPlayer Video Pipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("[MetalVideoRenderer] Failed to create pipeline state: \(error)")
        }
    }
    
    // MARK: - MTKViewDelegate
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle window resizing (update projection matrices if needed)
    }
    
    public func draw(in view: MTKView) {
        guard let pixelBuffer = currentPixelBuffer,
              let textureCache = textureCache,
              let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let pipelineState = renderPipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var cvTextureOut: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm, // Assuming 32BGRA from extractor.
            width,
            height,
            0,
            &cvTextureOut
        )
        
        guard result == kCVReturnSuccess,
              let cvTexture = cvTextureOut,
              let metalTexture = CVMetalTextureGetTexture(cvTexture) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setFragmentTexture(metalTexture, index: 0)
        
        // Draw a full-screen quad (6 vertices for 2 triangles)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
