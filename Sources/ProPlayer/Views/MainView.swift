import SwiftUI
import ProPlayerEngine

struct MainView: View {
    @StateObject private var playerVM = PlayerViewModel()
    @StateObject private var libraryVM = LibraryViewModel()
    @State private var currentView: AppView = .library
    @State private var showingSettings = false

    enum AppView {
        case library
        case player
    }

    var body: some View {
        ZStack {
            switch currentView {
            case .library:
                LibraryView(libraryVM: libraryVM) { url in
                    playVideo(url: url)
                }
                .transition(.opacity)

            case .player:
                PlayerView(viewModel: playerVM) {
                    playerVM.stop()
                    Task { @MainActor in
                        WindowController.exitImmersiveFullScreen()
                        withAnimation { currentView = .library }
                    }
                }
                .transition(.opacity)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .frame(minWidth: 800, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .animation(ProTheme.Animations.standard, value: currentView == .player)
        .toolbar(currentView == .player ? .hidden : .visible, for: .windowToolbar)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url, VideoItem.isVideoFile(url) else { return }
                    Task { @MainActor in
                        playVideo(url: url)
                    }
                }
            }
            return true
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: $playerVM.settings)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if currentView == .library {
                    Button {
                        if let urls = libraryVM.showOpenFileDialog() {
                            if urls.count == 1 {
                                playVideo(url: urls[0])
                            } else {
                                libraryVM.addVideoFiles(urls)
                            }
                        }
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Open File")
                }

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .proPlayerOpenFiles)) { notification in
            guard let urls = notification.object as? [URL] else { return }
            if urls.count == 1 {
                playVideo(url: urls[0])
            } else {
                libraryVM.addVideoFiles(urls)
                playerVM.openFiles(urls: urls)
                Task { @MainActor in
                    WindowController.enterImmersiveFullScreen()
                    withAnimation { currentView = .player }
                }
            }
        }
    }

    private func playVideo(url: URL) {
        // Add to library if not already there
        libraryVM.addVideoFiles([url])

        // Play
        playerVM.openFile(url: url)
        
        Task { @MainActor in
            WindowController.enterImmersiveFullScreen()
            withAnimation { currentView = .player }
        }
    }
}
