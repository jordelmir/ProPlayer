import Foundation
import AVFoundation
import AppKit

public struct MusicMetadata: Codable, Identifiable {
    public var id: UUID = UUID()
    public var url: URL
    public var title: String
    public var artist: String
    public var album: String
    public var year: String
    public var trackNumber: String
    public var genre: String
    public var artworkData: Data?
    
    public init(url: URL) {
        self.url = url
        self.title = url.deletingPathExtension().lastPathComponent
        self.artist = "Unknown Artist"
        self.album = "Unknown Album"
        self.year = ""
        self.trackNumber = ""
        self.genre = ""
    }
}

public class MusicMetadataService {
    public static let shared = MusicMetadataService()
    
    private init() {}
    
    /// Reads metadata from an audio file
    public func readMetadata(from url: URL) async -> MusicMetadata {
        var metadata = MusicMetadata(url: url)
        let asset = AVAsset(url: url)
        
        do {
            let commonMetadata = try await asset.load(.commonMetadata)
            
            for item in commonMetadata {
                guard let key = item.commonKey?.rawValue else { continue }
                let value = try? await item.load(.value)
                
                switch key {
                case AVMetadataKey.commonKeyTitle.rawValue:
                    metadata.title = value as? String ?? metadata.title
                case AVMetadataKey.commonKeyArtist.rawValue:
                    metadata.artist = value as? String ?? "Unknown Artist"
                case AVMetadataKey.commonKeyAlbumName.rawValue:
                    metadata.album = value as? String ?? "Unknown Album"
                case AVMetadataKey.commonKeyType.rawValue:
                    metadata.genre = value as? String ?? ""
                case AVMetadataKey.commonKeyArtwork.rawValue:
                    metadata.artworkData = value as? Data
                default:
                    break
                }
            }
            
            // Try to get year and track number from format-specific metadata
            let formatMetadata = try await asset.load(.metadata)
            for item in formatMetadata {
                // Format-specific keys (ID3/iTunes)
                if let key = item.key as? String {
                    let value = try? await item.load(.value)
                    if key.contains("YEAR") || key.contains("TYER") || key.contains("TDRC") {
                        metadata.year = value as? String ?? ""
                    } else if key.contains("TRCK") {
                        metadata.trackNumber = value as? String ?? ""
                    }
                }
            }
            
        } catch {
            print("Error loading metadata: \(error)")
        }
        
        return metadata
    }
    
    /// Writes metadata back to the file
    /// Note: Writing metadata in AVFoundation typically requires exporting to a new file.
    public func writeMetadata(_ metadata: MusicMetadata) async throws {
        let asset = AVAsset(url: metadata.url)
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)
        
        guard let session = exportSession else {
            throw NSError(domain: "MusicMetadataService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(metadata.url.pathExtension)
        session.outputURL = tempURL
        session.outputFileType = self.outputFileType(for: metadata.url)
        session.shouldOptimizeForNetworkUse = true
        
        // Prepare metadata items
        var metadataItems: [AVMutableMetadataItem] = []
        
        metadataItems.append(createItem(.commonKeyTitle, value: metadata.title))
        metadataItems.append(createItem(.commonKeyArtist, value: metadata.artist))
        metadataItems.append(createItem(.commonKeyAlbumName, value: metadata.album))
        metadataItems.append(createItem(.commonKeyType, value: metadata.genre))
        
        if let artwork = metadata.artworkData {
            let item = AVMutableMetadataItem()
            item.key = AVMetadataKey.commonKeyArtwork.rawValue as (NSCopying & NSObjectProtocol)?
            item.keySpace = .common
            item.value = artwork as (NSCopying & NSObjectProtocol)?
            item.dataType = kCMMetadataBaseDataType_JPEG as String
            metadataItems.append(item)
        }
        
        session.metadata = metadataItems
        
        await session.export()
        
        if session.status == .completed {
            // Replace original file with the new one
            try FileManager.default.removeItem(at: metadata.url)
            try FileManager.default.moveItem(at: tempURL, to: metadata.url)
        } else {
            throw session.error ?? NSError(domain: "MusicMetadataService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
        }
    }
    
    private func createItem(_ key: AVMetadataKey, value: String) -> AVMutableMetadataItem {
        let item = AVMutableMetadataItem()
        item.key = key.rawValue as (NSCopying & NSObjectProtocol)?
        item.keySpace = .common
        item.value = value as (NSCopying & NSObjectProtocol)?
        return item
    }
    
    private func outputFileType(for url: URL) -> AVFileType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "m4a": return .m4a
        case "mp3": return .mp3
        case "wav": return .wav
        default: return .mp4
        }
    }
}
