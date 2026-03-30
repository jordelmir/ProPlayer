import SwiftUI
import ProPlayerEngine

struct LibraryView: View {
    @ObservedObject var libraryVM: LibraryViewModel
    let onPlayVideo: (URL) -> Void

    @State private var selectedSidebarItem: SidebarItem = .allVideos

    enum SidebarItem: String, CaseIterable, Identifiable {
        case recent = "Recent"
        case allVideos = "All Videos"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .recent: return "clock.fill"
            case .allVideos: return "film.stack"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            mainContent
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedSidebarItem) {
            Section {
                HStack(spacing: 12) {
                    BreathingLogoView(size: 28, glowRadius: 8)
                    Text("ELYSIUM 8K")
                        .font(ProTheme.Fonts.headline)
                        .tracking(2)
                        .foregroundColor(Color(red: 0.1, green: 0.9, blue: 1.0))
                }
                .padding(.vertical, 6)
            }

            Section("Library") {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                }
            }

            Section("Quick Actions") {
                Button {
                    if let urls = libraryVM.showOpenFileDialog() {
                        libraryVM.addVideoFiles(urls)
                    }
                } label: {
                    Label("Add Files", systemImage: "plus.circle")
                }
                .buttonStyle(.plain)

                Button {
                    if let url = libraryVM.showOpenFolderDialog() {
                        libraryVM.addFolder(url)
                    }
                } label: {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar
                .padding(.horizontal, ProTheme.Spacing.xl)
                .padding(.vertical, ProTheme.Spacing.md)

            Divider()

            // Content
            if displayedVideos.isEmpty {
                emptyState
            } else {
                contentView
            }
        }
        .background(
            ZStack {
                MatrixRainView()
                Color.black.opacity(0.7)
            }
        )
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: ProTheme.Spacing.md) {
            // Title
            Text(selectedSidebarItem.rawValue)
                .font(ProTheme.Fonts.displayMedium)
                .foregroundColor(ProTheme.Colors.textPrimary)

            Text("\(displayedVideos.count) videos")
                .font(ProTheme.Fonts.caption)
                .foregroundColor(ProTheme.Colors.textTertiary)

            Spacer()

            // Search
            HStack(spacing: ProTheme.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ProTheme.Colors.textTertiary)
                TextField("Search videos...", text: $libraryVM.searchText)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 400)
                if !libraryVM.searchText.isEmpty {
                    Button { libraryVM.searchText = "" } label: {
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

            // Sort menu
            Menu {
                ForEach(LibrarySortOption.allCases) { option in
                    Button {
                        libraryVM.sortOption = option
                    } label: {
                        HStack {
                            Label(option.rawValue, systemImage: option.icon)
                            if libraryVM.sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: ProTheme.Spacing.xs) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(libraryVM.sortOption.rawValue)
                        .font(ProTheme.Fonts.controlLabel)
                }
                .foregroundColor(ProTheme.Colors.textSecondary)
                .padding(.horizontal, ProTheme.Spacing.sm)
                .padding(.vertical, ProTheme.Spacing.xs)
                .background(ProTheme.Colors.surfaceMedium)
                .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.small))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // View mode toggle
            HStack(spacing: 0) {
                ForEach(LibraryViewMode.allCases, id: \.rawValue) { mode in
                    Button {
                        withAnimation(ProTheme.Animations.standard) {
                            libraryVM.viewMode = mode
                        }
                    } label: {
                        Image(systemName: mode.icon)
                            .font(.system(size: 14))
                            .foregroundColor(libraryVM.viewMode == mode ? ProTheme.Colors.accentBlue : ProTheme.Colors.textTertiary)
                            .frame(width: 30, height: 24)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(ProTheme.Colors.surfaceMedium)
            .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.small))
        }
    }

    // MARK: - Content Views

    @ViewBuilder
    private var contentView: some View {
        if libraryVM.isScanning {
            VStack(spacing: ProTheme.Spacing.md) {
                ProgressView()
                    .tint(ProTheme.Colors.accentBlue)
                Text("Scanning videos...")
                    .font(ProTheme.Fonts.body)
                    .foregroundColor(ProTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch libraryVM.viewMode {
            case .grid:
                gridView
            case .list:
                listView
            }
        }
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 240, maximum: 320), spacing: ProTheme.Spacing.lg)],
                spacing: ProTheme.Spacing.xl
            ) {
                ForEach(Array(displayedVideos.enumerated()), id: \.element.id) { index, video in
                    VideoGridItem(
                        item: video,
                        onPlay: { onPlayVideo(video.url) },
                        onRemove: { libraryVM.removeVideo(video) }
                    )
                    .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
                    .animation(ProTheme.Animations.spring.delay(Double(index) * 0.04), value: displayedVideos.count)
                }
            }
            .padding(ProTheme.Spacing.xl)
        }
    }

    private var listView: some View {
        List {
            ForEach(Array(displayedVideos.enumerated()), id: \.element.id) { index, video in
                HStack(spacing: ProTheme.Spacing.md) {
                    // Mini thumbnail
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ProTheme.Colors.surfaceDark)
                            .frame(width: 80, height: 45)
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(ProTheme.Colors.textTertiary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(video.title)
                            .font(ProTheme.Fonts.subheadline)
                            .foregroundColor(ProTheme.Colors.textPrimary)
                            .lineLimit(1)
                        Text("\(video.resolutionLabel) • \(video.codecLabel)")
                            .font(ProTheme.Fonts.caption)
                            .foregroundColor(ProTheme.Colors.textTertiary)
                    }

                    Spacer()

                    Text(video.durationLabel)
                        .font(ProTheme.Fonts.mono)
                        .foregroundColor(ProTheme.Colors.textSecondary)

                    Text(video.fileSizeLabel)
                        .font(ProTheme.Fonts.caption)
                        .foregroundColor(ProTheme.Colors.textTertiary)
                        .frame(width: 70, alignment: .trailing)

                    Text(FormatUtils.relativeDateString(from: video.dateAdded))
                        .font(ProTheme.Fonts.caption)
                        .foregroundColor(ProTheme.Colors.textTertiary)
                        .frame(width: 80, alignment: .trailing)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onPlayVideo(video.url)
                }
                .contextMenu {
                    Button("Play") { onPlayVideo(video.url) }
                    Button("Remove") { libraryVM.removeVideo(video) }
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
                .animation(ProTheme.Animations.smooth.delay(Double(index) * 0.03), value: displayedVideos.count)
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ZStack {
            MatrixRainView()
                .opacity(0.12)
                .ignoresSafeArea()

            VStack(spacing: ProTheme.Spacing.xxl) {
                Spacer()

                BreathingLogoView(size: 140, glowRadius: 35)
                    .padding(.bottom, ProTheme.Spacing.lg)

                Text("Your Library is Empty")
                    .font(ProTheme.Fonts.displayMedium)
                    .foregroundColor(ProTheme.Colors.textPrimary)
                    .shadow(color: ProTheme.Colors.accentBlue.opacity(0.3), radius: 10)

                Text("Add videos to get started. You can drag & drop files,\nor use the buttons below.")
                    .font(ProTheme.Fonts.body)
                    .foregroundColor(ProTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: ProTheme.Spacing.lg) {
                    Button {
                        if let urls = libraryVM.showOpenFileDialog() {
                            libraryVM.addVideoFiles(urls)
                        }
                    } label: {
                        Label("Add Files", systemImage: "plus.circle.fill")
                            .font(ProTheme.Fonts.subheadline)
                            .padding(.horizontal, ProTheme.Spacing.xl)
                            .padding(.vertical, ProTheme.Spacing.md)
                            .background(ProTheme.Colors.accentBlue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.medium))
                            .shadow(color: ProTheme.Colors.accentBlue.opacity(0.5), radius: 10)
                    }
                    .buttonStyle(.plain)

                    Button {
                        if let url = libraryVM.showOpenFolderDialog() {
                            libraryVM.addFolder(url)
                        }
                    } label: {
                        Label("Add Folder", systemImage: "folder.badge.plus")
                            .font(ProTheme.Fonts.subheadline)
                            .padding(.horizontal, ProTheme.Spacing.xl)
                            .padding(.vertical, ProTheme.Spacing.md)
                            .background(ProTheme.Colors.surfaceMedium)
                            .foregroundColor(ProTheme.Colors.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: ProTheme.Radius.medium))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var displayedVideos: [VideoItem] {
        switch selectedSidebarItem {
        case .recent:
            return libraryVM.recentFiles
        case .allVideos:
            return libraryVM.filteredVideos
        }
    }
}
