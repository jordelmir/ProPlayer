import SwiftUI

struct MusicGridItem: View {
    let item: MusicMetadata
    let onEdit: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: ProTheme.Spacing.md) {
            // Album Cover Container
            ZStack {
                if let data = item.artworkData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Modern Placeholder
                    ZStack {
                        ProTheme.Colors.surfaceDark
                        Image(systemName: "music.note")
                            .font(.system(size: 40, weight: .thin))
                            .foregroundColor(ProTheme.Colors.accentBlue.opacity(0.3))
                        
                        // Subtle Glow Overlay
                        Circle()
                            .fill(ProTheme.Colors.accentPurple.opacity(0.1))
                            .blur(radius: 40)
                    }
                }
                
                // Play/Edit Overlay on Hover
                if isHovered {
                    ZStack {
                        Color.black.opacity(0.4)
                        Button(action: onEdit) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.white)
                                .shadow(color: ProTheme.Colors.accentBlue, radius: 10)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.large))
            .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: ProTheme.Radius.large)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            
            // Text Info
            VStack(alignment: .leading, spacing: ProTheme.Spacing.xxs) {
                Text(item.title)
                    .font(ProTheme.Fonts.headline)
                    .foregroundColor(ProTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Text(item.artist)
                    .font(ProTheme.Fonts.subheadline)
                    .foregroundColor(ProTheme.Colors.textSecondary)
                    .lineLimit(1)
                
                if !item.album.isEmpty && item.album != "Unknown Album" {
                    Text(item.album)
                        .font(ProTheme.Fonts.caption)
                        .foregroundColor(ProTheme.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 200)
        .padding(ProTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ProTheme.Radius.xl)
                .fill(isHovered ? Color.white.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(ProTheme.Animations.interactive) {
                isHovered = hovering
            }
        }
    }
}
