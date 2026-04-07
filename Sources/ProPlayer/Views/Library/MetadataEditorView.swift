import SwiftUI
import AppKit

struct MetadataEditorView: View {
    @Binding var metadata: MusicMetadata
    let onSave: (MusicMetadata) -> Void
    let onCancel: () -> Void
    
    @State private var editedMetadata: MusicMetadata
    @State private var isSaving = false
    
    init(metadata: Binding<MusicMetadata>, onSave: @escaping (MusicMetadata) -> Void, onCancel: @escaping () -> Void) {
        _metadata = metadata
        _editedMetadata = State(initialValue: metadata.wrappedValue)
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("EDIT METADATA")
                    .font(ProTheme.Fonts.headline)
                    .tracking(2)
                    .foregroundColor(ProTheme.Colors.accentPurple)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(ProTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(ProTheme.Spacing.xl)
            .background(Color.black.opacity(0.3))
            
            ScrollView {
                VStack(spacing: ProTheme.Spacing.xl) {
                    // Artwork Section
                    VStack(spacing: ProTheme.Spacing.md) {
                        artworkView
                        
                        Button("Change Artwork") {
                            selectNewArtwork()
                        }
                        .buttonStyle(.plain)
                        .font(ProTheme.Fonts.caption)
                        .foregroundColor(ProTheme.Colors.accentBlue)
                    }
                    .padding(.top, ProTheme.Spacing.lg)
                    
                    // Fields
                    VStack(spacing: ProTheme.Spacing.lg) {
                        ProInputField(label: "TITLE", text: $editedMetadata.title)
                        ProInputField(label: "ARTIST", text: $editedMetadata.artist)
                        ProInputField(label: "ALBUM", text: $editedMetadata.album)
                        
                        HStack(spacing: ProTheme.Spacing.lg) {
                            ProInputField(label: "YEAR", text: $editedMetadata.year)
                            ProInputField(label: "TRACK", text: $editedMetadata.trackNumber)
                        }
                        
                        ProInputField(label: "GENRE", text: $editedMetadata.genre)
                    }
                    .padding(.horizontal, ProTheme.Spacing.xl)
                }
                .padding(.bottom, ProTheme.Spacing.xxl)
            }
            
            // Footer
            HStack(spacing: ProTheme.Spacing.lg) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(ProButtonStyle(variant: .secondary))
                
                Button("Save metadata") {
                    save()
                }
                .buttonStyle(ProButtonStyle(variant: .primary))
                .disabled(isSaving)
            }
            .padding(ProTheme.Spacing.xl)
            .background(Color.black.opacity(0.3))
        }
        .frame(width: 400)
        .background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 0.5),
            alignment: .leading
        )
    }
    
    private var artworkView: some View {
        ZStack {
            if let data = editedMetadata.artworkData, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    ProTheme.Colors.surfaceDark
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(ProTheme.Colors.textTertiary)
                }
            }
        }
        .frame(width: 180, height: 180)
        .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.large))
        .shadow(color: .black.opacity(0.5), radius: 10)
    }
    
    private func selectNewArtwork() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .jpeg, .png]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.title = "Select Artwork"
        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url) {
                editedMetadata.artworkData = data
            }
        }
    }
    
    private func save() {
        isSaving = true
        onSave(editedMetadata)
    }
}

// Pro UI Helpers
struct ProInputField: View {
    let label: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ProTheme.Spacing.xs) {
            Text(label)
                .font(ProTheme.Fonts.caption)
                .tracking(1)
                .foregroundColor(ProTheme.Colors.textTertiary)
            
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .padding(ProTheme.Spacing.sm)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: ProTheme.Radius.small)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                .font(ProTheme.Fonts.body)
                .foregroundColor(.white)
        }
    }
}

struct ProButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary }
    let variant: Variant
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ProTheme.Fonts.headline)
            .padding(.horizontal, ProTheme.Spacing.lg)
            .padding(.vertical, ProTheme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                variant == .primary
                    ? ProTheme.Colors.accentGradient
                    : LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.medium))
            .foregroundColor(.white)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(color: variant == .primary ? ProTheme.Colors.accentBlue.opacity(0.3) : .clear, radius: 8)
    }
}
