import SwiftUI

public struct MainView: View {
    @StateObject private var playerVM = PlayerViewModel()
    @StateObject private var libraryVM = LibraryViewModel()
    @State private var selectedTab: MediaTab = .video
    
    public enum MediaTab { case video, music }
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Background Base
            ProTheme.Colors.deepBlack.ignoresSafeArea()
            
            // Dynamic Nebula Background (Shifts with Tab)
            ZStack {
                Circle()
                    .fill(selectedTab == .video ? ProTheme.Colors.accentBlue : ProTheme.Colors.accentPurple)
                    .frame(width: 600)
                    .blur(radius: 120)
                    .opacity(0.15)
                    .offset(x: selectedTab == .video ? -200 : 200, y: -100)
                
                Circle()
                    .fill(selectedTab == .video ? ProTheme.Colors.accentPurple : ProTheme.Colors.accentBlue)
                    .frame(width: 400)
                    .blur(radius: 100)
                    .opacity(0.1)
                    .offset(x: selectedTab == .video ? 300 : -300, y: 200)
            }
            .animation(ProTheme.Animations.slow, value: selectedTab)
            
            VStack(spacing: 0) {
                // ELITE TOP BAR (The 1% Selector)
                HStack {
                    Spacer()
                    ProfessionalMediaSelector(selectedTab: $selectedTab)
                    Spacer()
                }
                .padding(.vertical, ProTheme.Spacing.md)
                .background(
                    VisualEffectView(material: .titlebar, blendingMode: .withinWindow)
                        .opacity(0.8)
                        .overlay(
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 0.5),
                            alignment: .bottom
                        )
                )
                
                // MAIN CONTENT AREA
                ZStack {
                    if selectedTab == .video {
                        LibraryView(libraryVM: libraryVM, onPlayVideo: { url in
                            playerVM.openFile(url: url)
                        })
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    } else {
                        MusicLibraryView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .animation(ProTheme.Animations.standard, value: selectedTab)
            }
        }
        .onAppear {
            setupStartupSelection()
        }
    }
    
    private func setupStartupSelection() {
        // Delay slightly to ensure NSWindow is fully initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let url = libraryVM.showOpenFolderDialog() {
                libraryVM.clearAndScanFolder(url)
            }
        }
    }
}

// Helper for native macOS blurring
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
