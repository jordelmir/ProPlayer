import Foundation

public struct LyricsResult: Sendable {
    public let plainLyrics: String?
    public let syncedLyrics: String? // LRC format
    public let provider: String
}

/// Service for fetching lyrics via the free LRCLIB API.
@MainActor
public final class LyricsService: Sendable {
    public static let shared = LyricsService()
    
    private let urlSession: URLSession
    private let cacheDirectory: URL
    
    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "ElysiumVanguard/16.0 ( https://github.com/jordelmir/ElysiumVanguard8K )"
        ]
        self.urlSession = URLSession(configuration: config)
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.cacheDirectory = appSupport.appendingPathComponent("ElysiumVanguardProPlayer8K/Lyrics", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    public func fetchLyrics(for track: MusicTrack) async throws -> LyricsResult? {
        // 1. Check local cache first
        let cacheFileName = "\(track.artist.prefix(20))-\(track.title.prefix(20))".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "unknown"
        let cachedURL = cacheDirectory.appendingPathComponent("\(cacheFileName).lrc")
        
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            if let cached = try? String(contentsOf: cachedURL, encoding: .utf8) {
                return LyricsResult(plainLyrics: nil, syncedLyrics: cached, provider: "Local Cache")
            }
        }
        
        // 2. Escape parameters for URL
        guard let artist = track.artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let title = track.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        // 3. Query LRCLIB
        let urlString = "https://lrclib.net/api/get?artist_name=\(artist)&track_name=\(title)"
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, response) = try await urlSession.data(from: url)
        
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            return nil
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let plain = json["plainLyrics"] as? String
            let synced = json["syncedLyrics"] as? String
            
            // Try to cache if we got synced results
            if let synced = synced, !synced.isEmpty {
                try? synced.write(to: cachedURL, atomically: true, encoding: .utf8)
            }
            
            return LyricsResult(
                plainLyrics: plain,
                syncedLyrics: synced,
                provider: "LRCLIB"
            )
        }
        
        return nil
    }
    
    /// Parses LRC formatted text into an array of (timeInSeconds, lineOfText)
    public static func parseLRC(_ lrcText: String) -> [(TimeInterval, String)] {
        var lines: [(TimeInterval, String)] = []
        let pattern = "\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})\\](.*)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        let targetStrings = lrcText.components(separatedBy: .newlines)
        
        for line in targetStrings {
            let nsString = line as NSString
            let results = regex.matches(in: line, range: NSRange(location: 0, length: nsString.length))
            
            for match in results {
                if match.numberOfRanges == 5 {
                    let minStr = nsString.substring(with: match.range(at: 1))
                    let secStr = nsString.substring(with: match.range(at: 2))
                    let msStr = nsString.substring(with: match.range(at: 3))
                    let text = nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
                    
                    if let mins = Double(minStr), let secs = Double(secStr), let ms = Double(msStr) {
                        let totalSeconds = (mins * 60) + secs + (ms / 100)
                        lines.append((totalSeconds, text))
                    }
                }
            }
        }
        
        return lines.sorted { $0.0 < $1.0 }
    }
}
