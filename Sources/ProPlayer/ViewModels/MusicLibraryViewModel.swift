import SwiftUI
import Combine
import AVFoundation

@MainActor
final class MusicLibraryViewModel: ObservableObject {
    @Published var tracks: [MusicTrack] = []
    @Published var filteredTracks: [MusicTrack] = []
    @Published var searchText = ""
    @Published var isScanning = false
    @Published var selectedTrack: MusicTrack?
    @Published var isEditingMetadata = false
    @Published var isSaving = false
    @Published var saveError: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let metadataService = MusicMetadataService.shared
    private let persistenceURL: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("ElysiumVanguardProPlayer8K", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        persistenceURL = appDir.appendingPathComponent("music_library.json")
        
        loadLibrary()
        setupSearch()
    }
    
    private func setupSearch() {
        $searchText
            .combineLatest($tracks)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] searchText, tracks in
                Task { @MainActor in
                    self?.applyFilter(searchText: searchText, source: tracks)
                }
            }
            .store(in: &cancellables)
    }
    
    private func applyFilter(searchText: String, source: [MusicTrack]) {
        if searchText.isEmpty {
            filteredTracks = source
        } else {
            let query = searchText.lowercased()
            filteredTracks = source.filter {
                $0.title.lowercased().contains(query) ||
                $0.artist.lowercased().contains(query) ||
                $0.album.lowercased().contains(query) ||
                $0.genre.lowercased().contains(query)
            }
        }
    }
    
    // MARK: - Folder Scanning
    
    func scanFolder(_ url: URL) {
        Task {
            isScanning = true
            tracks.removeAll()
            
            let musicURLs = await scanDirectory(url)
            if !musicURLs.isEmpty {
                tracks = await metadataService.extractTracks(from: musicURLs)
            }
            
            isScanning = false
            saveLibrary()
        }
    }
    
    func addFolder(_ url: URL) {
        Task {
            isScanning = true
            let musicURLs = await scanDirectory(url)
            let existingURLs = Set(tracks.map { $0.url })
            let newURLs = musicURLs.filter { !existingURLs.contains($0) }
            
            if !newURLs.isEmpty {
                let newTracks = await metadataService.extractTracks(from: newURLs)
                tracks.append(contentsOf: newTracks)
            }
            
            isScanning = false
            saveLibrary()
        }
    }
    
    private func scanDirectory(_ url: URL) async -> [URL] {
        await Task.detached {
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return [] }
            
            var urls: [URL] = []
            while let fileURL = enumerator.nextObject() as? URL {
                if MusicTrack.isMusicFile(fileURL) {
                    urls.append(fileURL)
                }
            }
            return urls
        }.value
    }
    
    // MARK: - Metadata Editing
    
    func saveMetadata(for track: MusicTrack) {
        Task {
            isSaving = true
            saveError = nil
            
            do {
                try await metadataService.writeMetadata(track)
                
                // Update local copy
                if let idx = tracks.firstIndex(where: { $0.id == track.id }) {
                    tracks[idx] = track
                }
                saveLibrary()
            } catch {
                saveError = error.localizedDescription
            }
            
            isSaving = false
        }
    }
    
    func removeTrack(_ track: MusicTrack) {
        tracks.removeAll { $0.id == track.id }
        if selectedTrack?.id == track.id {
            selectedTrack = nil
        }
        saveLibrary()
    }
    
    // MARK: - File Dialog
    
    func showMusicFolderDialog() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.title = "Select Music Folder"
        panel.message = "Choose a folder containing your music files"
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
    
    // MARK: - Persistence
    
    private func saveLibrary() {
        do {
            let data = try JSONEncoder().encode(tracks)
            try data.write(to: persistenceURL)
        } catch {
            // Silent
        }
    }
    
    private func loadLibrary() {
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
        do {
            let data = try Data(contentsOf: persistenceURL)
            tracks = try JSONDecoder().decode([MusicTrack].self, from: data)
        } catch {
            // Silent
        }
    }
}
