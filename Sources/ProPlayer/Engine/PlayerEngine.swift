import Foundation
@preconcurrency import AVFoundation
import AVKit
import Combine
import AppKit

// MARK: - Finite State Machine

/// The single source of truth for playback state.
public enum PlaybackState: Sendable, Equatable {
    case idle
    case loading
    case readyToPlay
    case playing
    case paused
    case buffering
    case stalled
    case failed(PlayerError)
}

/// Normalized events that drive state transitions.
public enum PlayerEvent: Sendable, Equatable {
    case itemReady(duration: Double)
    case itemFailed(PlayerError)
    case bufferEmpty
    case bufferRecovered
    case playbackEnded
    case systemSleep
    case systemWake
    case userPlay
    case userPause
    case userStop
    case userLoad
}

/// Seek state machine — prevents corruption during rapid seeks.
public enum SeekState: Equatable {
    case idle
    case seeking(target: Double)
}

/// Structured, actionable error model.
public enum PlayerError: Error, Identifiable, Equatable, Sendable {
    case network(String)
    case decoding(String)
    case assetUnavailable
    case codecNotSupported
    case validationFailed(String)
    case unknown(String)
    
    public var id: String {
        switch self {
        case .network(let m): return "net_\(m)"
        case .decoding(let m): return "dec_\(m)"
        case .assetUnavailable: return "unavailable"
        case .codecNotSupported: return "codec"
        case .validationFailed(let m): return "val_\(m)"
        case .unknown(let m): return "unk_\(m)"
        }
    }
}

// MARK: - Buffer Policy

struct BufferPolicy {
    let preferredForwardBuffer: TimeInterval = 5
    let minBufferToResume: TimeInterval = 2
    let debounceInterval: TimeInterval = 0.5
}

// MARK: - Playback Metrics

public struct PlaybackMetrics: Sendable {
    public let startupTime: TimeInterval
    public let stallCount: Int
    public let averageBitrate: Double
    public let totalBytesTransferred: Int64
    
    public static let zero = PlaybackMetrics(startupTime: 0, stallCount: 0, averageBitrate: 0, totalBytesTransferred: 0)
}

// MARK: - OTT Platform-Grade Engine

@MainActor
public final class PlayerEngine: NSObject, ObservableObject, @unchecked Sendable, VideoDisplayLinkDelegate, AVPictureInPictureControllerDelegate {

    // MARK: - State Machine (Single Source of Truth)
    @Published public private(set) var state: PlaybackState = .idle
    
    public var isPlaying: Bool { state == .playing }
    public var isLoading: Bool { state == .loading || state == .buffering }

    // MARK: - Published Media State
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var bufferedTime: Double = 0
    @Published public var volume: Float = 0.8 { didSet { driver.player.volume = volume } }
    @Published public var isMuted = false { didSet { driver.player.isMuted = isMuted } }
    @Published public var playbackSpeed: Float = 1.0 { didSet { applyRate() } }
    @Published public var videoSize: CGSize = .zero
    @Published public var currentItemTitle: String = ""
    @Published public var error: PlayerError?

    // Performance Telemetry (v7.2)
    @Published public private(set) var currentFPS: Double = 0
    @Published public private(set) var frameDropCount: Int = 0
    @Published public private(set) var frameJitter: Double = 0
    private var lastFrameTimestamp: CFTimeInterval = 0

    // A-B Loop
    @Published public var loopA: Double?
    @Published public var loopB: Double?
    public var isLooping: Bool { loopA != nil && loopB != nil }

    // PiP
    @Published public var isPiPActive = false
    @Published public var isPiPPossible = false
    
    // Seek
    @Published private(set) var seekState: SeekState = .idle

    // MARK: - Internal Components
    private let core = PlayerCore()
    private let validator = AssetValidator()
    private let driver: PlayerDriver
    private let bufferPolicy = BufferPolicy()
    private let eventLog = RingBuffer<LoggedEvent>(capacity: 512)
    private var eventCounter: UInt64 = 0
    
