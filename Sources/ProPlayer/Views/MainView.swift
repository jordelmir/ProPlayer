import SwiftUI

public struct MainView: View {
    @State private var selectedTab: MediaTab = .video
    
    enum MediaTab { case video, music }
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // EL SELECTOR CENTRAL SUPERIOR (Pedido por el Arquitecto)
                HStack {
                    Spacer()
                    Picker("", selection: $selectedTab) {
                        Text("VÍDEO").tag(MediaTab.video)
                        Text("MÚSICA").tag(MediaTab.music)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 250)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color.black.opacity(0.4))
                
                if selectedTab == .video {
                    LibraryView() // Galería de Video actual
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    // Placeholder para la Galería de Música
                    VStack {
                        Spacer()
                        Image(systemName: "music.note.list")
                            .font(.system(size: 80))
                            .foregroundColor(Theme.accentColor)
                        Text("ELYSYUM MUSIC CLAW")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Inyectando metadatos y carátulas...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(), value: selectedTab)
    }
}
