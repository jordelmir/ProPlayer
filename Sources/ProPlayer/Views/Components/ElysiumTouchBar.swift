import AppKit
import ProPlayerEngine

/// Implements NSTouchBar support for Elysium Vanguard on Intel MacBooks.
@MainActor
final class ElysiumTouchBarDelegate: NSObject, NSTouchBarDelegate {
    
    static let playPauseItem = NSTouchBarItem.Identifier("com.elysium.touchbar.playPause")
    static let scrubbingItem = NSTouchBarItem.Identifier("com.elysium.touchbar.scrubbing")
    static let volumeItem    = NSTouchBarItem.Identifier("com.elysium.touchbar.volume")
    
    // Shared bridge to current playback engine (Video or Music)
    private var isPlaying: Bool {
        // Simple bridge: checks if video or music is active (mock logic for delegate mapping)
        return MusicPlayerEngine.shared.isPlaying
    }
    
    func makeTouchBar() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [
            .flexibleSpace,
            ElysiumTouchBarDelegate.playPauseItem,
            .flexibleSpace,
            ElysiumTouchBarDelegate.volumeItem
        ]
        return touchBar
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        
        switch identifier {
        case ElysiumTouchBarDelegate.playPauseItem:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(image: NSImage(systemSymbolName: "playpause.fill", accessibilityDescription: nil) ?? NSImage(),
                                  target: self, action: #selector(togglePlayPause))
            item.view = button
            return item
            
        case ElysiumTouchBarDelegate.volumeItem:
            let item = NSSliderTouchBarItem(identifier: identifier)
            item.label = "Vol"
            item.slider.minValue = 0.0
            item.slider.maxValue = 1.0
            item.slider.doubleValue = 0.8
            item.target = self
            item.action = #selector(volumeChanged(_:))
            return item
            
        default:
            return nil
        }
    }
    
    @objc private func togglePlayPause() {
        NotificationCenter.default.post(name: Notification.Name("proPlayerTogglePlayPause"), object: nil)
        MusicPlayerEngine.shared.togglePlayPause()
    }
    
    @objc private func volumeChanged(_ sender: NSSliderTouchBarItem) {
        let val = sender.slider.doubleValue
        MusicPlayerEngine.shared.volume = val
        // The Video engine volume sync would exist here too
    }
}
