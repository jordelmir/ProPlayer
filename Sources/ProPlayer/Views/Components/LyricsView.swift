import SwiftUI

struct LyricsView: View {
    @ObservedObject var engine = MusicPlayerEngine.shared
    @State private var lyricsResult: LyricsResult?
    @State private var syncedLines: [(TimeInterval, String)] = []
    @State private var isFetching = false
    @State private var fetchError: String?
    
    // Auto-scroll anchor ID
    private let activeLineID = "ActiveSyncLine"
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "quote.bubble.fill")
                    .foregroundColor(ProTheme.Colors.accentPurple)
                Text("Lyrics")
                    .font(ProTheme.Fonts.headline)
                    .foregroundColor(ProTheme.Colors.textPrimary)
                
                Spacer()
                
                if let provider = lyricsResult?.provider {
                    Text("Powered by \(provider)")
                        .font(ProTheme.Fonts.caption)
                        .foregroundColor(ProTheme.Colors.textTertiary)
                }
                
                Button(action: fetchLyrics) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(ProTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .hoverEffect()
                .padding(.leading, 8)
            }
            .padding()
            .background(Color.black.opacity(0.3))
            
            Divider()
            
            // Content
            ZStack {
                if isFetching {
                    ProgressView()
                        .tint(ProTheme.Colors.accentPurple)
                } else if let error = fetchError {
                    Text(error)
                        .font(ProTheme.Fonts.body)
                        .foregroundColor(ProTheme.Colors.accentRed)
                        .multilineTextAlignment(.center)
                        .padding()
                } else if !syncedLines.isEmpty {
                    syncedLyricsList
                } else if let plain = lyricsResult?.plainLyrics {
                    plainLyricsView(text: plain)
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.05, green: 0.05, blue: 0.08))
        }
        .frame(width: 350)
        .glassBackground(cornerRadius: 0)
        .onChange(of: engine.currentTrack?.id) { _, _ in
            fetchLyrics()
        }
        .onAppear {
            if lyricsResult == nil { fetchLyrics() }
        }
    }
    
    // MARK: - Views
    
    private var syncedLyricsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: ProTheme.Spacing.lg) {
                    // Empty space at top
                    Color.clear.frame(height: 150)
                    
                    ForEach(Array(syncedLines.enumerated()), id: \.offset) { index, lineData in
                        let (time, text) = lineData
                        let isActive = isLineActive(index: index)
                        
                        Text(text.isEmpty ? "• • •" : text)
                            .font(isActive ? ProTheme.Fonts.displayMedium : ProTheme.Fonts.headline)
                            .foregroundColor(isActive ? .white : ProTheme.Colors.textTertiary)
                            .blur(radius: isActive ? 0 : 0.8)
                            .scaleEffect(isActive ? 1.05 : 1.0, anchor: .leading)
                            .shadow(color: isActive ? ProTheme.Colors.accentPurple.opacity(0.5) : .clear, radius: 10)
                            .animation(ProTheme.Animations.spring, value: isActive)
                            .onTapGesture {
                                engine.seekTo(time)
                            }
                            .id(isActive ? activeLineID : "Line-\(index)")
                    }
                    
                    // Empty space at bottom
                    Color.clear.frame(height: 300)
                }
                .padding(.horizontal, ProTheme.Spacing.xl)
            }
            .onChange(of: engine.currentTime) { _, _ in
                // Throttle scroll updates slightly
                withAnimation(ProTheme.Animations.smooth) {
                    proxy.scrollTo(activeLineID, anchor: .center)
                }
            }
        }
    }
    
    private func plainLyricsView(text: String) -> some View {
        ScrollView {
            Text(text)
                .font(ProTheme.Fonts.body)
                .foregroundColor(ProTheme.Colors.textSecondary)
                .lineSpacing(8)
                .padding(ProTheme.Spacing.xl)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: ProTheme.Spacing.lg) {
            Image(systemName: "music.mic")
                .font(.system(size: 48))
                .foregroundColor(ProTheme.Colors.textTertiary)
            
            Text("No lyrics available")
                .font(ProTheme.Fonts.headline)
                .foregroundColor(ProTheme.Colors.textSecondary)
            
            if engine.currentTrack != nil {
                Button("Search Online") {
                    fetchLyrics()
                }
                .buttonStyle(.borderedProminent)
                .tint(ProTheme.Colors.accentPurple)
            }
        }
    }
    
    // MARK: - Logic
    
    private func fetchLyrics() {
        guard let track = engine.currentTrack else { return }
        
        isFetching = true
        fetchError = nil
        lyricsResult = nil
        syncedLines = []
        
        Task {
            do {
                if let result = try await LyricsService.shared.fetchLyrics(for: track) {
                    await MainActor.run {
                        self.lyricsResult = result
                        if let synced = result.syncedLyrics {
                            self.syncedLines = LyricsService.parseLRC(synced)
                        }
                    }
                } else {
                    await MainActor.run {
                        self.fetchError = "Lyrics not found for this track."
                    }
                }
            } catch {
                await MainActor.run {
                    self.fetchError = "Network error: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                self.isFetching = false
            }
        }
    }
    
    private func isLineActive(index: Int) -> Bool {
        let (lineTime, _) = syncedLines[index]
        let nextTime = index + 1 < syncedLines.count ? syncedLines[index + 1].0 : Double.greatestFiniteMagnitude
        // We consider the line active if current time is between this line and the next.
        // Lead in slightly (0.3s) for smoother reading
        return engine.currentTime >= (lineTime - 0.3) && engine.currentTime < (nextTime - 0.3)
    }
}
