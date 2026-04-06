@MainActor
import Metal
import MetalKit
import AVFoundation

public final class MetalVideoRenderer: NSObject, MTKViewDelegate {
    
    struct Uniforms {
        var viewportSize: simd_uint2
        var contentSize: simd_uint2
        var gravityMode: simd_uint1
        var renderingTier: simd_uint1
        var sharpnessWeight: simd_float1
        var ambientIntensity: simd_float1
        var offset: simd_float2
        var time: simd_float1
        var matrixIntensity: simd_float1
        var colorMatrixType: simd_uint1
        
        // Advanced Rendering (v13.0)
        var colorTemperature: simd_float1
        var filmGrainIntensity: simd_float1
        var enableToneMapping: simd_uint1
        var enableTNR: simd_uint1
    }
    
    private let startTime = Date()
    
    // Settings Reference
    public var gravityMode: VideoGravityMode = .fill { didSet { mtkView.setNeedsDisplay(mtkView.bounds) } }
    public var renderingTier: SuperResolutionTier = .upscale4k { didSet { mtkView.setNeedsDisplay(mtkView.bounds) } }
    public var ambientIntensity: Double = 0.4 { didSet { mtkView.setNeedsDisplay(mtkView.bounds) } }
    public var matrixIntensity: Double = 0.0 { didSet { mtkView.setNeedsDisplay(mtkView.bounds) } }
    public var colorTemperature: Float = 6500.0 { didSet { mtkView.setNeedsDisplay(mtkView.bounds) } }
    public var filmGrainIntensity: Float = 0.0 { didSet { mtkView.setNeedsDisplay(mtkView.bounds) } }
    public var enableToneMapping: Bool = false { didSet { mtkView.setNeedsDisplay(mtkView.bounds) } }
    public var enableTNR: Bool = false { didSet { mtkView.setNeedsDisplay(mtkView.bounds) } }
    
    // Core Rendering State
    private var previousTexture: MTLTexture?
    
    public var currentPixelBuffer: CVPixelBuffer? {
        didSet {
            // Trigger a redraw whenever we get a new frame
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
        self.mtkView.colorPixelFormat = .bgra8Unorm
        self.mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        // Use enableSetNeedsDisplay for demand-driven rendering
        // Frame updates are triggered by setting currentPixelBuffer
        self.mtkView.enableSetNeedsDisplay = true
        self.mtkView.isPaused = true
        
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        setupPipeline()
    }
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    public let mtkView: MTKView
    private var textureCache: CVMetalTextureCache?
    
    private var renderPipelineState: MTLRenderPipelineState?
    private var computePipelineState: MTLComputePipelineState? 
    
    private func setupPipeline() {
        let bundle = Bundle.module
        var library: MTLLibrary?
        
        print("[MetalVideoRenderer] Loading library from bundle: \(bundle.bundlePath)")
        
        // Strategy 1: Default Library (pre-compiled metallib)
        if let lib = try? device.makeDefaultLibrary(bundle: bundle) {
            print("[MetalVideoRenderer] Success: makeDefaultLibrary(bundle:)")
            library = lib
        } 
        
        // Strategy 2: Explicit default.metallib
        if library == nil {
            if let path = bundle.path(forResource: "default", ofType: "metallib") {
                print("[MetalVideoRenderer] Found default.metallib: \(path)")
                library = try? device.makeLibrary(filepath: path)
            }
        }
        
        // Strategy 3: Compile from source
        if library == nil {
            if let path = bundle.path(forResource: "Shaders", ofType: "metal") {
                print("[MetalVideoRenderer] Found Shaders.metal: \(path)")
                do {
                    let source = try String(contentsOfFile: path)
                    library = try device.makeLibrary(source: source, options: nil)
                    print("[MetalVideoRenderer] Success: Compiled from source.")
                } catch {
                    print("[MetalVideoRenderer] Error compiling from source: \(error)")
                }
            } else {
                print("[MetalVideoRenderer] Error: Shaders.metal not found in bundle.")
            }
        }
        
        guard let libraryRef = library else {
            print("[MetalVideoRenderer] FATAL: All shader loading strategies failed.")
            return
        }
        
        do {
            let vertexFunction = libraryRef.makeFunction(name: "videoVertexShader")
            let fragmentFunction = libraryRef.makeFunction(name: "videoFragmentShader")
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
            
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            if let blurFunction = libraryRef.makeFunction(name: "gaussianBlurKernel") {
                computePipelineState = try device.makeComputePipelineState(function: blurFunction)
            }
            
            print("[MetalVideoRenderer] Success: Pipeline established.")
        } catch {
            print("[MetalVideoRenderer] Error creating pipelines: \(error)")
        }
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        guard let pixelBuffer = currentPixelBuffer,
              let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let pipelineState = renderPipelineState else {
            return
        }
        
        // Create BGRA texture from pixel buffer (single plane)
        guard let videoTexture = createBGRATexture(from: pixelBuffer) else {
            renderEncoder.endEncoding()
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setFragmentTexture(videoTexture, index: 0)
        
        // Provide previous texture for TNR (fallback to current if nil)
        renderEncoder.setFragmentTexture(previousTexture ?? videoTexture, index: 1)
        
        var uniforms = calculateUniforms(pixelBuffer: pixelBuffer)
        
        // Geometry Engine viewport
        let viewport = VideoGeometryEngine.calculateViewport(
            viewSize: mtkView.drawableSize,
            videoSize: CGSize(width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)), height: CGFloat(CVPixelBufferGetHeight(pixelBuffer))),
            gravity: gravityMode
        )
        renderEncoder.setViewport(viewport)
        
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        // Store current frame for next TNR cycle
        if enableTNR {
            previousTexture = videoTexture
        } else {
            previousTexture = nil
        }
    }
    
