import SwiftUI
import ProPlayerEngine

struct TimelineView: View {
    @ObservedObject var engine: PlayerEngine
    let onSeek: (Double) -> Void

    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @State private var isHovering = false
    @State private var hoverProgress: Double = 0

    private var displayProgress: Double {
        isDragging ? dragProgress : engine.progressPercent
    }

    var body: some View {
        VStack(spacing: ProTheme.Spacing.xxs) {
            // Timeline bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: isHovering ? 4 : 2.5)
                        .fill(ProTheme.Colors.timelineBackground)

                    // Buffered range
                    let bufferedWidth = geo.size.width * min(1, engine.duration > 0 ? engine.bufferedTime / engine.duration : 0)
                    RoundedRectangle(cornerRadius: isHovering ? 4 : 2.5)
                        .fill(ProTheme.Colors.timelineBuffer)
                        .frame(width: max(0, bufferedWidth))

                    // A-B Loop region
                    if let a = engine.loopA {
                        let aPos = geo.size.width * (engine.duration > 0 ? a / engine.duration : 0)
                        let bPos: CGFloat = {
                            if let b = engine.loopB {
                                return geo.size.width * (engine.duration > 0 ? b / engine.duration : 0)
                            }
                            return aPos + 2
                        }()

                        Rectangle()
                            .fill(ProTheme.Colors.accentOrange.opacity(0.3))
                            .frame(width: max(0, bPos - aPos))
                            .offset(x: aPos)
                    }

                    // Progress
                    let progressWidth = geo.size.width * displayProgress
                    RoundedRectangle(cornerRadius: isHovering ? 4 : 2.5)
                        .fill(ProTheme.Colors.accentGradient)
                        .shadow(color: ProTheme.Colors.accentBlue.opacity(0.5), radius: isHovering ? 6 : 0)
                        .frame(width: max(0, min(geo.size.width, progressWidth)))

                    // Thumb
                    if isHovering || isDragging {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: ProTheme.Colors.accentBlue.opacity(0.5), radius: 4)
                            .offset(x: max(0, min(geo.size.width - 14, progressWidth - 7)))
                    }

                    // Hover time tooltip
                    if isHovering && !isDragging {
                        let hoverTime = engine.duration * hoverProgress
                        Text(FormatUtils.timeString(from: hoverTime))
                            .font(ProTheme.Fonts.monoSmall)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .offset(x: max(20, min(geo.size.width - 50, geo.size.width * hoverProgress - 25)),
                                    y: -24)
                    }
                }
                .frame(height: isHovering ? 8 : 5)
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(ProTheme.Animations.quick) {
                        isHovering = hovering
                    }
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point):
                        hoverProgress = max(0, min(1, point.x / geo.size.width))
                    case .ended:
                        break
                    @unknown default:
                        break
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dragProgress = max(0, min(1, value.location.x / geo.size.width))
                        }
                        .onEnded { value in
                            let percent = max(0, min(1, value.location.x / geo.size.width))
                            onSeek(percent)
                            isDragging = false
                        }
                )
            }
            .frame(height: isHovering ? 8 : 5)
            .animation(ProTheme.Animations.quick, value: isHovering)

            // Time labels
            HStack {
                Text(FormatUtils.timeString(from: isDragging ? engine.duration * dragProgress : engine.currentTime))
                    .font(ProTheme.Fonts.monoSmall)
                    .foregroundColor(ProTheme.Colors.textPrimary)

                Spacer()

                Text("-\(FormatUtils.timeString(from: engine.remainingTime))")
                    .font(ProTheme.Fonts.monoSmall)
                    .foregroundColor(ProTheme.Colors.textSecondary)
            }
        }
    }
}
