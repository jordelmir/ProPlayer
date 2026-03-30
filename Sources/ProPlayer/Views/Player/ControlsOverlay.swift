import SwiftUI
import ProPlayerEngine

struct ControlsOverlay: View {
    @ObservedObject var viewModel: PlayerViewModel
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar
            Spacer()
            // Bottom bar
            bottomBar
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: ProTheme.Spacing.md) {
            // Close button
            Button(action: onClose) {
                controlButton(icon: "xmark.circle.fill", size: 22, tooltip: "Close Video")
                    .foregroundColor(ProTheme.Colors.textPrimary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.engine.currentItemTitle.isEmpty ? "Elysium Vanguard Pro Player 8K" : viewModel.engine.currentItemTitle)
                    .font(ProTheme.Fonts.headline)
                    .foregroundColor(ProTheme.Colors.textPrimary)
                    .lineLimit(1)

                if viewModel.engine.videoSize.width > 0 {
                    Text("\(Int(viewModel.engine.videoSize.width))×\(Int(viewModel.engine.videoSize.height)) • \(FormatUtils.speedString(Float(viewModel.engine.playbackSpeed)))")
                        .font(ProTheme.Fonts.caption)
                        .foregroundColor(ProTheme.Colors.textSecondary)
                }
            }

            Spacer()

            // Aspect ratio picker
            Menu {
                ForEach(VideoGravityMode.allCases) { mode in
                    Button {
                        viewModel.setGravityMode(mode)
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text(mode.rawValue)
                                Text(mode.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: mode.icon)
                        }
                    }
                    .disabled(viewModel.gravityMode == mode)
                }
            } label: {
                controlButton(icon: viewModel.gravityMode.icon, tooltip: "Screen Mode")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 36)

            // Speed menu
            Menu {
                ForEach(PlayerEngine.availableSpeeds, id: \.self) { speed in
                    Button(FormatUtils.speedString(Float(speed))) {
                        viewModel.engine.setSpeed(speed)
                        viewModel.showOSD("Speed: \(FormatUtils.speedString(Float(speed)))")
                    }
                    .disabled(viewModel.engine.playbackSpeed == speed)
                }
            } label: {
                controlButton(icon: "gauge.with.dots.needle.33percent", tooltip: "Speed")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 36)

            // Video info
            Button { viewModel.toggleVideoInfo() } label: {
                controlButton(icon: "info.circle", tooltip: "Video Info")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ProTheme.Spacing.xl)
        .padding(.top, ProTheme.Spacing.lg)
        .padding(.bottom, ProTheme.Spacing.xxxl)
        .background(ProTheme.Colors.topBarGradient)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: ProTheme.Spacing.sm) {
            // Timeline
            TimelineView(engine: viewModel.engine) { percent in
                viewModel.seekToPercent(percent)
            }
            .padding(.horizontal, ProTheme.Spacing.xl)

            // Controls row
            HStack(spacing: ProTheme.Spacing.lg) {
                // Left group: playback controls
                HStack(spacing: ProTheme.Spacing.md) {
                    Button { viewModel.playPrevious() } label: {
                        controlButton(icon: "backward.fill", size: 16)
                    }
                    .buttonStyle(.plain)

                    Button { viewModel.seekBackward(10) } label: {
                        controlButton(icon: "gobackward.10", size: 18)
                    }
                    .buttonStyle(.plain)

                    Button { viewModel.togglePlayPause() } label: {
                        controlButton(
                            icon: viewModel.engine.isPlaying ? "pause.fill" : "play.fill",
                            size: 22,
                            isAccent: true
                        )
                    }
                    .buttonStyle(.plain)

                    Button { viewModel.seekForward(10) } label: {
                        controlButton(icon: "goforward.10", size: 18)
                    }
                    .buttonStyle(.plain)

                    Button { viewModel.playNext() } label: {
                        controlButton(icon: "forward.fill", size: 16)
                    }
                    .buttonStyle(.plain)
                }

                // Volume
                HStack(spacing: ProTheme.Spacing.xs) {
                    Button { viewModel.toggleMute() } label: {
                        controlButton(icon: volumeIcon, size: 14)
                    }
                    .buttonStyle(.plain)

                    Slider(value: Binding(
                        get: { Double(viewModel.engine.volume) },
                        set: { viewModel.engine.volume = $0 }
                    ), in: 0...1)
                    .frame(width: 80)
                    .tint(ProTheme.Colors.accentBlue)
                }

                Spacer()

                // Right group: tools
                HStack(spacing: ProTheme.Spacing.sm) {
                    // Upscaling Quality Selector
                    HStack(spacing: 2) {
                        ForEach(SuperResolutionTier.allCases) { tier in
                            Button {
                                viewModel.setRenderingTier(tier)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: tier.icon)
                                        .font(.system(size: 8))
                                    Text(tier.shortLabel)
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(viewModel.currentRenderingTier == tier ? .white : ProTheme.Colors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(viewModel.currentRenderingTier == tier ? ProTheme.Colors.accentBlue : Color.white.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(viewModel.currentRenderingTier == tier ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(2)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .help("Upscaling Quality")

                    // A-B Loop
                    Button { viewModel.toggleLoop() } label: {
                        controlButton(
                            icon: "repeat",
                            size: 14,
                            isActive: viewModel.engine.isLooping
                        )
                    }
                    .buttonStyle(.plain)

                    // Screenshot
                    Button { viewModel.captureScreenshot() } label: {
                        controlButton(icon: "camera", size: 14)
                    }
                    .buttonStyle(.plain)

                    // PiP
                    Button {
                        viewModel.togglePiP()
                    } label: {
                        controlButton(
                            icon: viewModel.engine.isPiPActive ? "pip.exit" : "pip.enter",
                            size: 14,
                            isActive: viewModel.engine.isPiPActive
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.engine.isPiPPossible)

                    // Fullscreen
                    Button { viewModel.toggleFullscreen() } label: {
                        controlButton(
                            icon: viewModel.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                            size: 14
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ProTheme.Spacing.xl)
            .padding(.bottom, ProTheme.Spacing.lg)
        }
        .padding(.top, ProTheme.Spacing.xxxl)
        .background(ProTheme.Colors.controlsGradient)
    }

    // MARK: - Helpers

    private var volumeIcon: String {
        if viewModel.engine.isMuted || viewModel.engine.volume == 0 {
            return "speaker.slash.fill"
        } else if viewModel.engine.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if viewModel.engine.volume < 0.66 {
            return "speaker.wave.2.fill"
        }
        return "speaker.wave.3.fill"
    }

    @ViewBuilder
    private func controlButton(icon: String, size: CGFloat = 16, tooltip: String = "", isAccent: Bool = false, isActive: Bool = false) -> some View {
        Image(systemName: icon)
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(isActive ? ProTheme.Colors.accentBlue : (isAccent ? ProTheme.Colors.accentBlue : ProTheme.Colors.textPrimary))
            .shadow(color: isActive ? ProTheme.Colors.accentBlue.opacity(0.6) : (isAccent ? ProTheme.Colors.accentBlue.opacity(0.4) : .clear), radius: 6)
            .frame(width: size + 16, height: size + 16)
            .contentShape(Rectangle())
            .help(tooltip)
    }
}
