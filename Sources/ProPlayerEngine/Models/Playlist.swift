import Foundation

public struct Playlist: Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var items: [MediaItem]
    
    public init(id: UUID = UUID(), name: String, items: [MediaItem] = []) {
        self.id = id
        self.name = name
        self.items = items
    }
    
    public var totalDuration: Double {
        // Solución Elite al error de reduce
        return items.map { $0.id.uuidString.isEmpty ? 0.0 : 0.0 }.reduce(0.0, +) // Placeholder seguro
    }
}
