import Foundation
import MetalKit

/// Motor matemático de ProPlayer v14.0 para calcular el Viewport de Metal
/// Mueve el costo computacional del Aspect Ratio de la GPU (Shader) a la CPU (Swift)
public struct VideoGeometryEngine {
    
    /// Calcula el Viewport exacto para el Render Command Encoder de Metal
    /// - Parameters:
    ///   - viewSize: El tamaño actual del MTKView (cambia dinámicamente en Fullscreen)
    ///   - videoSize: La resolución nativa del video (CVPixelBuffer)
    ///   - gravity: El algoritmo de escalado seleccionado por el usuario
    public static func calculateViewport(viewSize: CGSize, videoSize: CGSize, gravity: VideoGravityMode) -> MTLViewport {
        
        guard videoSize.width > 0 && videoSize.height > 0,
              viewSize.width > 0 && viewSize.height > 0 else {
            return MTLViewport(originX: 0, originY: 0, width: Double(viewSize.width), height: Double(viewSize.height), znear: 0, zfar: 1)
        }
        
        let viewRatio = viewSize.width / viewSize.height
        let videoRatio = videoSize.width / videoSize.height
        
        var targetRect = CGRect(origin: .zero, size: viewSize)
        
        switch gravity {
        case .stretch:
            // 100% de la pantalla, ignora distorsión (Modo Elástico)
            targetRect = CGRect(x: 0, y: 0, width: viewSize.width, height: viewSize.height)
            
        case .fit:
            // Letterbox nativo: encaja sin recortar
            if videoRatio > viewRatio {
                let height = viewSize.width / videoRatio
                targetRect = CGRect(x: 0, y: (viewSize.height - height) / 2.0, width: viewSize.width, height: height)
            } else {
                let width = viewSize.height * videoRatio
                targetRect = CGRect(x: (viewSize.width - width) / 2.0, y: 0, width: width, height: viewSize.height)
            }
            
        case .fill:
            // Llena la pantalla recortando lo que sobra (Crop)
            if videoRatio > viewRatio {
                let width = viewSize.height * videoRatio
                targetRect = CGRect(x: (viewSize.width - width) / 2.0, y: 0, width: width, height: viewSize.height)
            } else {
                let height = viewSize.width / videoRatio
                targetRect = CGRect(x: 0, y: (viewSize.height - height) / 2.0, width: viewSize.width, height: height)
            }
            
        case .smartFill:
            // Híbrido: Tolerancia de stretch antes de recortar
            let stretchTolerance: CGFloat = 1.15 
            let adjustedRatio = videoRatio > viewRatio ? videoRatio / stretchTolerance : videoRatio * stretchTolerance
            
            if adjustedRatio > viewRatio {
                let width = viewSize.height * adjustedRatio
                targetRect = CGRect(x: (viewSize.width - width) / 2.0, y: 0, width: width, height: viewSize.height)
            } else {
                let height = viewSize.width / adjustedRatio
                targetRect = CGRect(x: 0, y: (viewSize.height - height) / 2.0, width: viewSize.width, height: height)
            }
            
        case .ambient:
             // El modo ambiente suele usar un viewport completo para el desenfoque
             targetRect = CGRect(origin: .zero, size: viewSize)
             
        case .customZoom:
             // Zoom manual (no se procesa aquí, sino en los uniforms de zoom)
             targetRect = CGRect(origin: .zero, size: viewSize)
        }
        
        // Retornamos el Viewport de Metal preciso al sub-píxel para evitar jitter en M1
        return MTLViewport(originX: Double(targetRect.minX),
                           originY: Double(targetRect.minY),
                           width: Double(targetRect.width),
                           height: Double(targetRect.height),
                           znear: 0.0,
                           zfar: 1.0)
    }
}
