import SwiftUI

struct MusicLibraryView: View {
    @State private var musicItems: [MediaItem] = []
    
    let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 20)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 30) {
                ForEach(musicItems) { item in
                    MusicGridItem(item: item)
                }
            }
            .padding(40)
        }
        .background(
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                // CAPA DE NEBLINA FUTURISTA (Neon Nebulae)
                Circle()
                    .fill(Theme.accentColor.opacity(0.1))
                    .frame(width: 800)
                    .blur(radius: 100)
                    .offset(x: -300, y: -200)
                
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 600)
                    .blur(radius: 80)
                    .offset(x: 400, y: 300)
            }
        )
        .onAppear {
            loadMusic()
        }
    }
    
    func loadMusic() {
        // Simulación: Cargar música desde el Music Manager de Titan
        // En una versión final, esto escanearía la carpeta del Mac.
    }
}
