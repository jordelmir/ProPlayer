import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep = 0
    private let totalSteps = 4
    
    var body: some View {
        ZStack {
            // Animated Background
            Color.black.ignoresSafeArea()
            MatrixRainView(themeColor: ProTheme.Colors.accentPurple)
                .opacity(0.15)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Content Carousel
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        
                        // Step 0: Welcome
                        VStack(spacing: ProTheme.Spacing.xxl) {
                            BreathingLogoView(size: 140, glowRadius: 40)
                                .padding(.bottom, 40)
                            
                            Text("Elysium Vanguard Pro")
                                .font(ProTheme.Fonts.displayLarge)
                                .foregroundColor(.white)
                            
                            Text("The ultimate 8K Video + High-Fidelity Music dual-engine suite.")
                                .font(ProTheme.Fonts.headline)
                                .foregroundColor(ProTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 400)
                        }
                        .frame(width: geo.size.width)
                        
                        // Step 1: Video Engine
                        VStack(spacing: ProTheme.Spacing.xxl) {
                            Image(systemName: "film.stack")
                                .font(.system(size: 100))
                                .foregroundColor(ProTheme.Colors.accentBlue)
                                .shadow(color: ProTheme.Colors.accentBlue.opacity(0.5), radius: 20)
                                .padding(.bottom, 20)
                            
                            Text("Cinematic Video")
                                .font(ProTheme.Fonts.displayMedium)
                                .foregroundColor(.white)
                            
                            Text("Hardware-accelerated Metal rendering, ACES tone mapping, and temporal noise reduction for pixel-perfect 8K playback.")
                                .font(ProTheme.Fonts.body)
                                .foregroundColor(ProTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 400)
                        }
                        .frame(width: geo.size.width)
                        
                        // Step 2: Music Engine
                        VStack(spacing: ProTheme.Spacing.xxl) {
                            Image(systemName: "waveform")
                                .font(.system(size: 100))
                                .foregroundColor(ProTheme.Colors.accentPurple)
                                .shadow(color: ProTheme.Colors.accentPurple.opacity(0.5), radius: 20)
                                .padding(.bottom, 20)
                            
                            Text("Intelligent Music Library")
                                .font(ProTheme.Fonts.displayMedium)
                                .foregroundColor(.white)
                            
                            Text("Gapless playback, real-time waveform visualization, synced lyrics, and automated MusicBrainz tagging for your perfect collection.")
                                .font(ProTheme.Fonts.body)
                                .foregroundColor(ProTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 400)
                        }
                        .frame(width: geo.size.width)
                        
                        // Step 3: Get Started
                        VStack(spacing: ProTheme.Spacing.xxl) {
                            Image(systemName: "folder.badge.gearshape")
                                .font(.system(size: 100))
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.3), radius: 20)
                                .padding(.bottom, 20)
                            
                            Text("Ready to Begin")
                                .font(ProTheme.Fonts.displayMedium)
                                .foregroundColor(.white)
                            
                            Text("Point Elysium Vanguard to your media folders and let the engine index your library instantly.")
                                .font(ProTheme.Fonts.body)
                                .foregroundColor(ProTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 400)
                        }
                        .frame(width: geo.size.width)
                        
                    }
                    .offset(x: -CGFloat(currentStep) * geo.size.width)
                    .animation(ProTheme.Animations.smooth, value: currentStep)
                }
                
                Spacer()
                
                // Bottom Navigation
                HStack {
                    // Skip
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .font(ProTheme.Fonts.subheadline)
                    .foregroundColor(ProTheme.Colors.textTertiary)
                    .buttonStyle(.plain)
                    .hoverEffect()
                    .opacity(currentStep == totalSteps - 1 ? 0 : 1)
                    
                    Spacer()
                    
                    // Dots
                    HStack(spacing: 8) {
                        ForEach(0..<totalSteps, id: \.self) { i in
                            Circle()
                                .fill(currentStep == i ? .white : .white.opacity(0.2))
                                .frame(width: 8, height: 8)
                                .scaleEffect(currentStep == i ? 1.2 : 1.0)
                                .animation(.spring(), value: currentStep)
                        }
                    }
                    
                    Spacer()
                    
                    // Next / Start
                    if currentStep < totalSteps - 1 {
                        Button("Next") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .font(ProTheme.Fonts.subheadline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                        .hoverEffect()
                    } else {
                        Button("Start Experience") {
                            completeOnboarding()
                        }
                        .font(ProTheme.Fonts.subheadline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(colors: [ProTheme.Colors.accentBlue, ProTheme.Colors.accentPurple], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                        .hoverEffect()
                        .shadow(color: ProTheme.Colors.accentBlue.opacity(0.4), radius: 10)
                    }
                }
                .padding(40)
            }
        }
        .frame(width: 800, height: 500)
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}
