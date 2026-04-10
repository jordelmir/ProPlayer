import SwiftUI

struct AlbumGroup: Identifiable {
    let id: String
    let album: String
    let artist: String
    let tracks: [MusicTrack]
    let artworkData: Data?
}

struct AlbumArtGridView: View {
    @ObservedObject var libraryVM: MusicLibraryViewModel
    
    @State private var expandedAlbumID: String? = nil
    @Namespace private var albumGridNamespace
    
    // Group tracks by album string (ignoring case)
    private var albumGroups: [AlbumGroup] {
        let grouped = Dictionary(grouping: libraryVM.tracks) { $0.album.lowercased() }
        return grouped.map { (key, tracks) in
            let sortedTracks = tracks.sorted { 
                let t1Str = $0.trackNumber.components(separatedBy: "/").first ?? "0"
                let t2Str = $1.trackNumber.components(separatedBy: "/").first ?? "0"
                let t1 = Int(t1Str) ?? 0
                let t2 = Int(t2Str) ?? 0
                return t1 < t2 
            }
            return AlbumGroup(
                id: key,
                album: tracks.first?.album ?? "Unknown Album",
                artist: tracks.first?.artist ?? "Unknown Artist",
                tracks: sortedTracks,
                artworkData: tracks.first(where: { $0.artworkData != nil })?.artworkData
            )
        }
        .sorted { $0.album < $1.album }
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: ProTheme.Spacing.lg)], spacing: ProTheme.Spacing.xl) {
                ForEach(albumGroups) { group in
                    VStack {
                        if expandedAlbumID == group.id {
                            // Empty placeholder in grid for the expanded view below
                            Color.clear.frame(height: 180)
                        } else {
                            albumCard(for: group)
                                .matchedGeometryEffect(id: group.id, in: albumGridNamespace)
                                .onTapGesture {
                                    withAnimation(ProTheme.Animations.spring) {
                                        if expandedAlbumID == group.id {
                                            expandedAlbumID = nil
                                        } else {
                                            expandedAlbumID = group.id
                                        }
                                    }
                                }
                        }
                    }
                }
            }
            .padding(ProTheme.Spacing.xl)
        }
        .overlay {
            if let expandedID = expandedAlbumID,
               let group = albumGroups.first(where: { $0.id == expandedID }) {
                expandedAlbumView(for: group)
            }
        }
    }
    
    @ViewBuilder
    private func albumCard(for group: AlbumGroup) -> some View {
        VStack(alignment: .leading, spacing: ProTheme.Spacing.sm) {
            ZStack {
                if let data = group.artworkData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.medium))
                } else {
                    RoundedRectangle(cornerRadius: ProTheme.Radius.medium)
                        .fill(
                            LinearGradient(
                                colors: [ProTheme.Colors.surfaceMedium, ProTheme.Colors.surfaceDark],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 180, height: 180)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundColor(ProTheme.Colors.accentPurple.opacity(0.3))
                }
                
                // Hover play button overlay could go here
            }
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .hoverEffect()
            
            Text(group.album)
                .font(ProTheme.Fonts.subheadline)
                .foregroundColor(ProTheme.Colors.textPrimary)
                .lineLimit(1)
            
            Text(group.artist)
                .font(ProTheme.Fonts.caption)
                .foregroundColor(ProTheme.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 180)
    }
    
    @ViewBuilder
    private func expandedAlbumView(for group: AlbumGroup) -> some View {
        ZStack {
            // Background blur cover
            Color.black.opacity(0.6)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(ProTheme.Animations.spring) {
                        expandedAlbumID = nil
                    }
                }
            
            VStack(spacing: 0) {
                // Header with card transition
                HStack(alignment: .top, spacing: ProTheme.Spacing.xl) {
                    albumCard(for: group)
                        .matchedGeometryEffect(id: group.id, in: albumGridNamespace)
                    
                    VStack(alignment: .leading, spacing: ProTheme.Spacing.md) {
                        Text(group.album)
                            .font(ProTheme.Fonts.displayLarge)
                            .foregroundColor(.white)
                        
                        Text(group.artist)
                            .font(ProTheme.Fonts.displayMedium)
                            .foregroundColor(ProTheme.Colors.accentPurple)
                        
                        Text("\(group.tracks.count) tracks • \(totalDuration(for: group.tracks))")
                            .font(ProTheme.Fonts.subheadline)
                            .foregroundColor(ProTheme.Colors.textSecondary)
                        
                        HStack {
                            Button(action: {
                                MusicPlayerEngine.shared.playAll(group.tracks)
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Play Album")
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(ProTheme.Colors.accentPurple)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .hoverEffect()
                            
                            Spacer()
                        }
                        .padding(.top, ProTheme.Spacing.md)
                    }
                    Spacer()
                    
                    Button {
                        withAnimation(ProTheme.Animations.spring) {
                            expandedAlbumID = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(ProTheme.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .hoverEffect()
                }
                .padding(ProTheme.Spacing.xxl)
                .background(Color.black.opacity(0.5))
                
                // Track list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(group.tracks.enumerated()), id: \.element.id) { index, track in
                            HStack {
                                Text("\(index + 1)")
                                    .font(ProTheme.Fonts.mono)
                                    .foregroundColor(ProTheme.Colors.textTertiary)
                                    .frame(width: 30, alignment: .trailing)
                                
                                Text(track.title)
                                    .font(ProTheme.Fonts.body)
                                    .foregroundColor(ProTheme.Colors.textPrimary)
                                    .padding(.leading, ProTheme.Spacing.md)
                                
                                Spacer()
                                
                                Text(track.durationLabel)
                                    .font(ProTheme.Fonts.monoSmall)
                                    .foregroundColor(ProTheme.Colors.textSecondary)
                            }
                            .padding(.horizontal, ProTheme.Spacing.xxl)
                            .padding(.vertical, ProTheme.Spacing.md)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                MusicPlayerEngine.shared.playAll(group.tracks, startingAt: index)
                            }
                            // Hover highlighting
                            .background(MusicPlayerEngine.shared.currentTrack?.id == track.id ? ProTheme.Colors.accentPurple.opacity(0.2) : Color.clear)
                            
                            Divider().opacity(0.1)
                                .padding(.leading, 50)
                        }
                    }
                    .padding(.vertical, ProTheme.Spacing.lg)
                }
            }
            .frame(maxWidth: 800, maxHeight: 600)
            .glassBackground()
            .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
        }
        .zIndex(100)
        .transition(.opacity)
    }
    
    private func totalDuration(for tracks: [MusicTrack]) -> String {
        let totalSeconds = tracks.reduce(0.0) { $0 + $1.duration }
        let mins = Int(totalSeconds) / 60
        let secs = Int(totalSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
