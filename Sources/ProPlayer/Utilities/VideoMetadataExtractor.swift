import Foundation
import AVFoundation
import AppKit
import ProPlayerEngine

@MainActor
enum VideoMetadataExtractor {

    static func extractMetadata(from url: URL) async -> VideoItem {
        let asset = AVURLAsset(url: url)
        let creationDate = fileCreationDate(url) ?? Date()
        let size = fileSize(url)
        
        var item = VideoItem(
            url: url,
            title: url.deletingPathExtension().lastPathComponent,
            type: .video,
            duration: 0,
            dateAdded: creationDate,
            fileSize: size,
            width: 0,
            height: 0
        )

        do {
            // Load and analyze properties in parallel
            let duration = try await asset.load(.duration)
            item.duration = duration.seconds

            let tracks = try await asset.load(.tracks)
            let videoTracks = tracks.filter { $0.mediaType == .video }
            if let videoTrack = videoTracks.first {
                let size = try await videoTrack.load(.naturalSize)
                item.width = Double(size.width)
                item.height = Double(size.height)
            }
        } catch {
            print("Error loading metadata for \(url): \(error)")
        }

        return item
    }

    /// Generates a thumbnail for a video.
    static func generateThumbnail(for url: URL) async -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)

        do {
            let (image, _) = try await generator.image(at: .zero)
            return NSImage(cgImage: image, size: .zero)
        } catch {
            print("Thumbnail generation failed: \(error)")
        }
        
        return nil
    }

    // Parallel extraction helper
    static func extractMetadata(from urls: [URL]) async -> [VideoItem] {
        await withTaskGroup(of: VideoItem?.self) { group in
            for url in urls {
                group.addTask {
                    await extractMetadata(from: url)
                }
            }
            
            var results: [VideoItem] = []
            for await item in group {
                if let item = item { results.append(item) }
            }
            return results
        }
    }

    private static func fileCreationDate(_ url: URL) -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attrs?[.creationDate] as? Date
    }
    
    private static func fileSize(_ url: URL) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attrs?[.size] as? Int64 ?? 0
    }
}