    // Custom Video Rendering Pipeline
    public let frameExtractor = VideoFrameExtractor()
    public let displayLink = VideoDisplayLink()
    
    /// Public access to the AVPlayer (for AVPlayerLayer binding).
    public var player: AVPlayer { driver.player }
    
    // Observer tokens
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var timeRangeObserver: NSKeyValueObservation?
    private var sizeObserver: NSKeyValueObservation?
    private var bufferEmptyObserver: NSKeyValueObservation?
    private var bufferFullObserver: NSKeyValueObservation?
    private var pipPossibleObserver: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var memoryObserver: NSObjectProtocol?
    private var playbackActivity: NSObjectProtocol?
    
    private var pipController: AVPictureInPictureController?
    private var wasPlayingBeforeInterruption = false
    
    // Anti-flapping
    private var bufferDebounceTask: Task<Void, Never>?
    
    // Event coalescing
    private var lastTimeUpdateEmit: UInt64 = 0
    private var lastBufferUpdateEmit: UInt64 = 0
    private static let timeCoalesceNanos: UInt64 = 250_000_000  // 250ms
    private static let bufferCoalesceNanos: UInt64 = 500_000_000 // 500ms
    
    // Metrics
    private var loadStartTime: Date?
    private var stallCounter: Int = 0
    private var retryCount: Int = 0
    private let maxRetries: Int = 1

    // MARK: - Init and Lifecycle

    public init(driver: PlayerDriver = AVPlayerDriver()) {
        self.driver = driver
        super.init()
        self.driver.player.volume = volume
        setupObservers() // Renamed from setupTimeObserver
        setupSystemObservers()
        displayLink.setDelegate(self)
    }

    public func shutdown() {
        send(.userStop)
        driver.pause()
        driver.replaceItem(with: nil)
        cleanupAllObservers()
        endPlaybackActivity()
    }

    // MARK: - Pure FSM Reducer

    private static func reduce(state: PlaybackState, event: PlayerEvent) -> PlaybackState {
        switch (state, event) {
        case (_, .userLoad):
            return .loading
        case (.loading, .itemReady):
            return .readyToPlay
        case (.readyToPlay, .userPlay),
             (.paused, .userPlay),
             (.buffering, .bufferRecovered):
            return .playing
        case (.playing, .userPause),
             (.buffering, .userPause):
            return .paused
        case (.playing, .bufferEmpty):
            return .buffering
        case (.playing, .playbackEnded),
             (.buffering, .playbackEnded):
            return .paused
        case (_, .userStop):
            return .idle
        case (.playing, .systemSleep),
             (.buffering, .systemSleep):
            return .paused
        case (_, .itemFailed(let err)):
            return .failed(err)
        default:
            return state
        }
    }

    // MARK: - Event Dispatcher (Single Entry Point)

    public func send(_ event: PlayerEvent) {
        let oldState = state
        let newState = Self.reduce(state: oldState, event: event)
        
        // Log EVERY event (even no-ops for replay fidelity)
        logEvent(event, before: oldState, after: newState)
        
        guard newState != oldState else { return }
        state = newState
        applySideEffects(old: oldState, new: newState, event: event)
        validateInvariants(state: newState)
    }

    private func logEvent(_ event: PlayerEvent, before: PlaybackState, after: PlaybackState) {
        eventCounter += 1
        let logged = LoggedEvent(
            id: eventCounter,
            timestamp: mach_absolute_time(),
            event: event,
            stateBefore: before,
            stateAfter: after
        )
        eventLog.append(logged)
    }

    private func applySideEffects(old: PlaybackState, new: PlaybackState, event: PlayerEvent) {
        switch (new, event) {
        case (.playing, _):
            applyRate()
            displayLink.start()
            if old != .playing { startPlaybackActivity() }
        case (.paused, .systemSleep):
            driver.pause()
            displayLink.stop()
            wasPlayingBeforeInterruption = true
            endPlaybackActivity()
        case (.paused, .playbackEnded):
            currentTime = 0
            displayLink.stop()
            endPlaybackActivity()
        case (.paused, _):
            driver.pause()
            displayLink.stop()
            endPlaybackActivity()
        case (.readyToPlay, let .itemReady(dur)):
            duration = dur
        case (.buffering, .bufferEmpty):
            stallCounter += 1
        case (.idle, _):
            displayLink.stop()
            error = nil
            endPlaybackActivity()
        case (.loading, _):
            displayLink.stop()
            error = nil
        case (.failed(let err), _):
            displayLink.stop()
            error = err
            endPlaybackActivity()
            attemptSoftReset()
        default:
            break
        }
    }

