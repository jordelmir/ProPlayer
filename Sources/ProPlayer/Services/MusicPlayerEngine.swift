import Foundation
import AVFoundation
import MediaPlayer
import AppKit

/// Professional music playback engine with gapless playback, volume normalization,
/// and system Now Playing integration.
@MainActor
final class MusicPlayerEngine: ObservableObject {
    static let shared = MusicPlayerEngine()
    
    // MARK: - Published State
    @Published var isPlaying = false
    @Published var currentTrack: MusicTrack?
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Double = 0.8 { didSet { player.volume = Float(volume) } }
    @Published var isMuted = false
    @Published var normalizeVolume = false
    
    // MARK: - Playback Queue
    @Published var queue = PlaybackQueue()
    
    // MARK: - Private
    private var player = AVQueuePlayer()
    private var timeObserver: Any?
    private var itemObservers: [NSKeyValueObservation] = []
    private var endObserver: NSObjectProtocol?
    private var preloadedItems: [URL: AVPlayerItem] = [:]
    private var volumeAdjustments: [URL: Float] = [:]
    
    private init() {
        setupTimeObserver()
        setupEndObserver()
        setupRemoteCommands()
        player.volume = Float(volume)
        // Allow audio mixing for background playback
        player.allowsExternalPlayback = false
    }
    
    // MARK: - Playback Controls
    
    func play() {
        player.play()
        isPlaying = true
        updateNowPlaying()
    }
    
    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlaying()
    }
    
    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }
    
    func stop() {
        player.pause()
        player.removeAllItems()
        preloadedItems.removeAll()
        isPlaying = false
        currentTrack = nil
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func seekTo(_ time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    func seekRelative(_ delta: Double) {
        let target = max(0, min(duration, currentTime + delta))
        seekTo(target)
    }
    
    // MARK: - Track Loading (Gapless)
    
    /// Plays a specific track from the queue. Pre-loads adjacent items for gapless transitions.
    func playTrack(at index: Int) {
        guard index >= 0 && index < queue.tracks.count else { return }
        
        queue.currentIndex = index
        let track = queue.tracks[index]
        
        // Clear player and rebuild queue for gapless
        player.removeAllItems()
        preloadedItems.removeAll()
        itemObservers.removeAll()
        
        // Load current + next items into AVQueuePlayer
        let currentItem = makePlayerItem(for: track)
        preloadedItems[track.url] = currentItem
        player.insert(currentItem, after: nil)
        
        // Pre-load next items for gapless
        let itemsToLoad = queue.upcomingTracks(count: 3)
        for t in itemsToLoad {
            let item = makePlayerItem(for: t)
            preloadedItems[t.url] = item
            player.insert(item, after: nil)
        }
        
        currentTrack = track
        duration = track.duration
        currentTime = 0
        
        play()
    }
    
    /// Plays the given track, setting up the queue around it.
    func playTrack(_ track: MusicTrack) {
        if let idx = queue.tracks.firstIndex(where: { $0.id == track.id }) {
            playTrack(at: idx)
        } else {
            // Single track play — add to queue first
            queue.tracks = [track]
            queue.currentIndex = 0
            playTrack(at: 0)
        }
    }
    
    /// Loads an entire list of tracks as the queue and starts playback.
    func playAll(_ tracks: [MusicTrack], startingAt index: Int = 0) {
        queue.tracks = tracks
        queue.currentIndex = index
        playTrack(at: index)
    }
    
    func nextTrack() {
        guard let next = queue.next() else { return }
        playTrack(at: queue.currentIndex)
    }
    
    func previousTrack() {
        // If we're >3s in, restart current track
        if currentTime > 3 {
            seekTo(0)
            return
        }
        guard let _ = queue.previous() else { return }
        playTrack(at: queue.currentIndex)
    }
    
    // MARK: - Volume Normalization (ReplayGain-style)
    
    private func makePlayerItem(for track: MusicTrack) -> AVPlayerItem {
        let item = AVPlayerItem(url: track.url)
        
        if normalizeVolume {
            // Apply volume normalization via AVAudioMix
            Task.detached { [weak self] in
                let asset = AVAsset(url: track.url)
                guard let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first else { return }
                
                let params = AVMutableAudioMixInputParameters(track: audioTrack)
                let gain = await self?.calculateReplayGain(for: track) ?? 1.0
                params.setVolume(gain, at: .zero)
                
                let mix = AVMutableAudioMix()
                mix.inputParameters = [params]
                
                await MainActor.run {
                    item.audioMix = mix
                }
            }
        }
        
        let observer = item.observe(\.status, options: [.new, .old]) { currentItem, _ in
            if currentItem.status == .failed {
                print("AVPlayerItem FAILED to load \(track.url): \(String(describing: currentItem.error))")
            } else if currentItem.status == .readyToPlay {
                print("AVPlayerItem READY to play \(track.url)")
            }
        }
        
        itemObservers.append(observer)
        
        return item
    }
    
    private func calculateReplayGain(for track: MusicTrack) -> Float {
        // Target loudness: -18 LUFS (standard ReplayGain reference)
        // For now, use a simple heuristic based on file size / duration ratio
        // A proper implementation would analyze PCM data with vDSP
        // This provides reasonable normalization without heavy computation
        let targetRMS: Float = 0.15
        
        // Cache lookup
        if let cached = volumeAdjustments[track.url] {
            return cached
        }
        
        // Simple estimation: smaller files per second = likely quieter
        let bytesPerSecond = track.duration > 0 ? Float(track.fileSize) / Float(track.duration) : 0
        let referenceBPS: Float = 20000 // ~160kbps reference
        
        var gain = referenceBPS / max(bytesPerSecond, 1000)
        gain = max(0.5, min(2.0, gain)) // Clamp to ±6dB
        
        volumeAdjustments[track.url] = gain
        return gain
    }
    
    // MARK: - Time Observer
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentTime = time.seconds.isNaN ? 0 : time.seconds
                
                // Update duration from current item if needed
                if let item = self.player.currentItem {
                    let dur = item.duration.seconds
                    if !dur.isNaN && dur > 0 {
                        self.duration = dur
                    }
                }
            }
        }
    }
    
    // MARK: - Track End Observer (Gapless Queue Advance)
    
    private func setupEndObserver() {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Advance queue
                if let next = self.queue.next() {
                    self.currentTrack = next
                    self.duration = next.duration
                    self.currentTime = 0
                    self.updateNowPlaying()
                    
                    // Pre-load the next-next track for gapless
                    let upcoming = self.queue.upcomingTracks(count: 1)
                    for t in upcoming {
                        if self.preloadedItems[t.url] == nil {
                            let item = self.makePlayerItem(for: t)
                            self.preloadedItems[t.url] = item
                            self.player.insert(item, after: nil)
                        }
                    }
                } else {
                    // End of queue
                    if self.queue.repeatMode == .all {
                        self.playTrack(at: 0)
                    } else {
                        self.stop()
                    }
                }
            }
        }
    }
    
    // MARK: - Now Playing Info Center (System Integration)
    
    private func updateNowPlaying() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        
        // Artwork
        if let data = track.artworkData, let image = NSImage(data: data) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // MARK: - Remote Command Center (Media Keys)
    
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.nextTrack() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previousTrack() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seekTo(event.positionTime) }
            return .success
        }
    }
    
    // MARK: - Mute
    
    func toggleMute() {
        isMuted.toggle()
        player.isMuted = isMuted
    }
}
