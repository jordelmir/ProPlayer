import SwiftUI
import AppKit

struct MiniPlayerView: View {
    @ObservedObject var engine = MusicPlayerEngine.shared
    
    var body: some View {
        HStack(spacing: ProTheme.Spacing.md) {
            // Artwork
            ZStack {
                if let track = engine.currentTrack, let data = track.artworkData, let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.small))
                } else {
                    RoundedRectangle(cornerRadius: ProTheme.Radius.small)
                        .fill(ProTheme.Colors.surfaceMedium)
                        .frame(width: 60, height: 60)
                    Image(systemName: "music.note")
                        .foregroundColor(ProTheme.Colors.textTertiary)
                }
                
                if engine.isPlaying {
                    VStack(spacing: 2) {
                        Spacer()
                        HStack(spacing: 2) {
                            ForEach(0..<3) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(ProTheme.Colors.accentPurple)
                                    .frame(width: 3, height: CGFloat.random(in: 4...12)) // Note: simple random for MVP
                            }
                        }
                        .padding(.bottom, 6)
                    }
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            
            // Metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.currentTrack?.title ?? "Elysium Vanguard")
                    .font(ProTheme.Fonts.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(engine.currentTrack?.artist ?? "Ready to play")
                    .font(ProTheme.Fonts.caption)
                    .foregroundColor(ProTheme.Colors.textSecondary)
                    .lineLimit(1)
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(ProTheme.Colors.surfaceDark)
                            .frame(height: 4)
                        
                        if engine.duration > 0 {
                            Capsule()
                                .fill(ProTheme.Colors.accentPurple)
                                .frame(width: max(0, geo.size.width * CGFloat(engine.currentTime / engine.duration)), height: 4)
                        }
                    }
                }
                .frame(height: 4)
                .padding(.top, 4)
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: ProTheme.Spacing.sm) {
                Button(action: { engine.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .hoverEffect()
                
                Button(action: { engine.togglePlayPause() }) {
                    Image(systemName: engine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(ProTheme.Colors.accentPurple)
                        .shadow(color: ProTheme.Colors.accentPurple.opacity(0.5), radius: 6)
                }
                .buttonStyle(.plain)
                .hoverEffect()
                
                Button(action: { engine.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .hoverEffect()
            }
        }
        .padding()
        .frame(width: 340, height: 90)
        // Background extraction logic would go here ideally to color tint
        .background(.ultraThinMaterial.opacity(0.95))
        .background(Color(red: 0.08, green: 0.1, blue: 0.15).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.large))
        .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: ProTheme.Radius.large)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