    private func validateInvariants(state: PlaybackState) {
        // Formal protection of FSM state invariants
        switch state {
        case .idle:
            assert(seekState == .idle, "Invariant violation: Cannot have active seekState while idle")
        case .playing:
            assert(error == nil, "Invariant violation: Cannot be playing while in error state")
        case .failed(let err):
            assert(error == err, "Invariant violation: Engine error must match failed state error")
        default:
            break
        }
    }

    private func attemptSoftReset() {
        guard retryCount < maxRetries, let url = (driver.player.currentItem?.asset as? AVURLAsset)?.url else { return }
        retryCount += 1
        let currentError = error
        
        Task { @MainActor in
            // 1 second backoff before retry
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled, let stateError = self.error, stateError == currentError else { return }
            // Restart the load process
            self.loadFile(url: url)
            self.send(.userPlay) // Auto-resume
        }
    }

    // MARK: - Event Log Access (for debugging / replay)

    /// Returns the last N logged events for diagnostics.
    public func recentEvents(_ count: Int = 50) -> [LoggedEvent] {
        eventLog.last(count)
    }
    
    /// Replays a sequence of events to verify determinism.
    public static func replay(events: [PlayerEvent]) -> PlaybackState {
        var state: PlaybackState = .idle
        for event in events {
            state = reduce(state: state, event: event)
        }
        return state
    }

    // MARK: - Media Loading (with deep validation)

    public func loadFile(url: URL) {
        send(.userLoad)
        error = nil
        currentItemTitle = url.deletingPathExtension().lastPathComponent
        clearLoop()
        loadStartTime = Date()
        stallCounter = 0
        if retryCount == 0 { } else if self.error == nil { retryCount = 0 } // Only preserve retryCount if recovering
        if case .failed = self.state { } else { retryCount = 0 }
        seekState = .idle
        
        Task {
            // Deep validation BEFORE touching AVPlayer
            let validation = await validator.validate(url: url)
            
            guard validation.isValid else {
                let reason: PlayerError
                switch validation.rejection {
                case .notPlayable: reason = .codecNotSupported
                case .zeroDuration: reason = .validationFailed("Duración cero")
                case .noPlayableTracks: reason = .validationFailed("Sin tracks reproducibles")
                case .fileTooLarge(let size):
                    reason = .validationFailed("Archivo demasiado grande: \(size / 1_000_000)MB")
                case .fileNotReadable: reason = .assetUnavailable
                case .timeout: reason = .validationFailed("Timeout en carga inicial")
                case .none: reason = .unknown("Validación fallida")
                }
                self.send(.itemFailed(reason))
                return
            }
            
            // Release previous item explicitly (memory pressure)
            self.driver.replaceItem(with: nil)
            self.frameExtractor.attach(to: nil)
            
            do {
                _ = try await core.loadMetadata(at: url)
                let item = AVPlayerItem(url: url)
                item.preferredForwardBufferDuration = bufferPolicy.preferredForwardBuffer
                setupItemObservers(for: item)
                self.driver.replaceItem(with: item)
                self.frameExtractor.attach(to: item)
            } catch let urlError as URLError {
                self.send(.itemFailed(.network(urlError.localizedDescription)))
            } catch {
                self.send(.itemFailed(.unknown(error.localizedDescription)))
            }
        }
    }

