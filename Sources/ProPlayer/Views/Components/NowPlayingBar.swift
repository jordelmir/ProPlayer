import SwiftUI
import AppKit

struct NowPlayingBar: View {
    @ObservedObject var engine = MusicPlayerEngine.shared
    @State private var isDraggingSlider = false
    @State private var dragPosition: Double? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Waveform visualizer embedded above the bar
            WaveformView()
                .frame(height: 40)
                .opacity(engine.isPlaying ? 1 : 0)
                .padding(.horizontal)
            
            // Progress Bar
            progressBar
            
            HStack(spacing: ProTheme.Spacing.md) {
                // Info Section
                HStack(spacing: ProTheme.Spacing.md) {
                    artworkView
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(engine.currentTrack?.title ?? "No track selected")
                            .font(ProTheme.Fonts.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(maxWidth: 200, alignment: .leading)
                        
                        Text(engine.currentTrack?.artist ?? "---")
                            .font(ProTheme.Fonts.subheadline)
                            .foregroundColor(ProTheme.Colors.textSecondary)
                            .lineLimit(1)
                            .frame(maxWidth: 200, alignment: .leading)
                    }
                }
                .frame(width: 300, alignment: .leading)
                
                Spacer()
                
                // Playback Controls
                HStack(spacing: ProTheme.Spacing.lg) {
                    Button(action: {
                        engine.queue.shuffleMode.toggle()
                    }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(engine.queue.shuffleMode ? ProTheme.Colors.accentPurple : ProTheme.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { engine.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .hoverEffect()
                    
                    Button(action: { engine.togglePlayPause() }) {
                        Image(systemName: engine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(engine.currentTrack != nil ? .white : ProTheme.Colors.textTertiary)
                            .shadow(color: engine.isPlaying ? .black.opacity(0.3) : .clear, radius: 4)
                    }
                    .buttonStyle(.plain)
                    .hoverEffect()
                    .disabled(engine.currentTrack == nil)
                    
                    Button(action: { engine.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .hoverEffect()
                    
                    Button(action: cycleRepeat) {
                        Image(systemName: engine.queue.repeatMode.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(engine.queue.repeatMode != .off ? ProTheme.Colors.accentPurple : ProTheme.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Volume & Extras
                HStack(spacing: ProTheme.Spacing.sm) {
                    Button(action: { engine.toggleMute() }) {
                        Image(systemName: engine.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .foregroundColor(ProTheme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    
                    Slider(value: Binding(get: { engine.volume }, set: { engine.volume = $0 }), in: 0...1)
                        .tint(ProTheme.Colors.accentPurple)
                        .frame(width: 100)
                        
                    Button(action: {
                        // Open lyrics window protocol
                        NotificationCenter.default.post(name: NSNotification.Name("ToggleLyrics"), object: nil)
                    }) {
                        Image(systemName: "quote.bubble")
                            .foregroundColor(ProTheme.Colors.textSecondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                }
                .frame(width: 300, alignment: .trailing)
            }
            .padding(.horizontal, ProTheme.Spacing.xl)
            .padding(.vertical, ProTheme.Spacing.md)
            .background(ProTheme.Colors.surfaceDark)
        }
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private var artworkView: some View {
        ZStack {
            if let track = engine.currentTrack, let data = track.artworkData, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.small))
            } else {
                RoundedRectangle(cornerRadius: ProTheme.Radius.small)
                    .fill(ProTheme.Colors.surfaceMedium)
                    .frame(width: 56, height: 56)
                Image(systemName: "music.note")
                    .foregroundColor(ProTheme.Colors.textTertiary)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }
    
    @ViewBuilder
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 4)
                
                // Progress
                if engine.duration > 0 {
                    let progressAmount = isDraggingSlider ? (dragPosition ?? engine.currentTime) : engine.currentTime
                    let ratio = CGFloat(progressAmount / engine.duration)
                    let w = max(0, min(geo.size.width, geo.size.width * ratio))
                    
                    Rectangle()
                        .fill(ProTheme.Colors.accentPurple)
                        .frame(width: w, height: 4)
                        .shadow(color: ProTheme.Colors.accentPurple, radius: 4)
                    
                    // Knob (visible on hover/drag)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .offset(x: w - 6)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        isDraggingSlider = true
                        let perc = max(0, min(1, val.location.x / geo.size.width))
                        dragPosition = perc * engine.duration
                    }
                    .onEnded { val in
                        let perc = max(0, min(1, val.location.x / geo.size.width))
                        engine.seekTo(perc * engine.duration)
                        isDraggingSlider = false
                        dragPosition = nil
                    }
            )
        }
        .frame(height: 4)
    }
    
    private func cycleRepeat() {
        switch engine.queue.repeatMode {
        case .off: engine.queue.repeatMode = .all
        case .all: engine.queue.repeatMode = .one
        case .one: engine.queue.repeatMode = .off
        }
    }
}
