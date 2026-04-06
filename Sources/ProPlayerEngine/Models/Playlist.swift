import Foundation

public struct Playlist: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var items: [VideoItem]
    public var currentIndex: Int
    public var repeatMode: RepeatMode
    public var shuffleEnabled: Bool
    public var dateCreated: Date
    public var dateModified: Date

    public enum RepeatMode: String, Codable, CaseIterable {
        case off = "Off"
        case one = "Repeat One"
        case all = "Repeat All"

        public var icon: String {
            switch self {
            case .off: return "repeat"
            case .one: return "repeat.1"
            case .all: return "repeat"
            }
        }
    }

    public init(
        id: UUID = UUID(),
        name: String = "Untitled Playlist",
        items: [VideoItem] = [],
        currentIndex: Int = 0,
        repeatMode: RepeatMode = .off,
        shuffleEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.items = items
        self.currentIndex = currentIndex
        self.repeatMode = repeatMode
        self.shuffleEnabled = shuffleEnabled
        self.dateCreated = Date()
        self.dateModified = Date()
    }

    public var currentItem: VideoItem? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    public var hasNext: Bool {
        currentIndex < items.count - 1 || repeatMode == .all
    }

    public var hasPrevious: Bool {
        currentIndex > 0 || repeatMode == .all
    }

    public var totalDuration: Double {
        items.reduce(0.0) { $0 + $1.duration }
    }

    public mutating func next() -> VideoItem? {
        if shuffleEnabled {
            guard items.count > 1 else { return items.first }
            var newIndex = currentIndex
            while newIndex == currentIndex {
                newIndex = Int.random(in: 0..<items.count)
            }
            currentIndex = newIndex
        } else if currentIndex < items.count - 1 {
            currentIndex += 1
        } else if repeatMode == .all {
            currentIndex = 0
        } else {
            return nil
        }
        return currentItem
    }

    public mutating func previous() -> VideoItem? {
        if currentIndex > 0 {
            currentIndex -= 1
        } else if repeatMode == .all {
            currentIndex = max(0, items.count - 1)
        } else {
            return nil
        }
        return currentItem
    }

    public mutating func addItem(_ item: VideoItem) {
        items.append(item)
        dateModified = Date()
    }

    public mutating func removeItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        if currentIndex >= items.count {
            currentIndex = max(0, items.count - 1)
        }
        dateModified = Date()
    }

    public mutating func moveItem(from source: IndexSet, to destination: Int) {
        // Manual move (Foundation-compatible, no SwiftUI dependency)
        let moving = source.map { items[$0] }
        let remaining = items.enumerated().filter { !source.contains($0.offset) }.map { $0.element }
        
        var result = remaining
        let insertAt = min(destination, result.count)
        result.insert(contentsOf: moving, at: insertAt)
        
        items = result
        dateModified = Date()
    }
}
