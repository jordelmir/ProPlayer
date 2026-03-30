import SwiftUI
import Combine
import ProPlayerEngine

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var videos: [VideoItem] = []
    @Published var filteredVideos: [VideoItem] = []
    @Published var searchText = ""
    @Published var sortOption: LibrarySortOption = .dateAdded
    @Published var viewMode: LibraryViewMode = .grid
    @Published var isScanning = false
    @Published var recentFiles: [VideoItem] = []

    private var cancellables = Set<AnyCancellable>()
    private let libraryURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        libraryURL = appSupport.appendingPathComponent("ElysiumVanguardProPlayer8K", isDirectory: true)
        try? FileManager.default.createDirectory(at: libraryURL, withIntermediateDirectories: true)

        loadLibrary()
        setupSearch()
        scanStandardDirectories()
    }

    private func setupSearch() {
        $searchText
            .combineLatest($sortOption, $videos)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] searchText, sortOption, videos in
                Task { @MainActor in
                    self?.applyFiltersAndSort(searchText: searchText, sort: sortOption, source: videos)
                }
            }
            .store(in: &cancellables)
    }

    private func applyFiltersAndSort(searchText: String, sort: LibrarySortOption, source: [VideoItem]) {
        var result = source

        // Filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.title.lowercased().contains(query) }
        }

        // Sort
        switch sort {
        case .dateAdded:
            result.sort { $0.dateAdded > $1.dateAdded }
        case .dateAddedOldest:
            result.sort { $0.dateAdded < $1.dateAdded }
        case .name:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .duration:
            result.sort { $0.duration > $1.duration }
        case .fileSize:
            result.sort { $0.fileSize > $1.fileSize }
        case .lastPlayed:
            result.sort { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
        }

        filteredVideos = result
    }

    // MARK: - Add Videos

    func addVideoFiles(_ urls: [URL]) {
        Task {
            isScanning = true
            let existingURLs = Set(videos.map { $0.url })
            let filteredURLs = urls.filter { url in 
                VideoItem.isVideoFile(url) && !existingURLs.contains(url) 
            }
            if !filteredURLs.isEmpty {
                let newItems = await VideoMetadataExtractor.extractMetadata(from: filteredURLs)
                videos.append(contentsOf: newItems)
            }
            isScanning = false
            saveLibrary()
        }
    }

    func addFolder(_ url: URL) {
        Task {
            isScanning = true
            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
                isScanning = false
                return
            }

            var videoURLs: [URL] = []
            while let fileURL = enumerator.nextObject() as? URL {
                if VideoItem.isVideoFile(fileURL) {
                    videoURLs.append(fileURL)
                }
            }

            let existingURLs = Set(videos.map { $0.url })
            let filteredURLs = videoURLs.filter { url in !existingURLs.contains(url) }
            
            if !filteredURLs.isEmpty {
                let newItems = await VideoMetadataExtractor.extractMetadata(from: filteredURLs)
                videos.append(contentsOf: newItems)
            }
            
            isScanning = false
            saveLibrary()
        }
    }

    func removeVideo(_ item: VideoItem) {
        videos.removeAll { $0.id == item.id }
        saveLibrary()
    }

    func removeVideos(at offsets: IndexSet) {
        let itemsToRemove = offsets.compactMap { filteredVideos.indices.contains($0) ? filteredVideos[$0] : nil }
        for item in itemsToRemove {
            videos.removeAll { $0.id == item.id }
        }
        saveLibrary()
    }

    func updateLastPlayed(for item: VideoItem, at time: Double) {
        if let idx = videos.firstIndex(where: { $0.id == item.id }) {
            videos[idx].lastPlayed = Date()
            videos[idx].playbackPosition = time
            updateRecentFiles(videos[idx])
            saveLibrary()
        }
    }

    // MARK: - Recent Files

    private func updateRecentFiles(_ item: VideoItem) {
        recentFiles.removeAll { $0.id == item.id }
        recentFiles.insert(item, at: 0)
        if recentFiles.count > 20 {
            recentFiles = Array(recentFiles.prefix(20))
        }
    }

    // MARK: - Open File Dialogs

    func showOpenFileDialog() -> [URL]? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .avi]
        panel.title = "Open Video Files"
        panel.message = "Select video files to add to your library"

        guard panel.runModal() == .OK else { return nil }
        return panel.urls
    }

    func showOpenFolderDialog() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.title = "Add Folder"
        panel.message = "Select a folder to scan for videos"

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    // MARK: - Persistence

    private var libraryFile: URL {
        libraryURL.appendingPathComponent("library.json")
    }

    private func saveLibrary() {
        do {
            let data = try JSONEncoder().encode(videos)
            try data.write(to: libraryFile)
        } catch {
            // Handle save error silently
        }
    }

    private func loadLibrary() {
        guard FileManager.default.fileExists(atPath: libraryFile.path) else { return }
        do {
            let data = try Data(contentsOf: libraryFile)
            videos = try JSONDecoder().decode([VideoItem].self, from: data)
        } catch {
            // Handle load error silently
        }
    }

    // MARK: - Auto-Scan

    private func scanStandardDirectories() {
        Task {
            isScanning = true
            
            // Pass the URLs as strings or URLs (Sendable) to the detached task
            let fileManager = FileManager.default
            let homeURL = fileManager.homeDirectoryForCurrentUser
            let dirsToScan = [
                homeURL.appendingPathComponent("Movies"),
                homeURL.appendingPathComponent("Downloads"),
                homeURL.appendingPathComponent("Desktop")
            ]
            
            let discoveredURLs: [URL] = await Task.detached {
                let fm = FileManager.default
                var localURLs: [URL] = []
                
                for dir in dirsToScan {
                    guard let enumerator = fm.enumerator(
                        at: dir,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) else { continue }
                    
                    while let fileURL = enumerator.nextObject() as? URL {
                        if VideoItem.isVideoFile(fileURL) {
                            localURLs.append(fileURL)
                        }
                    }
                }
                return localURLs
            }.value
            
            // Filter out already known videos
            let existingURLs = Set(videos.map { $0.url })
            let newURLs = discoveredURLs.filter { !existingURLs.contains($0) }
            
            if !newURLs.isEmpty {
                let newItems = await VideoMetadataExtractor.extractMetadata(from: newURLs)
                videos.append(contentsOf: newItems)
                saveLibrary()
                applyFiltersAndSort(searchText: searchText, sort: sortOption, source: videos)
            }
            isScanning = false
        }
    }
}
