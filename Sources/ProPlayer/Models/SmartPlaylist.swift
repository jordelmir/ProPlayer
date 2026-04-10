import Foundation

public enum SmartPlaylistField: String, Codable, CaseIterable {
    case any = "Any Field"
    case artist = "Artist"
    case album = "Album"
    case genre = "Genre"
    case year = "Year"
    case title = "Title"
    case duration = "Duration"
    case dateAdded = "Date Added"
}

public enum SmartPlaylistOperator: String, Codable, CaseIterable {
    case contains = "Contains"
    case equals = "Equals"
    case notEquals = "Does Not Equal"
    case startsWith = "Starts With"
    case endsWith = "Ends With"
    case greaterThan = "Is Greater Than"
    case lessThan = "Is Less Than"
    case isEmpty = "Is Empty"
    case isNotEmpty = "Is Not Empty"
}

public struct SmartPlaylistRule: Codable, Identifiable {
    public let id: UUID
    public var field: SmartPlaylistField
    public var `operator`: SmartPlaylistOperator
    public var value: String
    
    public init(id: UUID = UUID(), field: SmartPlaylistField, operator: SmartPlaylistOperator, value: String) {
        self.id = id
        self.field = field
        self.operator = `operator`
        self.value = value
    }
    
    public func matches(_ track: MusicTrack) -> Bool {
        if self.operator == .isEmpty {
            return getFieldValue(from: track).isEmpty
        }
        if self.operator == .isNotEmpty {
            return !getFieldValue(from: track).isEmpty
        }
        
        let trackValue = getFieldValue(from: track).lowercased()
        let checkValue = value.lowercased()
        
        switch self.operator {
        case .contains: return trackValue.contains(checkValue)
        case .equals: return trackValue == checkValue
        case .notEquals: return trackValue != checkValue
        case .startsWith: return trackValue.hasPrefix(checkValue)
        case .endsWith: return trackValue.hasSuffix(checkValue)
        case .greaterThan:
            if field == .duration, let tv = Double(trackValue), let cv = Double(checkValue) { return tv > cv }
            if field == .year, let tv = Int(trackValue), let cv = Int(checkValue) { return tv > cv }
            return trackValue > checkValue
        case .lessThan:
            if field == .duration, let tv = Double(trackValue), let cv = Double(checkValue) { return tv < cv }
            if field == .year, let tv = Int(trackValue), let cv = Int(checkValue) { return tv < cv }
            return trackValue < checkValue
        case .isEmpty, .isNotEmpty: return false // Handled above
        }
    }
    
    private func getFieldValue(from track: MusicTrack) -> String {
        switch field {
        case .any: return [track.title, track.artist, track.album, track.genre, track.year].joined(separator: " ")
        case .artist: return track.artist
        case .album: return track.album
        case .genre: return track.genre
        case .year: return track.year
        case .title: return track.title
        case .duration: return String(track.duration)
        case .dateAdded: return track.dateAdded.timeIntervalSince1970.description
        }
    }
}

public struct SmartPlaylist: Codable, Identifiable {
    public let id: UUID
    public var title: String
    public var rules: [SmartPlaylistRule]
    public var matchAllRules: Bool
    
    public init(id: UUID = UUID(), title: String, rules: [SmartPlaylistRule], matchAllRules: Bool = true) {
        self.id = id
        self.title = title
        self.rules = rules
        self.matchAllRules = matchAllRules
    }
    
    public func filter(_ tracks: [MusicTrack]) -> [MusicTrack] {
        return tracks.filter { track in
            if rules.isEmpty { return true }
            
            if matchAllRules {
                return rules.allSatisfy { $0.matches(track) }
            } else {
                return rules.contains { $0.matches(track) }
            }
        }
    }
    
    // MARK: - Presets
    
    public static var presets: [SmartPlaylist] {
        [
            SmartPlaylist(
                title: "80s Hits",
                rules: [
                    SmartPlaylistRule(field: .year, operator: .greaterThan, value: "1979"),
                    SmartPlaylistRule(field: .year, operator: .lessThan, value: "1990")
                ],
                matchAllRules: true
            ),
            SmartPlaylist(
                title: "Untagged Tracks",
                rules: [
                    SmartPlaylistRule(field: .artist, operator: .contains, value: "Unknown"),
                    SmartPlaylistRule(field: .album, operator: .contains, value: "Unknown")
                ],
                matchAllRules: false
            ),
            SmartPlaylist(
                title: "Long Tracks",
                rules: [
                    SmartPlaylistRule(field: .duration, operator: .greaterThan, value: "360") // > 6 mins
                ]
            )
        ]
    }
}
