import Foundation

/// Represents an audio track with full metadata for the music library.
public struct MusicTrack: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public var title: String
    public var artist: String
    public var album: String
    public var year: String
    public var trackNumber: String
    public var genre: String
    public var duration: Double
    public var fileSize: Int64
    public var dateAdded: Date
    public var artworkData: Data?
    
    public init(
        id: UUID = UUID(),
        url: URL,
        title: String? = nil,
        artist: String = "Unknown Artist",
        album: String = "Unknown Album",
        year: String = "",
        trackNumber: String = "",
        genre: String = "",
        duration: Double = 0,
        fileSize: Int64 = 0,
        dateAdded: Date = Date(),
        artworkData: Data? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title ?? url.deletingPathExtension().lastPathComponent
        self.artist = artist
        self.album = album
        self.year = year
        self.trackNumber = trackNumber
        self.genre = genre
        self.duration = duration
        self.fileSize = fileSize
        self.dateAdded = dateAdded
        self.artworkData = artworkData
    }
    
    public var durationLabel: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    public var fileSizeLabel: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    public static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "flac", "wav", "aac", "ogg", "wma", "aiff", "alac"
    ]
    
    public static func isMusicFile(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }
}
