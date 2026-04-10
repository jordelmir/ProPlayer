import Foundation

/// Defines the playback repeat mode.
public enum RepeatMode: String, Codable {
    case off = "Off"
    case all = "Repeat All"
    case one = "Repeat One"
    
    var icon: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

/// Manages the queue of tracks for gapless playback.
public struct PlaybackQueue: Codable {
    public var tracks: [MusicTrack] = []
    public var currentIndex: Int = -1
    public var repeatMode: RepeatMode = .off
    public var shuffleMode: Bool = false {
        didSet {
            if shuffleMode != oldValue {
                applyShuffle()
            }
        }
    }
    
    /// The original un-shuffled array of tracks to restore when shuffle is turned off.
    private var originalTracks: [MusicTrack] = []
    
    public init() {}
    
    // MARK: - Navigation
    
    public var currentTrack: MusicTrack? {
        guard currentIndex >= 0 && currentIndex < tracks.count else { return nil }
        return tracks[currentIndex]
    }
    
    public mutating func next() -> MusicTrack? {
        guard !tracks.isEmpty else { return nil }
        
        switch repeatMode {
        case .one:
            // Just return the same track
            return currentTrack
        case .all:
            // Loop back to 0 if at the end
            currentIndex = (currentIndex + 1) % tracks.count
            return tracks[currentIndex]
        case .off:
            // Advance or return nil if at the end
            if currentIndex + 1 < tracks.count {
                currentIndex += 1
                return tracks[currentIndex]
            } else {
                return nil
            }
        }
    }
    
    public mutating func previous() -> MusicTrack? {
        guard !tracks.isEmpty else { return nil }
        
        switch repeatMode {
        case .one:
            return currentTrack
        case .all:
            currentIndex = (currentIndex - 1 + tracks.count) % tracks.count
            return tracks[currentIndex]
        case .off:
            if currentIndex - 1 >= 0 {
                currentIndex -= 1
                return tracks[currentIndex]
            } else {
                return nil
            }
        }
    }
    
    /// Returns the next `count` upcoming tracks, used for gapless preloading.
    public func upcomingTracks(count: Int) -> [MusicTrack] {
        guard !tracks.isEmpty, currentIndex >= 0 else { return [] }
        
        var result: [MusicTrack] = []
        var tempIndex = currentIndex
        
        for _ in 0..<count {
            if tempIndex + 1 < tracks.count {
                tempIndex += 1
                result.append(tracks[tempIndex])
            } else if repeatMode == .all {
                tempIndex = 0
                result.append(tracks[tempIndex])
            } else {
                break
            }
        }
        return result
    }
    
    // MARK: - Queue Management
    
    public mutating func enqueue(_ track: MusicTrack) {
        if originalTracks.isEmpty && !tracks.isEmpty {
            originalTracks = tracks
        }
        tracks.append(track)
        originalTracks.append(track)
        
        if currentIndex == -1 {
            currentIndex = 0
        }
    }
    
    public mutating func enqueue(contentsOf newTracks: [MusicTrack]) {
        if originalTracks.isEmpty && !tracks.isEmpty {
            originalTracks = tracks
        }
        tracks.append(contentsOf: newTracks)
        originalTracks.append(contentsOf: newTracks)
        
        if currentIndex == -1 && !tracks.isEmpty {
            currentIndex = 0
        }
    }
    
    public mutating func remove(at offsets: IndexSet) {
        tracks.remove(atOffsets: offsets)
        // Note: keeping originalTracks synced is complex if we allow removing while shuffled.
        // For simplicity, if we modify the queue directly, we update originalTracks too.
        originalTracks = tracks
        
        // Adjust currentIndex
        if offsets.contains(currentIndex) {
            currentIndex = min(currentIndex, tracks.count - 1)
        } else {
            let removedBeforeCurrent = offsets.filter { $0 < currentIndex }.count
            currentIndex -= removedBeforeCurrent
        }
    }
    
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let itemsToMove = source.map { tracks[$0] }
        
        // Find current track before move
        let currentItem = currentTrack
        
        tracks.move(fromOffsets: source, toOffset: destination)
        originalTracks = tracks // Reset original ordering to match manual user ordering
        
        // Restore currentIndex
        if let currentItem = currentItem, let newIdx = tracks.firstIndex(where: { $0.id == currentItem.id }) {
            currentIndex = newIdx
        }
    }
    
    public mutating func clear() {
        tracks.removeAll()
        originalTracks.removeAll()
        currentIndex = -1
    }
    
    // MARK: - Shuffle
    
    private mutating func applyShuffle() {
        guard !tracks.isEmpty else { return }
        
        if shuffleMode {
            // Turning shuffle ON
            originalTracks = tracks
            let current = currentTrack
            
            // Shuffle everything except the currently playing track
            var remainingTracks = tracks
            if let current = current {
                remainingTracks.removeAll { $0.id == current.id }
            }
            
            remainingTracks.shuffle()
            
            if let current = current {
                tracks = [current] + remainingTracks
                currentIndex = 0
            } else {
                tracks = remainingTracks
                currentIndex = -1
            }
        } else {
            // Turning shuffle OFF - restore original order
            let current = currentTrack
            tracks = originalTracks
            
            if let current = current, let newIdx = tracks.firstIndex(where: { $0.id == current.id }) {
                currentIndex = newIdx
            }
        }
    }
}
