import SwiftUI

struct MetadataEditorView: View {
    @Binding var track: MusicTrack
    let onSave: (MusicTrack) -> Void
    let onCancel: () -> Void
    
    @State private var editedTrack: MusicTrack
    @State private var artworkImage: NSImage?
    @State private var isPickingArtwork = false
    
    init(track: Binding<MusicTrack>, onSave: @escaping (MusicTrack) -> Void, onCancel: @escaping () -> Void) {
        self._track = track
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedTrack = State(initialValue: track.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
                .overlay(ProTheme.Colors.accentPurple.opacity(0.3))
            
            ScrollView {
                VStack(spacing: ProTheme.Spacing.xl) {
                    // Artwork Section
                    artworkSection
                    
                    // Fields
                    fieldsSection
                }
                .padding(ProTheme.Spacing.xl)
            }
            
            Divider()
                .overlay(ProTheme.Colors.accentPurple.opacity(0.3))
            
            // Action Bar
            actionBar
        }
        .frame(width: 380)
        .background(
            ZStack {
                ProTheme.Colors.surfaceDark
                ProTheme.Colors.accentPurple.opacity(0.03)
            }
        )
        .onAppear {
            loadArtworkImage()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("METADATA EDITOR")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundColor(ProTheme.Colors.accentPurple)
                
                Text(editedTrack.title)
                    .font(ProTheme.Fonts.subheadline)
                    .foregroundColor(ProTheme.Colors.textPrimary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button { onCancel() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(ProTheme.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(ProTheme.Spacing.lg)
    }
    
    // MARK: - Artwork
    
    private var artworkSection: some View {
        VStack(spacing: ProTheme.Spacing.md) {
            // Artwork display
            ZStack {
                RoundedRectangle(cornerRadius: ProTheme.Radius.large)
                    .fill(ProTheme.Colors.surfaceMedium)
                    .frame(width: 200, height: 200)
                
                if let image = artworkImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.large))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundColor(ProTheme.Colors.accentPurple.opacity(0.5))
                        Text("No Artwork")
                            .font(ProTheme.Fonts.caption)
                            .foregroundColor(ProTheme.Colors.textTertiary)
                    }
                }
            }
            .shadow(color: ProTheme.Colors.accentPurple.opacity(0.3), radius: 12, y: 4)
            .onTapGesture { pickArtwork() }
            
            // Artwork buttons
            HStack(spacing: ProTheme.Spacing.sm) {
                Button { pickArtwork() } label: {
                    Label("Change Cover", systemImage: "photo.on.rectangle.angled")
                        .font(ProTheme.Fonts.controlLabel)
                }
                .buttonStyle(.bordered)
                .tint(ProTheme.Colors.accentPurple)
                
                if artworkImage != nil {
                    Button {
                        artworkImage = nil
                        editedTrack.artworkData = nil
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(ProTheme.Fonts.controlLabel)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
    }
    
    // MARK: - Fields
    
    private var fieldsSection: some View {
        VStack(spacing: ProTheme.Spacing.md) {
            metadataField(label: "Title", icon: "textformat", text: $editedTrack.title)
            metadataField(label: "Artist", icon: "person.fill", text: $editedTrack.artist)
            metadataField(label: "Album", icon: "opticaldisc.fill", text: $editedTrack.album)
            
            HStack(spacing: ProTheme.Spacing.md) {
                metadataField(label: "Year", icon: "calendar", text: $editedTrack.year)
                metadataField(label: "Track #", icon: "number", text: $editedTrack.trackNumber)
            }
            
            metadataField(label: "Genre", icon: "guitars.fill", text: $editedTrack.genre)
            
            // Info (read-only)
            VStack(alignment: .leading, spacing: ProTheme.Spacing.xs) {
                Text("FILE INFO")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(ProTheme.Colors.textTertiary)
                
                HStack {
                    Label(editedTrack.durationLabel, systemImage: "clock")
                    Spacer()
                    Label(editedTrack.fileSizeLabel, systemImage: "doc")
                }
                .font(ProTheme.Fonts.caption)
                .foregroundColor(ProTheme.Colors.textSecondary)
                
                Text(editedTrack.url.lastPathComponent)
                    .font(ProTheme.Fonts.caption)
                    .foregroundColor(ProTheme.Colors.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(ProTheme.Spacing.md)
            .background(ProTheme.Colors.surfaceMedium.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.small))
        }
    }
    
    // MARK: - Action Bar
    
    private var actionBar: some View {
        HStack {
            Button("Cancel") { onCancel() }
                .buttonStyle(.plain)
                .foregroundColor(ProTheme.Colors.textSecondary)
            
            Spacer()
            
            Button {
                onSave(editedTrack)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Tags")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, ProTheme.Spacing.lg)
                .padding(.vertical, ProTheme.Spacing.sm)
                .background(
                    LinearGradient(
                        colors: [ProTheme.Colors.accentPurple, ProTheme.Colors.accentPurple.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.small))
                .shadow(color: ProTheme.Colors.accentPurple.opacity(0.4), radius: 8)
            }
            .buttonStyle(.plain)
        }
        .padding(ProTheme.Spacing.lg)
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func metadataField(label: String, icon: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(ProTheme.Colors.accentPurple.opacity(0.7))
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(ProTheme.Colors.textTertiary)
            }
            
            TextField(label, text: text)
                .textFieldStyle(.plain)
                .font(ProTheme.Fonts.body)
                .foregroundColor(ProTheme.Colors.textPrimary)
                .padding(.horizontal, ProTheme.Spacing.sm)
                .padding(.vertical, ProTheme.Spacing.xs + 2)
                .background(ProTheme.Colors.surfaceMedium)
                .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: ProTheme.Radius.small)
                        .strokeBorder(ProTheme.Colors.accentPurple.opacity(0.15), lineWidth: 1)
                )
        }
    }
    
    private func loadArtworkImage() {
        guard let data = editedTrack.artworkData else { return }
        artworkImage = NSImage(data: data)
    }
    
    private func pickArtwork() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.title = "Select Album Artwork"
        
        guard panel.runModal() == .OK, let url = panel.url else { return }
        
        guard let image = NSImage(contentsOf: url) else { return }
        artworkImage = image
        
        // Convert to JPEG data for embedding
        if let tiffData = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiffData),
           let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
            editedTrack.artworkData = jpegData
        }
    }
}
