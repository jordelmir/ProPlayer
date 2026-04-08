import Foundation
import AVFoundation
import AppKit

/// Professional-grade music metadata engine.
/// Reads and writes ID3/iTunes tags + album artwork using AVFoundation.
@MainActor
final class MusicMetadataService {
    static let shared = MusicMetadataService()
    private init() {}
    
    // MARK: - Read Metadata
    
    /// Reads all available metadata from an audio file.
    func readMetadata(from url: URL) async -> MusicTrack {
        var track = MusicTrack(url: url)
        let asset = AVAsset(url: url)
        
        // File attributes
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
            track.fileSize = attrs[.size] as? Int64 ?? 0
            track.dateAdded = attrs[.creationDate] as? Date ?? Date()
        }
        
        do {
            // Duration
            let duration = try await asset.load(.duration)
            track.duration = duration.seconds.isNaN ? 0 : duration.seconds
            
            // Common metadata (cross-format)
            let commonMetadata = try await asset.load(.commonMetadata)
            for item in commonMetadata {
                guard let key = item.commonKey?.rawValue else { continue }
                let value = try? await item.load(.value)
                
                switch key {
                case AVMetadataKey.commonKeyTitle.rawValue:
                    if let v = value as? String, !v.isEmpty { track.title = v }
                case AVMetadataKey.commonKeyArtist.rawValue:
                    if let v = value as? String, !v.isEmpty { track.artist = v }
                case AVMetadataKey.commonKeyAlbumName.rawValue:
                    if let v = value as? String, !v.isEmpty { track.album = v }
                case AVMetadataKey.commonKeyType.rawValue:
                    if let v = value as? String, !v.isEmpty { track.genre = v }
                case AVMetadataKey.commonKeyArtwork.rawValue:
                    if let data = value as? Data {
                        track.artworkData = data
                    }
                default:
                    break
                }
            }
            
            // Format-specific metadata (ID3 / iTunes atoms) for year & track
            let formatMetadata = try await asset.load(.metadata)
            for item in formatMetadata {
                let value = try? await item.load(.value)
                
                // Check by identifier
                if let identifier = item.identifier {
                    switch identifier {
                    case .id3MetadataYear, .iTunesMetadataReleaseDate:
                        if let v = value as? String, !v.isEmpty { track.year = v }
                    case .id3MetadataTrackNumber:
                        if let v = value as? String, !v.isEmpty { track.trackNumber = v }
                    case .id3MetadataContentType:
                        if let v = value as? String, !v.isEmpty, track.genre.isEmpty { track.genre = v }
                    default:
                        // Fallback: check raw key strings
                        if let key = item.key as? String {
                            if key.contains("TYER") || key.contains("TDRC") || key.contains("©day") {
                                if let v = value as? String, !v.isEmpty { track.year = v }
                            } else if key.contains("TRCK") {
                                if let v = value as? String, !v.isEmpty { track.trackNumber = v }
                            } else if key.contains("TCON") {
                                if let v = value as? String, !v.isEmpty, track.genre.isEmpty { track.genre = v }
                            }
                        }
                    }
                }
            }
            
        } catch {
            print("[MusicMetadataService] Error reading metadata for \(url.lastPathComponent): \(error)")
        }
        
        return track
    }
    
    // MARK: - Write Metadata
    
    /// Writes metadata back to the file by exporting with AVAssetExportSession.
    func writeMetadata(_ track: MusicTrack) async throws {
        let asset = AVAsset(url: track.url)
        
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw MetadataError.exportSessionFailed
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(track.url.pathExtension)
        
        session.outputURL = tempURL
        session.outputFileType = outputFileType(for: track.url)
        session.shouldOptimizeForNetworkUse = true
        
        // Build metadata items
        var items: [AVMutableMetadataItem] = []
        items.append(makeItem(key: .commonKeyTitle, value: track.title))
        items.append(makeItem(key: .commonKeyArtist, value: track.artist))
        items.append(makeItem(key: .commonKeyAlbumName, value: track.album))
        
        if !track.genre.isEmpty {
            items.append(makeItem(key: .commonKeyType, value: track.genre))
        }
        
        // Artwork
        if let artworkData = track.artworkData {
            let artItem = AVMutableMetadataItem()
            artItem.key = AVMetadataKey.commonKeyArtwork.rawValue as (NSCopying & NSObjectProtocol)?
            artItem.keySpace = .common
            artItem.value = artworkData as (NSCopying & NSObjectProtocol)?
            items.append(artItem)
        }
        
        session.metadata = items
        
        await session.export()
        
        guard session.status == .completed else {
            throw session.error ?? MetadataError.exportFailed
        }
        
        // Atomic replace: remove original, move temp to original
        let fm = FileManager.default
        try fm.removeItem(at: track.url)
        try fm.moveItem(at: tempURL, to: track.url)
    }
    
    // MARK: - Batch Read
    
    /// Extracts metadata from multiple URLs in parallel.
    func extractTracks(from urls: [URL]) async -> [MusicTrack] {
        await withTaskGroup(of: MusicTrack.self) { group in
            for url in urls {
                group.addTask {
                    await self.readMetadata(from: url)
                }
            }
            var tracks: [MusicTrack] = []
            for await track in group {
                tracks.append(track)
            }
            return tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }
    
    // MARK: - Helpers
    
    private func makeItem(key: AVMetadataKey, value: String) -> AVMutableMetadataItem {
        let item = AVMutableMetadataItem()
        item.key = key.rawValue as (NSCopying & NSObjectProtocol)?
        item.keySpace = .common
        item.value = value as (NSCopying & NSObjectProtocol)?
        return item
    }
    
    private func outputFileType(for url: URL) -> AVFileType {
        switch url.pathExtension.lowercased() {
        case "m4a": return .m4a
        case "wav": return .wav
        case "aiff": return .aiff
        default: return .mp4  // Passthrough for mp3 and others
        }
    }
    
    enum MetadataError: LocalizedError {
        case exportSessionFailed
        case exportFailed
        
        var errorDescription: String? {
            switch self {
            case .exportSessionFailed: return "Could not create export session for this file format."
            case .exportFailed: return "Metadata export failed."
            }
        }
    }
}
