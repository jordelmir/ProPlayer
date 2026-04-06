import SwiftUI

struct MusicGridItem: View {
    let item: MediaItem
    @State private var artwork: NSImage? = nil
    @State private var isHovering = False
    
    var body: some View {
        VStack {
            ZStack {
                // REFLEJO INFERIOR (Obsidian Floor)
                if let artwork = artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(y: -1)
                        .offset(y: 160)
                        .opacity(0.2)
                        .blur(radius: 2)
                        .mask(LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .bottom, endPoint: .top))
                }

                // CARÁTULA PRINCIPAL CON BORDE NEÓN
                Group {
                    if let artwork = artwork {
                        Image(nsImage: artwork)
                            .resizable()
                    } else {
                        Color.gray.opacity(0.3)
                            .overlay(Image(systemName: "music.note").font(.largeTitle))
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(width: 180, height: 180)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isHovering ? Theme.accentColor : Color.white.opacity(0.2), lineWidth: 2)
                        .shadow(color: isHovering ? Theme.accentColor : .clear, radius: 10)
                )
                
                // VISUALIZADOR DE ESPECTRO (Animation)
                if isHovering {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.accentColor)
                                .frame(width: 4, height: CGFloat.random(in: 10...40))
                                .animation(Animation.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.1), value: isHovering)
                        }
                    }
                    .padding(.bottom, 10)
                }
            }
            .frame(width: 180, height: 180)
            
            Text(item.title)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.top, 12)
        }
        .padding()
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .onHover { hovering in withAnimation(.spring()) { isHovering = hovering } }
        .task {
            self.artwork = await MediaMetadataExtractor.getArtwork(for: item.url)
        }
    }
}
