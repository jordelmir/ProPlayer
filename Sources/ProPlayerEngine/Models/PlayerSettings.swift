import Foundation
import AVFoundation

// MARK: - Video Gravity Mode

public enum VideoGravityMode: String, Codable, CaseIterable, Identifiable {
    case fit = "Fit"
    case fill = "Fill"
    case stretch = "Stretch"
    case customZoom = "Custom Zoom"
    case ambient = "Ambient Mode"
    case smartFill = "Smart Fill (Max)"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .fit: return "rectangle.arrowtriangle.2.inward"
        case .fill: return "rectangle.arrowtriangle.2.outward"
        case .stretch: return "arrow.up.left.and.arrow.down.right"
        case .smartFill: return "sparkles.rectangle.stack"
        case .ambient: return "sparkles"
        case .customZoom: return "plus.magnifyingglass"
        }
    }

    public var description: String {
        switch self {
        case .fit: return "Letterboxed — no cropping"
        case .fill: return "Fills screen — crops edges"
        case .stretch: return "Stretches to fill — no black bars"
        case .smartFill: return "Fills with minimal distortion"
        case .ambient: return "Dynamic background blur"
        case .customZoom: return "Manual zoom and pan"
        }
    }

    public var avGravity: AVLayerVideoGravity {
        switch self {
        case .fit: return .resizeAspect
        case .fill: return .resizeAspectFill
        case .stretch: return .resize
        case .ambient, .smartFill: return .resizeAspect // Handled by custom Metal pipeline
        case .customZoom: return .resizeAspect
        }
    }
}

// MARK: - Sort Option

public enum LibrarySortOption: String, Codable, CaseIterable, Identifiable {
    case dateAdded = "Date Added"
    case dateAddedOldest = "Date Added (Oldest)"
    case name = "Name"
    case duration = "Duration"
    case fileSize = "File Size"
    case lastPlayed = "Last Played"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .dateAdded: return "calendar.badge.clock"
        case .dateAddedOldest: return "calendar"
        case .name: return "textformat.abc"
        case .duration: return "timer"
        case .fileSize: return "doc"
        case .lastPlayed: return "play.circle"
        }
    }
}

// MARK: - Library View Mode

public enum LibraryViewMode: String, Codable, CaseIterable {
    case grid = "Grid"
    case list = "List"

    public var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

// MARK: - Rendering Tiers

public enum SuperResolutionTier: String, Codable, CaseIterable, Identifiable {
    case off = "Off"
    case upscale2k = "2K (1440p)"
    case upscale4k = "4K (2160p)"
    case ultraAI = "Ultra AI (Neural)"
    case ultra5K = "Ultra 5K (Edge Directed)"
    case extreme8K = "Extreme 8K (EASU)"
    case animeAdaptive = "Anime Adaptive"
    
    public var id: String { rawValue }
    
    public var scaleFactor: Float {
        switch self {
        case .off: return 1.0
        case .upscale2k: return 1.5
        case .upscale4k: return 2.0
        case .ultraAI: return 2.5
        case .ultra5K: return 3.0
        case .extreme8K: return 4.0
        case .animeAdaptive: return 1.8
        }
    }
    
    public var shortLabel: String {
        switch self {
        case .off: return "Off"
        case .upscale2k: return "2K"
        case .upscale4k: return "4K"
        case .ultraAI: return "ULTRA"
        case .ultra5K: return "5K"
        case .extreme8K: return "8K"
        case .animeAdaptive: return "ANIME"
        }
    }
    
    public var icon: String {
        switch self {
        case .off: return "sparkles.none"
        case .upscale2k: return "sparkles"
        case .upscale4k: return "sparkles.rectangle.stack"
        case .ultraAI: return "brain.head.profile"
        case .ultra5K: return "diamond.inset.filled"
        case .extreme8K: return "infinity.circle.fill"
        case .animeAdaptive: return "wand.and.stars"
        }
    }
    
    public var sharpnessWeight: Float {
        switch self {
        case .off: return 0.0
        case .upscale2k: return 0.10
        case .upscale4k: return 0.25
        case .ultraAI: return 0.45
        case .ultra5K: return 0.85
        case .extreme8K: return 1.5
        case .animeAdaptive: return 0.30
        }
    }
}

// MARK: - Player Settings

public struct PlayerSettings: Codable, Equatable {
    public var defaultGravityMode: VideoGravityMode = .stretch
    public var resumePlayback: Bool = true
    public var autoPlayNext: Bool = true
    public var screenshotSavePath: String = NSSearchPathForDirectoriesInDomains(.picturesDirectory, .userDomainMask, true).first ?? ""
    public var showOSD: Bool = true
    public var osdDuration: Double = 2.0
    public var controlsAutoHideDelay: Double = 5.0
    public var librarySortOption: LibrarySortOption = .dateAdded
    public var libraryViewMode: LibraryViewMode = .grid
    
    // Elite Rendering
    public var renderingTier: SuperResolutionTier = .upscale4k
    public var ambientIntensity: Double = 0.4
    
    // Pro-Grade Enhancements (v13.0)
    public var colorTemperature: Float = 6500.0 // Kelvin
    public var filmGrainIntensity: Float = 0.0 // Off by default
    public var enableToneMapping: Bool = false // ACES Filmic HDR
    public var enableTNR: Bool = false // Temporal Noise Reduction
    

    // Subtitle defaults
    public var subtitleFontSize: Double = 24
    public var subtitleColor: String = "white"
    public var subtitleBackgroundOpacity: Double = 0.6

    // Audio defaults
    public var defaultVolume: Float = 0.8
    
    public init() {}

    public static func load() -> PlayerSettings {
        guard let data = UserDefaults.standard.data(forKey: "ProPlayerSettings"),
              let settings = try? JSONDecoder().decode(PlayerSettings.self, from: data) else {
            return PlayerSettings()
        }
        return settings
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "ProPlayerSettings")
        }
    }
}
