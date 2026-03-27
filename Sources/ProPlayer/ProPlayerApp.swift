import SwiftUI
import UniformTypeIdentifiers

@main
struct ProPlayerApp: App {

    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 900, minHeight: 550)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 750)
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("Open File...") {
                    openFile()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Open URL...") {
                    // Placeholder for URL input
                }
                .keyboardShortcut("u", modifiers: .command)
            }

            // Playback menu
            CommandMenu("Playback") {
                Button("Play / Pause") {
                    NotificationCenter.default.post(name: .proPlayerTogglePlayPause, object: nil)
                }
                .keyboardShortcut(.space, modifiers: [])

                Divider()

                Button("Seek Forward 5s") {
                    NotificationCenter.default.post(name: .proPlayerSeekForward, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])

                Button("Seek Backward 5s") {
                    NotificationCenter.default.post(name: .proPlayerSeekBackward, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button("Seek Forward 30s") {
                    NotificationCenter.default.post(name: .proPlayerSeekForward, object: 30)
                }
                .keyboardShortcut(.rightArrow, modifiers: .shift)

                Button("Seek Backward 30s") {
                    NotificationCenter.default.post(name: .proPlayerSeekBackward, object: 30)
                }
                .keyboardShortcut(.leftArrow, modifiers: .shift)

                Divider()

                Button("Speed Up") {
                    NotificationCenter.default.post(name: .proPlayerSpeedUp, object: nil)
                }
                .keyboardShortcut("]", modifiers: [])

                Button("Speed Down") {
                    NotificationCenter.default.post(name: .proPlayerSpeedDown, object: nil)
                }
                .keyboardShortcut("[", modifiers: [])
            }

            // Video menu
            CommandMenu("Video") {
                Button("Cycle Screen Mode") {
                    NotificationCenter.default.post(name: .proPlayerCycleGravity, object: nil)
                }
                .keyboardShortcut("a", modifiers: [])

                Divider()

                Button("Screenshot") {
                    NotificationCenter.default.post(name: .proPlayerScreenshot, object: nil)
                }
                .keyboardShortcut("s", modifiers: [])

                Button("Video Info") {
                    NotificationCenter.default.post(name: .proPlayerToggleInfo, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)
            }

            // Audio menu
            CommandMenu("Audio") {
                Button("Volume Up") {
                    NotificationCenter.default.post(name: .proPlayerVolumeUp, object: nil)
                }
                .keyboardShortcut(.upArrow, modifiers: [])

                Button("Volume Down") {
                    NotificationCenter.default.post(name: .proPlayerVolumeDown, object: nil)
                }
                .keyboardShortcut(.downArrow, modifiers: [])

                Button("Mute / Unmute") {
                    NotificationCenter.default.post(name: .proPlayerToggleMute, object: nil)
                }
                .keyboardShortcut("m", modifiers: [])
            }
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType.movie, UTType.video, UTType.mpeg4Movie,
            UTType.quickTimeMovie, UTType.avi
        ]
        panel.title = "Open Video"
        panel.runModal()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let proPlayerTogglePlayPause = Notification.Name("proPlayerTogglePlayPause")
    static let proPlayerSeekForward = Notification.Name("proPlayerSeekForward")
    static let proPlayerSeekBackward = Notification.Name("proPlayerSeekBackward")
    static let proPlayerSpeedUp = Notification.Name("proPlayerSpeedUp")
    static let proPlayerSpeedDown = Notification.Name("proPlayerSpeedDown")
    static let proPlayerCycleGravity = Notification.Name("proPlayerCycleGravity")
    static let proPlayerScreenshot = Notification.Name("proPlayerScreenshot")
    static let proPlayerToggleInfo = Notification.Name("proPlayerToggleInfo")
    static let proPlayerVolumeUp = Notification.Name("proPlayerVolumeUp")
    static let proPlayerVolumeDown = Notification.Name("proPlayerVolumeDown")
    static let proPlayerToggleMute = Notification.Name("proPlayerToggleMute")
}
