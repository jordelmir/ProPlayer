import Foundation

public struct MusicBrainzResult: Codable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let year: String
    public let trackNumber: String
    public let genre: String? // MusicBrainz doesn't reliably do genres, but we can try
    public let coverURL: URL?
    public let musicbrainzRecordingID: String?
}

/// Service for fingerprinting audio and retrieving metadata via AcoustID + MusicBrainz
@MainActor
public final class MusicBrainzService: Sendable {
    public static let shared = MusicBrainzService()
    
    // The user's provided AcoustID API key
    private let acoustIDKey = "iKSrstZCq7"
    
    private let urlSession: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        // MusicBrainz strictly requires a descriptive User-Agent
        config.httpAdditionalHeaders = [
            "User-Agent": "ElysiumVanguard/16.0 ( https://github.com/jordelmir/ElysiumVanguard8K )"
        ]
        self.urlSession = URLSession(configuration: config)
    }
    
    /// Looks up a track's metadata using acoustic fingerprinting or filename heuristics.
    public func lookupTrack(_ track: MusicTrack) async throws -> MusicBrainzResult {
        // Step 1: Attempt to generate AcoustID fingerprint
        // Since we don't have the fpcalc binary bundled, we'll try to extract what we can from the URL first,
        // and simulate the AcoustID lookup for the PoC unless fpcalc is provided.
        // In a real release, we'd bundle ChromePrint/fpcalc.
        
        let fingerprint = await generatePseudoFingerprint(for: track)
        
        // Step 2: Query AcoustID (using the real API key provided by user)
        let acoustIDURL = URL(string: "https://api.acoustid.org/v2/lookup?client=\(acoustIDKey)&meta=recordings+releases+usermeta&duration=\(Int(track.duration))&fingerprint=\(fingerprint)")!
        
        do {
            let (data, response) = try await urlSession.data(from: acoustIDURL)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                // Try to parse AcoustID response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let firstResult = results.first,
                   let recordings = firstResult["recordings"] as? [[String: Any]],
                   let firstRecording = recordings.first {
                    
                    let title = firstRecording["title"] as? String ?? track.title
                    let artistArray = firstRecording["artists"] as? [[String: Any]]
                    let artist = artistArray?.first?["name"] as? String ?? track.artist
                    
                    var album = track.album
                    var mbid: String? = firstRecording["id"] as? String
                    
                    if let releases = firstRecording["releases"] as? [[String: Any]],
                       let firstRelease = releases.first {
                        album = firstRelease["title"] as? String ?? album
                        // Get cover art URL from CoverArtArchive if we have a release MBID
                        var coverURL: URL? = nil
                        if let releaseMBID = firstRelease["id"] as? String {
                            coverURL = URL(string: "https://coverartarchive.org/release/\(releaseMBID)/front")
                        }
                        
                        return MusicBrainzResult(
                            title: title,
                            artist: artist,
                            album: album,
                            year: track.year, // Usually need secondary MB query for year
                            trackNumber: track.trackNumber,
                            genre: nil,
                            coverURL: coverURL,
                            musicbrainzRecordingID: mbid
                        )
                    }
                }
            }
        } catch {
            print("MusicBrainzService: AcoustID lookup failed, falling back to heuristics. \(error)")
        }
        
        // Step 3: Fallback heuristic (parse filename: "Artist - Title.mp3")
        return fallbackLookup(track)
    }
    
    // In a full production C/C++ engine, this would wrap chromaprint.
    // For this version, if we can't run `fpcalc`, we return a dummy string to test the API flow.
    private func generatePseudoFingerprint(for track: MusicTrack) async -> String {
        return "simulate_fingerprint_for_now"
    }
    
    private func fallbackLookup(_ track: MusicTrack) -> MusicBrainzResult {
        let filename = track.url.deletingPathExtension().lastPathComponent
        let components = filename.components(separatedBy: " - ")
        
        var parsedArtist = track.artist
        var parsedTitle = track.title
        
        if components.count >= 2 {
            parsedArtist = components[0].trimmingCharacters(in: .whitespaces)
            parsedTitle = components[1...].joined(separator: " - ").trimmingCharacters(in: .whitespaces)
        }
        
        return MusicBrainzResult(
            title: parsedTitle != "Unknown Title" ? parsedTitle : track.title,
            artist: parsedArtist != "Unknown Artist" ? parsedArtist : track.artist,
            album: track.album,
            year: track.year,
            trackNumber: track.trackNumber,
            genre: nil,
            coverURL: nil,
            musicbrainzRecordingID: nil
        )
    }
}