    /// Creates a Metal texture from a BGRA CVPixelBuffer (non-planar, single texture)
    private func createBGRATexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let textureCache = textureCache else { return nil }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard width > 0 && height > 0 else { return nil }
        
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,  // Matching kCVPixelFormatType_32BGRA from VideoFrameExtractor
            width,
            height,
            0,            // planeIndex 0 for non-planar
            &cvTexture
        )
        
        guard status == kCVReturnSuccess, let texture = cvTexture else {
            return nil
        }
        return CVMetalTextureGetTexture(texture)
    }
    
    private func calculateUniforms(pixelBuffer: CVPixelBuffer) -> Uniforms {
        let width = UInt32(CVPixelBufferGetWidth(pixelBuffer))
        let height = UInt32(CVPixelBufferGetHeight(pixelBuffer))
        let viewportWidth = UInt32(mtkView.drawableSize.width)
        let viewportHeight = UInt32(mtkView.drawableSize.height)
        
        let offset = simd_float2(0, 0)
        let time = Float(Date().timeIntervalSince(startTime))
        
        return Uniforms(
            viewportSize: simd_uint2(viewportWidth, viewportHeight),
            contentSize: simd_uint2(width, height),
            gravityMode: simd_uint1(gravityMode.indexValue),
            renderingTier: simd_uint1(renderingTier.indexValue),
            sharpnessWeight: simd_float1(renderingTier.sharpnessWeight),
            ambientIntensity: simd_float1(ambientIntensity),
            offset: offset,
            time: simd_float1(time),
            matrixIntensity: simd_float1(matrixIntensity),
            colorMatrixType: simd_uint1(0),
            colorTemperature: simd_float1(colorTemperature),
            filmGrainIntensity: simd_float1(filmGrainIntensity),
            enableToneMapping: simd_uint1(enableToneMapping ? 1 : 0),
            enableTNR: simd_uint1(enableTNR ? 1 : 0)
        )
    }
}

// ProPlayerEngine VideoGravityMode Extension
extension VideoGravityMode {
    var indexValue: Int {
        switch self {
        case .fit: return 0
        case .fill: return 1
        case .stretch: return 2
        case .smartFill: return 3
        case .customZoom: return 4
        case .ambient: return 5
        }
    }
}

extension SuperResolutionTier {
    var indexValue: Int {
        switch self {
        case .off: return 0
        case .upscale2k: return 1
        case .upscale4k: return 2
        case .ultraAI: return 3
        case .ultra5K: return 4
        case .extreme8K: return 5
        case .animeAdaptive: return 6
        }
    }
}
