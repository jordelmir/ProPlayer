import SwiftUI
import AVFoundation
import ProPlayerEngine

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var engine: PlayerEngine = PlayerEngine()
    @Published var gravityMode: VideoGravityMode = .fill {
        didSet {
            engine.gravityMode = gravityMode
            // If the view is active, update the renderer directly
            engine.renderer.gravityMode = gravityMode
        }
    }
    @Published var showControls = true {
        didSet {
            // Cinema mode: hide/show cursor with controls
            if showControls {
                NSCursor.unhide()
            } else if engine.isPlaying {
                NSCursor.hide()
            }
        }
    }
    @Published var isFullscreen = false
    @Published var osdMessage: String?
    @Published var showingVideoInfo = false
    @Published var currentVideoItem: VideoItem?
    @Published var playlist = Playlist()
    @Published var customZoomScale: CGFloat = 1.0
    @Published var customZoomOffset: CGSize = .zero
    @Published var matrixIntensity: Double = 0.0 { didSet { engine.matrixIntensity = matrixIntensity } }
    @Published var settings = PlayerSettings.load() {
        didSet {
            engine.renderer.gravityMode = settings.defaultGravityMode
            engine.renderer.renderingTier = settings.renderingTier
            engine.renderer.ambientIntensity = settings.ambientIntensity
            engine.renderer.colorTemperature = settings.colorTemperature
            engine.renderer.filmGrainIntensity = settings.filmGrainIntensity
            engine.renderer.enableToneMapping = settings.enableToneMapping
            engine.renderer.enableTNR = settings.enableTNR
            settings.save()
        }
    }

    // Video adjustments
    @Published var brightness: Double = 0
    @Published var contrast: Double = 1
    @Published var saturation: Double = 1

    // Robust controls auto-hide
    private var controlsTask: Task<Void, Never>?
    private var osdTask: Task<Void, Never>?

    init() {
        gravityMode = .stretch
        engine.volume = Double(settings.defaultVolume)
        engine.renderer.gravityMode = .stretch
        engine.renderer.renderingTier = settings.renderingTier
        engine.renderer.ambientIntensity = settings.ambientIntensity
        engine.renderer.colorTemperature = settings.colorTemperature
        engine.renderer.filmGrainIntensity = settings.filmGrainIntensity
        engine.renderer.enableToneMapping = settings.enableToneMapping
        engine.renderer.enableTNR = settings.enableTNR
        setupNotifications()
    }
    
    deinit {
        // Ensure cursor is visible when ViewModel is deallocated
        NSCursor.unhide()
    }
    
    private func setupNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: .proPlayerTogglePlayPause, object: nil, queue: .main) { _ in Task { @MainActor in self.togglePlayPause() } }
        nc.addObserver(forName: .proPlayerSeekForward, object: nil, queue: .main) { n in Task { @MainActor in self.seekForward((n.object as? Double) ?? 5) } }
        nc.addObserver(forName: .proPlayerSeekBackward, object: nil, queue: .main) { n in Task { @MainActor in self.seekBackward((n.object as? Double) ?? 5) } }
        nc.addObserver(forName: .proPlayerSpeedUp, object: nil, queue: .main) { _ in Task { @MainActor in self.speedUp() } }
        nc.addObserver(forName: .proPlayerSpeedDown, object: nil, queue: .main) { _ in Task { @MainActor in self.speedDown() } }
        nc.addObserver(forName: .proPlayerCycleGravity, object: nil, queue: .main) { _ in Task { @MainActor in self.cycleGravityMode() } }
        nc.addObserver(forName: .proPlayerScreenshot, object: nil, queue: .main) { _ in Task { @MainActor in self.captureScreenshot() } }
        nc.addObserver(forName: .proPlayerToggleInfo, object: nil, queue: .main) { _ in Task { @MainActor in self.toggleVideoInfo() } }
        nc.addObserver(forName: .proPlayerVolumeUp, object: nil, queue: .main) { _ in Task { @MainActor in self.volumeUp() } }
        nc.addObserver(forName: .proPlayerVolumeDown, object: nil, queue: .main) { _ in Task { @MainActor in self.volumeDown() } }
        nc.addObserver(forName: .proPlayerToggleMute, object: nil, queue: .main) { _ in Task { @MainActor in self.toggleMute() } }
        nc.addObserver(forName: .proPlayerToggleFullscreen, object: nil, queue: .main) { _ in Task { @MainActor in self.toggleFullscreen() } }
        
        // Fullscreen state sync — tracks green button and Mission Control transitions
        nc.addObserver(forName: NSWindow.didEnterFullScreenNotification, object: nil, queue: .main) { _ in Task { @MainActor in self.isFullscreen = true } }
        nc.addObserver(forName: NSWindow.didExitFullScreenNotification, object: nil, queue: .main) { _ in Task { @MainActor in self.isFullscreen = false } }
    }

    // MARK: - File Loading

    func openFile(url: URL) {
        // Stop previous instance if any
        engine.stop()
        
        // Load and Play
        engine.loadFile(url: url)
        engine.play()
        
        showOSD("En vivo: \(url.deletingPathExtension().lastPathComponent)")
        resetControlsTimer()
        
        // Force an immediate UI refresh for the player
        objectWillChange.send()
    }

    func openFiles(urls: [URL]) {
        playlist = Playlist(items: urls.map { VideoItem(url: $0) })
        if let first = urls.first {
            openFile(url: first)
        }
    }

    // MARK: - Playback

    func togglePlayPause() {
        engine.togglePlayPause()
        showOSD(engine.isPlaying ? "▶ Play" : "⏸ Paused")
        
        // Show cursor when paused
        if !engine.isPlaying {
            NSCursor.unhide()
        }
    }

    func stop() {
        engine.stop()
        NSCursor.unhide()
        showOSD("⏹ Stopped")
    }

    func seekForward(_ seconds: Double = 5) {
        engine.seekRelative(seconds)
        showOSD("⏩ +\(Int(seconds))s")
    }

    func seekBackward(_ seconds: Double = 5) {
        engine.seekRelative(-seconds)
        showOSD("⏪ -\(Int(seconds))s")
    }

    func seekToPercent(_ percent: Double) {
        engine.seekToPercent(percent)
    }

    // MARK: - Volume

    func volumeUp() {
        engine.adjustVolume(by: 0.05)
        showOSD("🔊 Volume: \(Int(engine.volume * 100))%")
    }

    func volumeDown() {
        engine.adjustVolume(by: -0.05)
        showOSD("🔉 Volume: \(Int(engine.volume * 100))%")
    }

    func toggleMute() {
        engine.toggleMute()
        showOSD(engine.isMuted ? "🔇 Muted" : "🔊 Volume: \(Int(engine.volume * 100))%")
    }

    // MARK: - Speed

    func speedUp() {
        engine.cycleSpeedUp()
        showOSD("Speed: \(FormatUtils.speedString(Float(engine.playbackSpeed)))")
    }

    func speedDown() {
        engine.cycleSpeedDown()
        showOSD("Speed: \(FormatUtils.speedString(Float(engine.playbackSpeed)))")
    }

    // MARK: - Video Gravity

    func cycleGravityMode() {
        let modes = VideoGravityMode.allCases
        guard let idx = modes.firstIndex(of: gravityMode) else { return }
        let nextIdx = (idx + 1) % modes.count
        gravityMode = modes[nextIdx]

        // Reset zoom when leaving custom zoom mode
        if gravityMode != .customZoom {
            customZoomScale = 1.0
            customZoomOffset = .zero
        }

        showOSD("📐 \(gravityMode.rawValue)")
    }

    func setGravityMode(_ mode: VideoGravityMode) {
        gravityMode = mode
        if mode != .customZoom {
            customZoomScale = 1.0
            customZoomOffset = .zero
        }
        showOSD("📐 \(mode.rawValue)")
    }

    // MARK: - Upscaling
    
    var currentRenderingTier: SuperResolutionTier {
        settings.renderingTier
    }
    
    func setRenderingTier(_ tier: SuperResolutionTier) {
        settings.renderingTier = tier
        showOSD("✨ Upscaling: \(tier.rawValue)")
    }

    // MARK: - A-B Loop

    func toggleLoop() {
        engine.toggleLoop()
        if engine.isLooping {
            showOSD("🔁 Loop: \(FormatUtils.timeString(from: engine.loopA!)) → \(FormatUtils.timeString(from: engine.loopB!))")
        } else if engine.loopA != nil {
            showOSD("🔁 Loop Start: \(FormatUtils.timeString(from: engine.loopA!))")
        } else {
            showOSD("🔁 Loop Cleared")
        }
    }

    // MARK: - Screenshot

    func captureScreenshot() {
        let url = URL(fileURLWithPath: settings.screenshotSavePath)
        engine.captureScreenshot(savePath: url)
        showOSD("📸 Screenshot Saved")
    }

    // MARK: - Fullscreen

    func toggleFullscreen() {
        // Try to find the window that is currently active or the main one
        let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first { $0.isVisible }
        guard let targetWindow = window else { return }
        
        targetWindow.toggleFullScreen(nil)
        // Note: isFullscreen is now synced via NSWindow notifications, not manual toggle
    }
    
    // MARK: - Picture in Picture
    
    func setupPiP(with layer: AVPlayerLayer) {
        engine.setupPiP(with: layer)
    }
    
    func togglePiP() {
        engine.togglePiP()
    }

    // MARK: - Playlist

    func playNext() {
        if var pl = Optional(playlist), let next = pl.next() {
            playlist = pl
            openFile(url: next.url)
        }
    }

    func playPrevious() {
        if engine.currentTime > 3 {
            engine.seek(to: 0)
            return
        }
        if var pl = Optional(playlist), let prev = pl.previous() {
            playlist = pl
            openFile(url: prev.url)
        }
    }

    // MARK: - Controls Visibility

    func resetControlsTimer() {
        showControls = true
        controlsTask?.cancel()
        controlsTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(settings.controlsAutoHideDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            
            if engine.isPlaying {
                withAnimation(ProTheme.Animations.smooth) {
                    showControls = false
                }
            }
        }
    }

    func handleMouseMoved() {
        resetControlsTimer()
    }

    // MARK: - OSD

    func showOSD(_ message: String) {
        guard settings.showOSD else { return }
        
        withAnimation(ProTheme.Animations.standard) {
            osdMessage = message
        }
        
        osdTask?.cancel()
        osdTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(settings.osdDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            
            withAnimation(ProTheme.Animations.smooth) {
                if self.osdMessage == message {
                    self.osdMessage = nil
                }
            }
        }
    }

    // MARK: - Video Info

    func toggleVideoInfo() {
        showingVideoInfo.toggle()
    }
}
