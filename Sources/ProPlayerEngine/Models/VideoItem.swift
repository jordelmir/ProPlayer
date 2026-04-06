import Foundation
import SwiftUI
import AVFoundation

public struct MediaItem: Identifiable, Codable {
    public let id: UUID
    public let url: URL
    public let title: String
    public let type: MediaType
    
    public enum MediaType: String, Codable {
        case video
        case music
    }
    
    public init(id: UUID = UUID(), url: URL, title: String, type: MediaType) {
        self.id = id
        self.url = url
        self.title = title
        self.type = type
    }
}

public typealias VideoItem = MediaItem

public class MediaMetadataExtractor {
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
