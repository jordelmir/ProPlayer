import SwiftUI

struct MusicLibraryView: View {
    @ObservedObject var musicVM: MusicLibraryViewModel
    @State private var editingTrack: MusicTrack?
    
    var body: some View {
        HSplitView {
            // Main list
            mainContent
                .frame(minWidth: 500)
            
            // Metadata editor panel
            if let track = editingTrack {
                MetadataEditorView(
                    track: Binding(
                        get: { track },
                        set: { editingTrack = $0 }
                    ),
                    onSave: { updated in
                        musicVM.saveMetadata(for: updated)
                        editingTrack = nil
                    },
                    onCancel: {
                        editingTrack = nil
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(ProTheme.Animations.smooth, value: editingTrack?.id)
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Toolbar
            musicToolbar
                .padding(.horizontal, ProTheme.Spacing.xl)
                .padding(.vertical, ProTheme.Spacing.md)
            
            Divider()
                .overlay(ProTheme.Colors.accentPurple.opacity(0.2))
            
            if musicVM.isScanning {
                scanningView
            } else if musicVM.filteredTracks.isEmpty {
                emptyMusicState
            } else {
                trackListView
            }
        }
        .background(
            ZStack {
                ProTheme.Colors.deepBlack
                // Subtle purple ambient
                RadialGradient(
                    colors: [ProTheme.Colors.accentPurple.opacity(0.05), Color.clear],
                    center: .topTrailing,
                    startRadius: 100,
                    endRadius: 500
                )
            }
        )
    }
    
    // MARK: - Toolbar
    
    private var musicToolbar: some View {
        HStack(spacing: ProTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Music Library")
                    .font(ProTheme.Fonts.displayMedium)
                    .foregroundColor(ProTheme.Colors.textPrimary)
                
                Text("\(musicVM.filteredTracks.count) tracks")
                    .font(ProTheme.Fonts.caption)
                    .foregroundColor(ProTheme.Colors.accentPurple.opacity(0.8))
            }
            
            Spacer()
            
            // Search
            HStack(spacing: ProTheme.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ProTheme.Colors.textTertiary)
                TextField("Search music...", text: $musicVM.searchText)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 300)
                if !musicVM.searchText.isEmpty {
                    Button { musicVM.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ProTheme.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ProTheme.Spacing.sm)
            .padding(.vertical, ProTheme.Spacing.xs)
            .background(ProTheme.Colors.surfaceMedium)
            .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.small))
            
            // Add Music Folder
            Button {
                if let url = musicVM.showMusicFolderDialog() {
                    musicVM.addFolder(url)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.plus")
                    Text("Add Music")
                        .font(ProTheme.Fonts.controlLabel)
                }
                .foregroundColor(ProTheme.Colors.accentPurple)
                .padding(.horizontal, ProTheme.Spacing.sm)
                .padding(.vertical, ProTheme.Spacing.xs)
                .background(ProTheme.Colors.accentPurple.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.small))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Track List
    
    private var trackListView: some View {
        List {
            // Column Headers
            HStack(spacing: 0) {
                Text("#")
                    .frame(width: 30, alignment: .leading)
                Text("TITLE")
                    .frame(minWidth: 200, alignment: .leading)
                Text("ARTIST")
                    .frame(width: 150, alignment: .leading)
                Text("ALBUM")
                    .frame(width: 150, alignment: .leading)
                Text("YEAR")
                    .frame(width: 50, alignment: .center)
                Text("GENRE")
                    .frame(width: 80, alignment: .leading)
                Spacer()
                Text("DURATION")
                    .frame(width: 60, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(1)
            .foregroundColor(ProTheme.Colors.textTertiary)
            .padding(.vertical, 4)
            .listRowBackground(Color.clear)
            
            ForEach(Array(musicVM.filteredTracks.enumerated()), id: \.element.id) { index, track in
                MusicTrackRow(
                    track: track,
                    index: index + 1,
                    isSelected: editingTrack?.id == track.id,
                    onEdit: {
                        withAnimation(ProTheme.Animations.smooth) {
                            editingTrack = track
                        }
                    },
                    onRemove: { musicVM.removeTrack(track) }
                )
                .listRowBackground(
                    editingTrack?.id == track.id
                        ? ProTheme.Colors.accentPurple.opacity(0.1)
                        : Color.clear
                )
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Empty State
    
    private var emptyMusicState: some View {
        VStack(spacing: ProTheme.Spacing.xxl) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(ProTheme.Colors.accentPurple.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundColor(ProTheme.Colors.accentPurple.opacity(0.6))
            }
            .shadow(color: ProTheme.Colors.accentPurple.opacity(0.3), radius: 20)
            
            Text("No Music Yet")
                .font(ProTheme.Fonts.displayMedium)
                .foregroundColor(ProTheme.Colors.textPrimary)
            
            Text("Add a folder to scan for music files.\nEdit tags, artwork, and more—right here.")
                .font(ProTheme.Fonts.body)
                .foregroundColor(ProTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                if let url = musicVM.showMusicFolderDialog() {
                    musicVM.scanFolder(url)
                }
            } label: {
                Label("Select Music Folder", systemImage: "folder.badge.plus")
                    .font(ProTheme.Fonts.subheadline)
                    .padding(.horizontal, ProTheme.Spacing.xl)
                    .padding(.vertical, ProTheme.Spacing.md)
                    .background(
                        LinearGradient(
                            colors: [ProTheme.Colors.accentPurple, ProTheme.Colors.accentPurple.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.medium))
                    .shadow(color: ProTheme.Colors.accentPurple.opacity(0.5), radius: 12)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Scanning
    
    private var scanningView: some View {
        VStack(spacing: ProTheme.Spacing.md) {
            ProgressView()
                .tint(ProTheme.Colors.accentPurple)
                .scaleEffect(1.3)
            Text("Scanning music files...")
                .font(ProTheme.Fonts.body)
                .foregroundColor(ProTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Track Row

struct MusicTrackRow: View {
    let track: MusicTrack
    let index: Int
    let isSelected: Bool
    let onEdit: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Index / Play
            ZStack {
                Text("\(index)")
                    .font(ProTheme.Fonts.mono)
                    .foregroundColor(ProTheme.Colors.textTertiary)
                    .opacity(isHovered ? 0 : 1)
                
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
                    .foregroundColor(ProTheme.Colors.accentPurple)
                    .opacity(isHovered ? 1 : 0)
            }
            .frame(width: 30, alignment: .leading)
            
            // Artwork mini + Title
            HStack(spacing: ProTheme.Spacing.sm) {
                // Mini artwork
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ProTheme.Colors.surfaceMedium)
                        .frame(width: 32, height: 32)
                    
                    if let data = track.artworkData, let image = NSImage(data: data) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 12))
                            .foregroundColor(ProTheme.Colors.accentPurple.opacity(0.5))
                    }
                }
                
                Text(track.title)
                    .font(ProTheme.Fonts.subheadline)
                    .foregroundColor(ProTheme.Colors.textPrimary)
                    .lineLimit(1)
            }
            .frame(minWidth: 200 - 32, alignment: .leading)
            
            Text(track.artist)
                .font(ProTheme.Fonts.body)
                .foregroundColor(ProTheme.Colors.textSecondary)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
            
            Text(track.album)
                .font(ProTheme.Fonts.body)
                .foregroundColor(ProTheme.Colors.textSecondary)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
            
            Text(track.year)
                .font(ProTheme.Fonts.caption)
                .foregroundColor(ProTheme.Colors.textTertiary)
                .frame(width: 50, alignment: .center)
            
            Text(track.genre)
                .font(ProTheme.Fonts.caption)
                .foregroundColor(ProTheme.Colors.textTertiary)
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            Text(track.durationLabel)
                .font(ProTheme.Fonts.mono)
                .foregroundColor(ProTheme.Colors.textSecondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) { onEdit() }
        .contextMenu {
            Button("Edit Tags") { onEdit() }
            Divider()
            Button("Remove from Library") { onRemove() }
        }
        .animation(ProTheme.Animations.quick, value: isHovered)
    }
}
