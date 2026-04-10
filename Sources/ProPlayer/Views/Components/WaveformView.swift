import SwiftUI
import AppKit

struct BackgroundWaveformView: View {
    let mode: MediaMode
    @State private var time: Double = 0
    let barsCount = 64
    
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let barWidth = w / CGFloat(barsCount) * 0.8
            let spacing = w / CGFloat(barsCount) * 0.2
            
            for i in 0..<barsCount {
                let norm = Double(i) / Double(barsCount)
                // Simulate some waveform data
                let sin1 = sin(time * 3 + norm * .pi * 4) * 0.5 + 0.5
                let sin2 = cos(time * 2 + norm * .pi * 8) * 0.5 + 0.5
                let sin3 = sin(time * 5 - norm * .pi * 2) * 0.5 + 0.5
                
                let val = (sin1 + sin2 + sin3) / 3.0
                let magnitude = val * val // Make peaks sharper
                
                let barHeight = max(2, magnitude * Double(h) * 0.6)
                
                let x = CGFloat(i) * (barWidth + spacing)
                let y = h - CGFloat(barHeight)
                
                let rect = CGRect(x: x, y: y, width: barWidth, height: CGFloat(barHeight))
                
                let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                context.fill(path, with: .color(mode.accentColor.opacity(0.3 + magnitude * 0.7)))
                
                // Add top glow
                let glowRect = CGRect(x: x - barWidth/2, y: y - barWidth, width: barWidth * 2, height: barWidth * 2)
                let glowPath = Path(ellipseIn: glowRect)
                context.fill(glowPath, with: .color(mode.glowColor.opacity(magnitude * 0.5)))
            }
        }
        .onAppear {
            let timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
                time += 0.03
            }
            RunLoop.main.add(timer, forMode: .common)
        }
    }
}

/// A highly polished waveform visualizer that simulates real-time audio FFT.
/// In a fully C++ integrated implementation, this would read PCM buffers from AVAudioEngine tap.
struct WaveformView: View {
    @ObservedObject var engine = MusicPlayerEngine.shared
    
    var body: some View {
        ZStack {
            if engine.isPlaying {
                // Animated spectrum
                BackgroundWaveformView(mode: .music)
                    .blur(radius: 12)
                    .opacity(0.5)
                
                BackgroundWaveformView(mode: .music)
            } else {
                // Static flat line when paused/stopped
                Canvas { context, size in
                    let w = size.width
                    let h = size.height
                    let barWidth = w / 64 * 0.8
                    let spacing = w / 64 * 0.2
                    
                    for i in 0..<64 {
                        let x = CGFloat(i) * (barWidth + spacing)
                        let y = h - 4
                        let rect = CGRect(x: x, y: y, width: barWidth, height: 4)
                        context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(ProTheme.Colors.textTertiary))
                    }
                }
            }
        }
        .frame(height: 80)
        .padding(.horizontal)
        .animation(ProTheme.Animations.standard, value: engine.isPlaying)
    }
}