    private func setupItemObservers(for item: AVPlayerItem) {
        statusObserver?.invalidate()
        timeRangeObserver?.invalidate()
        sizeObserver?.invalidate()
        bufferEmptyObserver?.invalidate()
        bufferFullObserver?.invalidate()
        bufferDebounceTask?.cancel()
        if let e = endObserver { NotificationCenter.default.removeObserver(e) }
        
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let status = item.status
            let dur = item.duration.seconds
            let err = item.error
            Task { @MainActor in
                guard let self = self else { return }
                switch status {
                case .readyToPlay:
                    self.send(.itemReady(duration: dur.isFinite ? dur : 0))
                case .failed:
                    self.send(.itemFailed(self.classifyError(err)))
                default: break
                }
            }
        }
        
        // Buffer ranges (data update, coalesced)
        timeRangeObserver = item.observe(\.loadedTimeRanges, options: [.new]) { [weak self] item, _ in
            if let range = item.loadedTimeRanges.first?.timeRangeValue {
                let buffered = range.start.seconds + range.duration.seconds
                let now = mach_absolute_time()
                Task { @MainActor in
                    guard let self = self else { return }
                    if now - self.lastBufferUpdateEmit > Self.bufferCoalesceNanos {
                        self.bufferedTime = buffered
                        self.lastBufferUpdateEmit = now
                    }
                }
            }
        }
        
        // Video size (data, immediate)
        sizeObserver = item.observe(\.presentationSize, options: [.new]) { [weak self] item, _ in
            let size = item.presentationSize
            Task { @MainActor in
                if size.width > 0 { self?.videoSize = size }
            }
        }
        
