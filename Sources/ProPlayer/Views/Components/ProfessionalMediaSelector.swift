import SwiftUI

/// The active media mode for the application.
enum MediaMode: String, CaseIterable {
    case video = "Video"
    case music = "Music"
    
    var icon: String {
        switch self {
        case .video: return "film.stack.fill"
        case .music: return "music.note.list"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .video: return ProTheme.Colors.accentBlue
        case .music: return ProTheme.Colors.accentPurple
        }
    }
    
    var glowColor: Color {
        switch self {
        case .video: return Color(red: 0.1, green: 0.9, blue: 1.0)
        case .music: return Color(red: 0.55, green: 0.36, blue: 1.0)
        }
    }
}

/// A bespoke, 1% professional-grade media mode selector with glass-morphism,
/// sliding capsule animation, and dynamic glow effects.
struct ProfessionalMediaSelector: View {
    @Binding var selectedMode: MediaMode
    @Namespace private var selectorNamespace
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MediaMode.allCases, id: \.rawValue) { mode in
                modeButton(mode)
            }
        }
        .padding(3)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial.opacity(0.4))
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                selectedMode.glowColor.opacity(0.4),
                                selectedMode.glowColor.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: selectedMode.glowColor.opacity(0.25), radius: 12, y: 4)
        .animation(ProTheme.Animations.interactive, value: selectedMode)
    }
    
    @ViewBuilder
    private func modeButton(_ mode: MediaMode) -> some View {
        Button {
            withAnimation(ProTheme.Animations.interactive) {
                selectedMode = mode
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .symbolEffect(.bounce, value: selectedMode == mode)
                
                Text(mode.rawValue)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(0.5)
            }
            .foregroundColor(selectedMode == mode ? .white : ProTheme.Colors.textTertiary)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                ZStack {
                    if selectedMode == mode {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        mode.accentColor.opacity(0.7),
                                        mode.accentColor.opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .matchedGeometryEffect(id: "selector_capsule", in: selectorNamespace)
                        
                        // Inner glow
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(mode.glowColor.opacity(0.5), lineWidth: 0.5)
                            .matchedGeometryEffect(id: "selector_border", in: selectorNamespace)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}
