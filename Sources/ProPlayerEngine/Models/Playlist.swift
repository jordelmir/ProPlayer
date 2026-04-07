import Foundation

public struct Playlist: Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var items: [MediaItem]
    public var currentIndex: Int = 0
    
    public init(id: UUID = UUID(), name: String, items: [MediaItem] = [], currentIndex: Int = 0) {
        self.id = id
        self.name = name
        self.items = items
        self.currentIndex = currentIndex
    }
    
    public mutating func next() -> MediaItem? {
        guard !items.isEmpty else { return nil }
        currentIndex = (currentIndex + 1) % items.count
        return items[currentIndex]
    }
    
    public mutating func previous() -> MediaItem? {
        guard !items.isEmpty else { return nil }
        currentIndex = (currentIndex - 1 + items.count) % items.count
        return items[currentIndex]
    }
    
    public var totalDuration: Double {
        return items.reduce(0.0) { $0 + $1.duration }
    }
}
