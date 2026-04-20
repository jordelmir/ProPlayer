import SwiftUI

struct BreathingLogoView: View {
    let size: CGFloat
    let glowRadius: CGFloat
    
    @State private var isBreathing = false
    
    var body: some View {
        if let nsImage = NSImage(contentsOfFile: Bundle.proPlayerApp.path(forResource: "ElysiumLogo", ofType: "png") ?? "") {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: Color(red: 0.1, green: 0.9, blue: 1.0).opacity(0.8), radius: isBreathing ? glowRadius : glowRadius * 0.2)
                .shadow(color: Color.blue.opacity(0.6), radius: isBreathing ? glowRadius * 0.5 : 0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        isBreathing = true
                    }
                }
        } else {
            // Fallback if resource fails
            Image(systemName: "triangle.fill")
                .font(.system(size: size))
                .foregroundColor(Color(red: 0.1, green: 0.9, blue: 1.0))
                .rotationEffect(.degrees(90))
                .shadow(color: Color(red: 0.1, green: 0.9, blue: 1.0), radius: isBreathing ? glowRadius : 0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        isBreathing = true
                    }
                }
        }
    }
}
