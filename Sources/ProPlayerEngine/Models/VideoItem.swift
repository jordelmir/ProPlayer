import Foundation
import SwiftUI
import AVFoundation

public struct MediaItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let url: URL
    public let title: String
    public let type: MediaType
    public var duration: Double
    public var dateAdded: Date
    public var fileSize: Int64
    public var lastPlayed: Date?
    public var playbackPosition: Double
    public var thumbnailUrl: URL?
    public var width: Double
    public var height: Double
    
    public enum MediaType: String, Codable, Sendable {
        case video
        case music
    }
    
    public init(id: UUID = UUID(), url: URL, title: String, type: MediaType, duration: Double = 0, dateAdded: Date = Date(), fileSize: Int64 = 0, width: Double = 0, height: Double = 0) {
        self.id = id
        self.url = url
        self.title = title
        self.type = type
        self.duration = duration
        self.dateAdded = dateAdded
        self.fileSize = fileSize
        self.width = width
        self.height = height
        self.playbackPosition = 0
    }

    public var durationLabel: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }

    public var hasResumePosition: Bool {
        playbackPosition > 5 && playbackPosition < duration - 5
    }

    public var resolutionLabel: String {
        // Return dummy or extracted resolution
        "1080p"
    }

    public var codecLabel: String {
        // Return dummy or extracted codec
        "H.264"
    }

    public var fileSizeLabel: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    public static func isVideoFile(_ url: URL) -> Bool {
        let extensions = ["mp4", "mkv", "mov", "avi", "m4v"]
        return extensions.contains(url.pathExtension.lowercased())
    }

    public static func isMusicFile(_ url: URL) -> Bool {
        let extensions = ["mp3", "m4a", "wav", "flac"]
        return extensions.contains(url.pathExtension.lowercased())
    }
}

public typealias VideoItem = MediaItem

public class VideoMetadataExtractor {
    public static func extractMetadata(from urls: [URL]) async -> [VideoItem] {
        var items: [VideoItem] = []
        for url in urls {
            let asset = AVAsset(url: url)
            let duration = (try? await asset.load(.duration))?.seconds ?? 0
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = attributes?[.size] as? Int64 ?? 0
            let date = attributes?[.creationDate] as? Date ?? Date()
            
            let item = VideoItem(
                url: url,
                title: url.deletingPathExtension().lastPathComponent,
                type: .video,
                duration: duration,
                dateAdded: date,
                fileSize: size
            )
            items.append(item)
        }
        return items
    }

    public static func getArtwork(for url: URL) async -> NSImage? {
        let asset = AVAsset(url: url)
        do {
            let metadata = try await asset.load(.commonMetadata)
            let artworkItems = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierArtwork)
            if let artworkItem = artworkItems.first {
                let data = try await artworkItem.load(.dataValue)
                if let data = data as? Data {
                    return NSImage(data: data)
                }
            }
        } catch {
            print("Error extrayendo carátula: \(error)")
        }
        return nil
    }
    
    public static func getDetails(for url: URL) async -> (artist: String, album: String, year: String)? {
        let asset = AVAsset(url: url)
        do {
            let metadata = try await asset.load(.commonMetadata)
            let artist = try await AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierArtist).first?.load(.stringValue) ?? "Unknown Artist"
            let album = try await AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierAlbumName).first?.load(.stringValue) ?? "Unknown Album"
            let year = try await AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierCreationDate).first?.load(.stringValue) ?? ""
            return (artist, album, year)
        } catch {
            return nil
        }
    }
}
