import SwiftUI
import ProPlayerEngine
import AppKit

struct VideoGridItem: View {
    let item: VideoItem
    let onPlay: () -> Void
    let onRemove: () -> Void

    @State private var isHovered = false
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: ProTheme.Spacing.sm) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: ProTheme.Radius.medium)
                    .fill(ProTheme.Colors.surfaceDark)
                    .aspectRatio(16/9, contentMode: .fit)

                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.medium))
                } else {
                    Image(systemName: "film")
                        .font(.system(size: 32))
                        .foregroundColor(ProTheme.Colors.textTertiary)
                }

                // Play overlay on hover
                if isHovered {
                    RoundedRectangle(cornerRadius: ProTheme.Radius.medium)
                        .fill(Color.black.opacity(0.4))
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: ProTheme.Colors.accentBlue.opacity(0.5), radius: 12)
                }

                // Duration badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(item.durationLabel)
                            .font(ProTheme.Fonts.monoSmall)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                    }
                }

                // Resume indicator
                if item.hasResumePosition {
                    VStack {
                        Spacer()
                        GeometryReader { geo in
                            let progress = item.playbackPosition / max(1, item.duration)
                            Rectangle()
                                .fill(ProTheme.Colors.accentBlue)
                                .frame(width: geo.size.width * progress, height: 3)
                        }
                        .frame(height: 3)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.medium))
                }
            }
            .aspectRatio(16/9, contentMode: .fit)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(ProTheme.Fonts.subheadline)
                    .foregroundColor(ProTheme.Colors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: ProTheme.Spacing.sm) {
                    if item.width > 0 {
                        Text(item.resolutionLabel)
                            .font(ProTheme.Fonts.caption)
                            .foregroundColor(ProTheme.Colors.textSecondary)
                    }
                    Text(item.fileSizeLabel)
                        .font(ProTheme.Fonts.caption)
                        .foregroundColor(ProTheme.Colors.textTertiary)
                }

                Text(FormatUtils.relativeDateString(from: item.dateAdded))
                    .font(ProTheme.Fonts.caption)
                    .foregroundColor(ProTheme.Colors.textTertiary)
            }
        }
        .onHover { hovering in
            withAnimation(ProTheme.Animations.quick) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .shadow(color: isHovered ? ProTheme.Colors.accentBlue.opacity(0.8) : .clear, radius: 16)
        .animation(ProTheme.Animations.spring, value: isHovered)
        .onTapGesture {
            onPlay()
        }
        .contextMenu {
            Button("Play") { onPlay() }
            Button("Remove from Library") { onRemove() }
        }
        .task {
            thumbnail = await VideoMetadataExtractor.generateThumbnail(for: item.url)
        }
    }
}
