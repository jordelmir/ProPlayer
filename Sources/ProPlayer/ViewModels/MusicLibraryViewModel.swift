import SwiftUI
import Combine

@MainActor
final class MusicLibraryViewModel: ObservableObject {
    @Published var items: [MusicMetadata] = []
    @Published var isScanning = false
    @Published var selectedItem: MusicMetadata?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {}
    
    func addFiles(_ urls: [URL]) {
        Task {
            isScanning = true
            for url in urls {
                if !items.contains(where: { $0.url == url }) {
                    let metadata = await MusicMetadataService.shared.readMetadata(from: url)
                    items.append(metadata)
                }
            }
            isScanning = false
        }
    }
    
    func scanFolder(_ url: URL) {
        Task {
            isScanning = true
            let urls = await scanDirectory(url)
            for url in urls {
                if !items.contains(where: { $0.url == url }) {
                    let metadata = await MusicMetadataService.shared.readMetadata(from: url)
                    items.append(metadata)
                }
            }
            isScanning = false
        }
    }
    
    func saveMetadata(_ metadata: MusicMetadata) {
        Task {
            do {
                try await MusicMetadataService.shared.writeMetadata(metadata)
                // Update local list
                if let index = items.firstIndex(where: { $0.url == metadata.url }) {
                    items[index] = metadata
                }
            } catch {
                print("Error saving metadata: \(error)")
            }
        }
    }
    
    private func scanDirectory(_ url: URL) async -> [URL] {
        var results: [URL] = []
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            if ["mp3", "m4a", "wav", "flac"].contains(ext) {
                results.append(fileURL)
            }
        }
        
        return results
    }
}
