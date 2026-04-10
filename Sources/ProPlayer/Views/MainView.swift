import SwiftUI
import ProPlayerEngine

struct MainView: View {
    @StateObject private var playerVM = PlayerViewModel()
    @StateObject private var libraryVM = LibraryViewModel()
    @StateObject private var musicVM = MusicLibraryViewModel()
    @State private var currentView: AppView = .library
    @State private var showingSettings = false
    @State private var mediaMode: MediaMode = .video
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    enum AppView {
        case library
        case player
    }

    var body: some View {
        ZStack {
            // Dynamic background - shifts color based on mode
            dynamicBackground
                .ignoresSafeArea()
            
            if !hasCompletedOnboarding {
                OnboardingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .zIndex(1000)
                    .transition(.opacity)
            } else {
            
            switch currentView {
            case .library:
                libraryLayer
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
            
            // MiniPlayer floating panel
            if MusicPlayerEngine.shared.currentTrack != nil && mediaMode != .music && currentView == .library {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MiniPlayerView()
                            .padding(ProTheme.Spacing.xxl)
                    }
                }
                .zIndex(100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .edgesIgnoringSafeArea(.all)
        .frame(minWidth: 900, maxWidth: .infinity, minHeight: 550, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .animation(ProTheme.Animations.standard, value: currentView == .player)
        .toolbar(currentView == .player ? .hidden : .visible, for: .windowToolbar)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url else { return }
                    Task { @MainActor in
                        if VideoItem.isVideoFile(url) {
                            mediaMode = .video
                            playVideo(url: url)
                        } else if MusicTrack.isMusicFile(url) {
                            mediaMode = .music
                        }
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
                    // Media Mode Selector — the centerpiece
                    ProfessionalMediaSelector(selectedMode: $mediaMode)
                    
                    Spacer()
                    
                    Button {
                        switch mediaMode {
                        case .video:
                            if let urls = libraryVM.showOpenFileDialog() {
                                if urls.count == 1 {
                                    playVideo(url: urls[0])
                                } else {
                                    libraryVM.addVideoFiles(urls)
                                }
                            }
                        case .music:
                            if let url = musicVM.showMusicFolderDialog() {
                                musicVM.addFolder(url)
                            }
                        }
                    } label: {
                        Image(systemName: mediaMode == .video ? "folder" : "folder.badge.plus")
                    }
                    .help(mediaMode == .video ? "Open Video File" : "Add Music Folder")
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let url = libraryVM.showOpenFolderDialog() {
                    libraryVM.clearAndScanFolder(url)
                }
            }
        }
    }
    
    // MARK: - Library Layer
    
    @ViewBuilder
    private var libraryLayer: some View {
        Group {
            switch mediaMode {
            case .video:
                LibraryView(libraryVM: libraryVM) { url in
                    playVideo(url: url)
                }
            case .music:
                MusicLibraryView(musicVM: musicVM)
            }
        }
        .animation(ProTheme.Animations.smooth, value: mediaMode)
    }
    
    // MARK: - Dynamic Background
    
    private var dynamicBackground: some View {
        ZStack {
            ProTheme.Colors.deepBlack
            
            // Mode-reactive ambient glow
            RadialGradient(
                colors: [
                    mediaMode.glowColor.opacity(0.06),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 50,
                endRadius: 600
            )
            
            RadialGradient(
                colors: [
                    mediaMode.glowColor.opacity(0.03),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 100,
                endRadius: 500
            )
        }
        .animation(ProTheme.Animations.slow, value: mediaMode)
    }

    // MARK: - Actions

    private func playVideo(url: URL) {
        libraryVM.addVideoFiles([url])
        playerVM.openFile(url: url)
        
        Task { @MainActor in
            WindowController.enterImmersiveFullScreen()
            withAnimation { currentView = .player }
        }
    }
}
