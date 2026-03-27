import SwiftUI
import AVKit
import ProPlayerEngine

struct PlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    var onClose: () -> Void

    var body: some View {
        ZStack {
            // Background
            ProTheme.Colors.deepBlack.ignoresSafeArea()

            // Video layer
            videoContent
                .ignoresSafeArea()

            // Controls overlay
            if viewModel.showControls || !viewModel.engine.isPlaying {
                ControlsOverlay(viewModel: viewModel, onClose: onClose)
                    .transition(.opacity)
            }

            // OSD
            if let msg = viewModel.osdMessage {
                VStack {
                    HStack {
                        Spacer()
                        OSDView(message: msg)
                            .padding(ProTheme.Spacing.xl)
                    }
                    Spacer()
                }
                .animation(ProTheme.Animations.standard, value: viewModel.osdMessage)
            }

            // Video info panel
            if viewModel.showingVideoInfo {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VideoInfoOverlay(engine: viewModel.engine)
                            .padding(ProTheme.Spacing.xl)
                    }
                }
                .animation(ProTheme.Animations.smooth, value: viewModel.showingVideoInfo)
            }

            // Loading indicator
            if viewModel.engine.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(.circular)
                    .tint(ProTheme.Colors.accentBlue)
            }

            // Error message
            if let error = viewModel.engine.error {
                VStack(spacing: ProTheme.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(ProTheme.Colors.accentOrange)
                    Text(error.localizedDescription)
                        .font(ProTheme.Fonts.subheadline)
                        .foregroundColor(ProTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Cerrar") {
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ProTheme.Colors.accentBlue)
                }
                .padding()
                .background(ProTheme.Colors.deepBlack.opacity(0.8))
                .cornerRadius(12)
            }
        }
        .onHover { hovering in
            if hovering { viewModel.handleMouseMoved() }
        }
        .onTapGesture(count: 2) {
            viewModel.toggleFullscreen()
        }
        .onTapGesture(count: 1) {
            withAnimation(ProTheme.Animations.standard) {
                if viewModel.showControls && viewModel.engine.isPlaying {
                    viewModel.showControls = false
                } else {
                    viewModel.resetControlsTimer()
                }
            }
        }
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    if viewModel.gravityMode == .customZoom {
                        viewModel.customZoomScale = max(0.5, min(5.0, value.magnification))
                    }
                }
        )
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .background(KeyboardHandler(viewModel: viewModel))
        .contextMenu { contextMenu }
    }

    // MARK: - Video Content

    @ViewBuilder
    private var videoContent: some View {
        MetalPlayerView(engine: viewModel.engine)
            .ignoresSafeArea()
            // Custom zoom/scaling is now handled by the Metal renderer's projection matrix (todo)
            // or by SwiftUI scale effect for now.
            .scaleEffect(viewModel.gravityMode == .customZoom ? viewModel.customZoomScale : 1.0)
            .offset(viewModel.gravityMode == .customZoom ? viewModel.customZoomOffset : .zero)
            .animation(ProTheme.Animations.standard, value: viewModel.gravityMode)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenu: some View {
        Button(viewModel.engine.isPlaying ? "Pause" : "Play") {
            viewModel.togglePlayPause()
        }
        Divider()

        Menu("Screen Mode") {
            ForEach(VideoGravityMode.allCases) { mode in
                Button {
                    viewModel.setGravityMode(mode)
                } label: {
                    HStack {
                        Text(mode.rawValue)
                        if viewModel.gravityMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        Menu("Speed") {
            ForEach(PlayerEngine.availableSpeeds, id: \.self) { speed in
                Button(FormatUtils.speedString(speed)) {
                    viewModel.engine.setSpeed(speed)
                }
            }
        }

        Divider()

        Button("Screenshot") { viewModel.captureScreenshot() }
        Button("Video Info") { viewModel.toggleVideoInfo() }

        Divider()

        Button(viewModel.isFullscreen ? "Exit Fullscreen" : "Enter Fullscreen") {
            viewModel.toggleFullscreen()
        }
    }

    // MARK: - Drop Handler

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url, VideoItem.isVideoFile(url) else { return }
                Task { @MainActor in
                    viewModel.openFile(url: url)
                }
            }
        }
        return true
    }
}

// MARK: - Keyboard Handler

struct KeyboardHandler: NSViewRepresentable {
    let viewModel: PlayerViewModel

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.viewModel = viewModel
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.viewModel = viewModel
    }
}

class KeyCaptureView: NSView {
    var viewModel: PlayerViewModel?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard let vm = viewModel else { return }

        switch event.keyCode {
        case 49: // Space
            Task { @MainActor in vm.togglePlayPause() }
        case 123: // Left arrow
            Task { @MainActor in vm.seekBackward(event.modifierFlags.contains(.shift) ? 30 : 5) }
        case 124: // Right arrow
            Task { @MainActor in vm.seekForward(event.modifierFlags.contains(.shift) ? 30 : 5) }
        case 126: // Up arrow
            Task { @MainActor in vm.volumeUp() }
        case 125: // Down arrow
            Task { @MainActor in vm.volumeDown() }
        case 3: // F
            Task { @MainActor in vm.toggleFullscreen() }
        case 46: // M
            Task { @MainActor in vm.toggleMute() }
        case 1: // S
            Task { @MainActor in vm.captureScreenshot() }
        case 33: // [
            Task { @MainActor in vm.speedDown() }
        case 30: // ]
            Task { @MainActor in vm.speedUp() }
        case 34: // I
            if event.modifierFlags.contains(.command) {
                Task { @MainActor in vm.toggleVideoInfo() }
            }
        case 38: // J
            Task { @MainActor in vm.seekBackward(10) }
        case 40: // K
            Task { @MainActor in vm.togglePlayPause() }
        case 37: // L
            Task { @MainActor in vm.seekForward(10) }
        case 0: // A (cycle aspect)
            Task { @MainActor in vm.cycleGravityMode() }
        case 15: // R (loop)
            Task { @MainActor in vm.toggleLoop() }
        default:
            super.keyDown(with: event)
        }
    }
}
