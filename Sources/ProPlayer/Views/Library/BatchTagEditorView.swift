import SwiftUI
import AppKit

struct BatchTagEditorView: View {
    @ObservedObject var libraryVM: MusicLibraryViewModel
    let tracks: [MusicTrack]
    @Environment(\.dismiss) private var dismiss
    
    @State private var artist: String = ""
    @State private var album: String = ""
    @State private var year: String = ""
    @State private var genre: String = ""
    
    @State private var modifyArtist = false
    @State private var modifyAlbum = false
    @State private var modifyYear = false
    @State private var modifyGenre = false
    
    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var statusMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Batch Edit Selected (\(tracks.count) tracks)")
                    .font(ProTheme.Fonts.displayMedium)
                    .foregroundColor(ProTheme.Colors.textPrimary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ProTheme.Colors.textTertiary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.black.opacity(0.3))
            
            Form {
                Section("Metadata to Apply") {
                    ToggleField(
                        title: "Artist",
                        text: $artist,
                        isOn: $modifyArtist,
                        placeholder: commonValue(for: \.artist) ?? "Multiple Values"
                    )
                    
                    ToggleField(
                        title: "Album",
                        text: $album,
                        isOn: $modifyAlbum,
                        placeholder: commonValue(for: \.album) ?? "Multiple Values"
                    )
                    
                    ToggleField(
                        title: "Year",
                        text: $year,
                        isOn: $modifyYear,
                        placeholder: commonValue(for: \.year) ?? "Multiple Values"
                    )
                    
                    ToggleField(
                        title: "Genre",
                        text: $genre,
                        isOn: $modifyGenre,
                        placeholder: commonValue(for: \.genre) ?? "Multiple Values"
                    )
                }
                
                Section("Smart Actions") {
                    Button(action: autoTagAll) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Auto-Tag Automatically via MusicBrainz")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ProTheme.Colors.accentPurple)
                    .disabled(isProcessing)
                }
            }
            .formStyle(.grouped)
            .disabled(isProcessing)
            
            // Footer
            VStack(spacing: ProTheme.Spacing.md) {
                if isProcessing {
                    ProgressView(value: progress, total: 1.0)
                        .tint(ProTheme.Colors.accentPurple)
                    if let msg = statusMessage {
                        Text(msg)
                            .font(ProTheme.Fonts.caption)
                            .foregroundColor(ProTheme.Colors.textSecondary)
                    }
                }
                
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
                    
                    Spacer()
                    
                    Button("Save Selected Changes") {
                        saveChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ProTheme.Colors.accentBlue)
                    .disabled(isProcessing || (!modifyArtist && !modifyAlbum && !modifyYear && !modifyGenre))
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
        }
        .frame(width: 500, height: 600)
        .glassBackground()
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Logic
    
    private func commonValue(for keyPath: KeyPath<MusicTrack, String>) -> String? {
        guard let first = tracks.first else { return nil }
        let value = first[keyPath: keyPath]
        if tracks.allSatisfy({ $0[keyPath: keyPath] == value }) {
            return value
        }
        return nil
    }
    
    private func saveChanges() {
        isProcessing = true
        statusMessage = "Saving changes..."
        progress = 0
        
        Task {
            var updatedTracks = tracks
            for i in 0..<updatedTracks.count {
                if modifyArtist { updatedTracks[i].artist = artist }
                if modifyAlbum { updatedTracks[i].album = album }
                if modifyYear { updatedTracks[i].year = year }
                if modifyGenre { updatedTracks[i].genre = genre }
            }
            
            for (idx, track) in updatedTracks.enumerated() {
                try? await MusicMetadataService.shared.writeMetadata(track)
                
                await MainActor.run {
                    if let index = libraryVM.tracks.firstIndex(where: { $0.id == track.id }) {
                        libraryVM.tracks[index] = track
                    }
                    progress = Double(idx + 1) / Double(updatedTracks.count)
                }
            }
            
            await MainActor.run {
                isProcessing = false
                dismiss()
            }
        }
    }
    
    private func autoTagAll() {
        isProcessing = true
        progress = 0
        
        Task {
            let total = Double(tracks.count)
            var idx = 0.0
            
            for track in tracks {
                await MainActor.run {
                    statusMessage = "Identifying: \(track.title)..."
                }
                
                if let identified = try? await MusicMetadataService.shared.autoTag(track: track) {
                    try? await MusicMetadataService.shared.writeMetadata(identified)
                    
                    await MainActor.run {
                        if let targetIdx = libraryVM.tracks.firstIndex(where: { $0.id == track.id }) {
                            libraryVM.tracks[targetIdx] = identified
                        }
                    }
                }
                
                idx += 1.0
                await MainActor.run { progress = idx / total }
                // Delay to respect API rate limits (1 req/sec)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            await MainActor.run {
                statusMessage = "Auto-tag complete!"
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                isProcessing = false
                dismiss()
            }
        }
    }
}

// Custom Helper for Checkbox + TextField
struct ToggleField: View {
    let title: String
    @Binding var text: String
    @Binding var isOn: Bool
    let placeholder: String
    
    var body: some View {
        HStack {
            Toggle("", isOn: $isOn)
                .labelsHidden()
            
            Text(title)
                .frame(width: 60, alignment: .leading)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .disabled(!isOn)
        }
    }
}
