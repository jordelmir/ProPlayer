import SwiftUI

struct ProfessionalMediaSelector: View {
    @Binding var selectedTab: MainView.MediaTab
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            selectorButton(title: "VÍDEO", tab: .video, icon: "film.fill")
            selectorButton(title: "MÚSICA", tab: .music, icon: "music.note")
        }
        .padding(ProTheme.Spacing.xs)
        .background(
            ZStack {
                // Glass Base
                RoundedRectangle(cornerRadius: ProTheme.Radius.medium)
                    .fill(.ultraThinMaterial.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: ProTheme.Radius.medium)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                
                // Sliding Accent
                HStack {
                    if selectedTab == .music { Spacer() }
                    
                    RoundedRectangle(cornerRadius: ProTheme.Radius.small)
                        .fill(
                            LinearGradient(
                                colors: [
                                    selectedTab == .video ? ProTheme.Colors.accentBlue : ProTheme.Colors.accentPurple,
                                    selectedTab == .video ? ProTheme.Colors.accentPurple : ProTheme.Colors.accentBlue.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .matchedGeometryEffect(id: "selector", in: animation)
                        .frame(width: 140)
                        .shadow(
                            color: (selectedTab == .video ? ProTheme.Colors.accentBlue : ProTheme.Colors.accentPurple).opacity(0.5),
                            radius: 12, x: 0, y: 0
                        )
                    
                    if selectedTab == .video { Spacer() }
                }
                .padding(ProTheme.Spacing.xs)
            }
        )
        .frame(width: 290, height: 44)
    }
    
    private func selectorButton(title: String, tab: MainView.MediaTab, icon: String) -> some View {
        Button {
            withAnimation(ProTheme.Animations.interactive) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: ProTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(ProTheme.Fonts.controlLabel)
                    .tracking(1.5)
            }
            .foregroundColor(selectedTab == tab ? .white : ProTheme.Colors.textSecondary)
            .frame(width: 140, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
