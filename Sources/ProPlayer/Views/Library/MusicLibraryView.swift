import SwiftUI

struct MusicLibraryView: View {
    @StateObject private var viewModel = MusicLibraryViewModel()
    @State private var showingEditor = false
    @State private var editingItem: MusicMetadata?
    
    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 260), spacing: ProTheme.Spacing.xl)
    ]
    
    var body: some View {
        ZStack {
            // Background Layer
            ProTheme.Colors.deepBlack.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: ProTheme.Spacing.lg) {
                    Label("\(viewModel.items.count) Audio Tracks", systemImage: "music.note.list")
                        .font(ProTheme.Fonts.headline)
                        .foregroundColor(ProTheme.Colors.textSecondary)
                    
                    Spacer()
                    
                    Button {
                        selectFolder()
                    } label: {
                        Label("Add Folder", systemImage: "folder.badge.plus")
                            .font(ProTheme.Fonts.controlLabel)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(ProTheme.Colors.surfaceMedium)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    if viewModel.isScanning {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(ProTheme.Colors.accentPurple)
                    }
                }
                .padding(.horizontal, ProTheme.Spacing.xxl)
                .padding(.vertical, ProTheme.Spacing.xl)
                .background(Color.black.opacity(0.2))
                
                // Content
                if viewModel.items.isEmpty && !viewModel.isScanning {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: ProTheme.Spacing.xxl) {
                            ForEach(viewModel.items) { item in
                                MusicGridItem(item: item, onEdit: {
                                    editingItem = item
                                    showingEditor = true
                                })
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
                            }
                        }
                        .padding(ProTheme.Spacing.xxl)
                    }
                }
            }
            
            // Side Editor Panel
            if showingEditor, let item = Binding($editingItem) {
                HStack(spacing: 0) {
                    Spacer()
                    MetadataEditorView(
                        metadata: item,
                        onSave: { updated in
                            viewModel.saveMetadata(updated)
                            withAnimation(ProTheme.Animations.interactive) {
                                showingEditor = false
                            }
                        },
                        onCancel: {
                            withAnimation(ProTheme.Animations.interactive) {
                                showingEditor = false
                            }
                        }
                    )
                    .transition(.move(edge: .trailing))
                }
                .background(Color.black.opacity(0.4).onTapGesture {
                    withAnimation(ProTheme.Animations.interactive) {
                        showingEditor = false
                    }
                })
                .zIndex(100)
            }
        }
        .animation(ProTheme.Animations.standard, value: viewModel.items.count)
        .animation(ProTheme.Animations.interactive, value: showingEditor)
    }
    
    private var emptyState: some View {
        VStack(spacing: ProTheme.Spacing.xl) {
            Image(systemName: "music.quarternote.3")
                .font(.system(size: 80, weight: .thin))
                .foregroundColor(ProTheme.Colors.accentPurple.opacity(0.3))
                .shadow(color: ProTheme.Colors.accentPurple.opacity(0.2), radius: 20)
            
            Text("NO AUDIO TRACKS FOUND")
                .font(ProTheme.Fonts.displayMedium)
                .tracking(4)
                .foregroundColor(ProTheme.Colors.textSecondary)
            
            Text("Select a folder to start managing your music collection with elite metadata tools.")
                .font(ProTheme.Fonts.body)
                .foregroundColor(ProTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            Button("CHOOSE FOLDER") {
                selectFolder()
            }
            .buttonStyle(ProButtonStyle(variant: .primary))
            .frame(width: 220)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Select Music Library"
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.scanFolder(url)
        }
    }
}