        // Buffer empty → event (immediate, critical)
        bufferEmptyObserver = item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] item, _ in
            let empty = item.isPlaybackBufferEmpty
            Task { @MainActor in
                if empty { self?.send(.bufferEmpty) }
            }
        }
        
        // Buffer recovery → event (debounced, anti-flapping)
        bufferFullObserver = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
            let ready = item.isPlaybackLikelyToKeepUp
            let buffered = item.loadedTimeRanges.first?.timeRangeValue.duration.seconds ?? 0
            Task { @MainActor in
                guard let self = self, ready else { return }
                self.debouncedBufferRecovery(buffered: buffered)
            }
        }
        
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.send(.playbackEnded) }
        }
    }

    private func debouncedBufferRecovery(buffered: Double) {
        bufferDebounceTask?.cancel()
        guard state == .buffering else { return }
        guard buffered >= bufferPolicy.minBufferToResume else { return }
        
        bufferDebounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(bufferPolicy.debounceInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.send(.bufferRecovered)
        }
    }

    private func classifyError(_ error: Error?) -> PlayerError {
        guard let err = error else { return .unknown("Error desconocido") }
        let nsErr = err as NSError
        if nsErr.domain == NSURLErrorDomain {
            return .network(nsErr.localizedDescription)
        }
        if nsErr.domain == AVFoundationErrorDomain {
            switch nsErr.code {
            case AVError.fileFormatNotRecognized.rawValue,
                 AVError.decoderNotFound.rawValue:
                return .decoding(nsErr.localizedDescription)
            case AVError.fileFailedToParse.rawValue:
                return .assetUnavailable
            default:
                return .unknown(nsErr.localizedDescription)
            }
        }
        return .unknown(nsErr.localizedDescription)
    }

    // MARK: - Public Playback API

    public func play() { send(.userPlay) }
    public func pause() { send(.userPause) }
    public func togglePlayPause() { isPlaying ? pause() : play() }

    public func stop() {
        send(.userStop)
        seek(to: 0)
    }

    // MARK: - Seek (with state correctness)

    public func seek(to targetTime: Double) {
        let clamped = max(0, min(targetTime, duration))
        
        // Idempotency: avoid redundant seeks
        if seekState == .idle && abs(currentTime - clamped) < 0.1 { return }
        
        seekState = .seeking(target: clamped)
        
        let time = CMTime(seconds: clamped, preferredTimescale: 600)
        driver.seek(to: time) { [weak self] finished in
            Task { @MainActor in
                guard let self = self else { return }
                // Only commit if this is still the latest seek
                if case .seeking(let target) = self.seekState, target == clamped {
                    self.currentTime = clamped
                    self.seekState = .idle
                }
            }
        }
        // Optimistic update for UI responsiveness
        currentTime = clamped
    }
    
    public func seekRelative(_ delta: Double) { seek(to: currentTime + delta) }
    public func seekToPercent(_ pt: Double) { seek(to: duration * max(0, min(1, pt))) }

    private func applyRate() {
        driver.play(rate: isPlaying ? playbackSpeed : 0)
    }

    // MARK: - Time Monitoring (coalesced)

    // MARK: - Observers
    
    private func setupObservers() {
        setupTimeObserver()
        setupPiPPossibleObserver()
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = driver.addPeriodicTimeObserver(interval: interval, queue: .main) { [weak self] time in
            let now = mach_absolute_time()
            Task { @MainActor in
                guard let self = self else { return }
                // Coalesce: emit time updates at most every 250ms to UI
                if now - self.lastTimeUpdateEmit > Self.timeCoalesceNanos || self.seekState != .idle {
                    self.currentTime = time.seconds
                    self.lastTimeUpdateEmit = now
                }
                // A-B loop check (always, not coalesced)
                if let a = self.loopA, let b = self.loopB, time.seconds >= b {
                    self.seek(to: a)
                }
            }
        }
    }

    // MARK: - System Resilience (macOS)

    private func setupSystemObservers() {
        sleepObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.send(.systemSleep) }
        }
        
        wakeObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.wasPlayingBeforeInterruption {
                    self.wasPlayingBeforeInterruption = false
                    self.send(.userPlay)
                }
            }
        }
        
        // Memory pressure: release caches
        memoryObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeOcclusionStateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                // If app is fully occluded and not playing, release item
                if let app = NSApp, !app.occlusionState.contains(.visible), !self.isPlaying {
                    self.driver.replaceItem(with: nil)
                }
            }
        }
    }

    private func setupPiPPossibleObserver() {
        isPiPPossible = AVPictureInPictureController.isPictureInPictureSupported()
    }

    // MARK: - Tracks

    public func getAudioTracks() async -> [AVMediaSelectionOption] {
        guard let url = (driver.player.currentItem?.asset as? AVURLAsset)?.url else { return [] }
        do { return try await core.loadMetadata(at: url).audioOptions } catch { return [] }
    }

    public func selectAudioTrack(_ option: AVMediaSelectionOption) {
        Task {
            guard let item = driver.player.currentItem else { return }
            await core.selectOption(option, in: item, characteristic: .audible)
        }
    }

    public func getSubtitleTracks() async -> [AVMediaSelectionOption] {
        guard let url = (driver.player.currentItem?.asset as? AVURLAsset)?.url else { return [] }
        do { return try await core.loadMetadata(at: url).subtitleOptions } catch { return [] }
    }

    public func selectSubtitleTrack(_ option: AVMediaSelectionOption?) {
        Task {
            guard let item = driver.player.currentItem else { return }
            await core.selectOption(option, in: item, characteristic: .legible)
        }
    }

    // MARK: - A-B Loop
    public func setLoopA() { loopA = currentTime; if let b = loopB, currentTime >= b { loopB = nil } }
    public func setLoopB() { if loopA != nil { loopB = currentTime } }
    public func clearLoop() { loopA = nil; loopB = nil }
    public func toggleLoop() { isLooping ? clearLoop() : (loopA == nil ? setLoopA() : setLoopB()) }

    // MARK: - Volume/Speed
    public func adjustVolume(by d: Float) { volume = max(0, min(1, volume + d)) }
    public func toggleMute() { isMuted.toggle() }
    
    public static let availableSpeeds: [Float] = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0]
    public func setSpeed(_ speed: Float) { playbackSpeed = speed }
    public func cycleSpeedUp() { if let i = Self.availableSpeeds.firstIndex(of: playbackSpeed), i < Self.availableSpeeds.count - 1 { setSpeed(Self.availableSpeeds[i + 1]) } }
    public func cycleSpeedDown() { if let i = Self.availableSpeeds.firstIndex(of: playbackSpeed), i > 0 { setSpeed(Self.availableSpeeds[i - 1]) } }

    public var progressPercent: Double { duration > 0 ? currentTime / duration : 0 }
    public var remainingTime: Double { max(0, duration - currentTime) }

    // MARK: - Telemetry

    public var metrics: PlaybackMetrics {
        guard let log = driver.player.currentItem?.accessLog(),
              let event = log.events.last else { return .zero }
        return PlaybackMetrics(
            startupTime: loadStartTime.map { Date().timeIntervalSince($0) } ?? 0,
            stallCount: stallCounter,
            averageBitrate: event.averageVideoBitrate,
            totalBytesTransferred: event.numberOfBytesTransferred
        )
    }

    // MARK: - Screenshot
    public func captureScreenshot(savePath: String? = nil) {
        guard let asset = driver.player.currentItem?.asset else { return }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: currentTime, preferredTimescale: 600)
        Task {
            do {
                let (image, _) = try await generator.image(at: time)
                let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                let path = savePath ?? NSTemporaryDirectory()
                let fileName = "ProPlayer_\(Int(Date().timeIntervalSince1970)).png"
                let fullPath = (path as NSString).appendingPathComponent(fileName)
                if let tiff = nsImage.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    try png.write(to: URL(fileURLWithPath: fullPath))
                }
            } catch {}
        }
    }

    // MARK: - PiP
    public func setupPiP(with layer: AVPlayerLayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        pipPossibleObserver?.invalidate()
        pipController = AVPictureInPictureController(playerLayer: layer)
        pipController?.delegate = self
        pipPossibleObserver = pipController?.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] c, _ in
            let possible = c.isPictureInPicturePossible
            Task { @MainActor in self?.isPiPPossible = possible }
        }
    }

    public func togglePiP() {
        guard let pip = pipController else { return }
        pip.isPictureInPictureActive ? pip.stopPictureInPicture() : pip.startPictureInPicture()
    }
    
    nonisolated public func pictureInPictureControllerWillStartPictureInPicture(_ pc: AVPictureInPictureController) {
        Task { @MainActor in self.isPiPActive = true }
    }
    nonisolated public func pictureInPictureControllerDidStopPictureInPicture(_ pc: AVPictureInPictureController) {
        Task { @MainActor in self.isPiPActive = false }
    }

    // MARK: - Cleanup

    private func cleanupAllObservers() {
        if let t = timeObserver { driver.removeTimeObserver(t); timeObserver = nil }
        statusObserver?.invalidate()
        timeRangeObserver?.invalidate()
        sizeObserver?.invalidate()
        bufferEmptyObserver?.invalidate()
        bufferFullObserver?.invalidate()
        pipPossibleObserver?.invalidate()
        bufferDebounceTask?.cancel()
        
        [endObserver, sleepObserver, wakeObserver, memoryObserver].compactMap { $0 }.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        endObserver = nil
        sleepObserver = nil
        wakeObserver = nil
        memoryObserver = nil
    }

    // MARK: - Activities
    private func startPlaybackActivity() {
        if playbackActivity == nil {
            playbackActivity = ProcessInfo.processInfo.beginActivity(options: .idleDisplaySleepDisabled, reason: "ProPlayer Playback")
        }
    }
    private func endPlaybackActivity() {
        if let a = playbackActivity { ProcessInfo.processInfo.endActivity(a); playbackActivity = nil }
    }
    
    // MARK: - VideoDisplayLinkDelegate
    
    public func displayLink(didFireWithHostTime hostTime: CFTimeInterval) {
        // Calculate metrics before extraction
        if lastFrameTimestamp > 0 {
            let delta = hostTime - lastFrameTimestamp
            currentFPS = 1.0 / delta
            frameJitter = abs(delta - (1.0 / 60.0)) // Assuming 60Hz baseline (ProMotion handles this naturally)
        }
        lastFrameTimestamp = hostTime
        
        let success = frameExtractor.extractFrame(forHostTime: hostTime)
        if !success {
            frameDropCount += 1
        }
    }
}
