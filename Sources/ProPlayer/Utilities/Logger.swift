import Foundation
import os.log

/// ProLogger: Unified observability system for ProPlayer Elite 2026.
/// Standardizes on Apple's OSLog for high-performance, persistent logging.
enum ProLogger {
    
    // MARK: - Subsystems
    
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.jordelmir.ElysiumVanguardProPlayer8K"
    
    static let engine = OSLog(subsystem: subsystem, category: "Engine")
    static let ui = OSLog(subsystem: subsystem, category: "UI")
    static let metal = OSLog(subsystem: subsystem, category: "Metal")
    static let networking = OSLog(subsystem: subsystem, category: "Networking")
    
    // MARK: - Logging Functions
    
    /// Log a message with a specific type and category.
    static func log(_ message: String, type: OSLogType = .default, category: OSLog = .default) {
        #if DEBUG
        let typeString: String
        switch type {
        case .debug: typeString = "🔍 DEBUG"
        case .info: typeString = "ℹ️ INFO"
        case .error: typeString = "🚨 ERROR"
        case .fault: typeString = "☣️ FAULT"
        default: typeString = "📝 DEFAULT"
        }
        print("[\(typeString)] \(message)")
        #endif
        
        os_log("%{public}@", log: category, type: type, message)
    }
    
    // MARK: - Specialized Helpers
    
    static func engineInfo(_ message: String) {
        log(message, type: .info, category: engine)
    }
    
    static func engineError(_ message: String) {
        log(message, type: .error, category: engine)
    }
    
    static func uiAction(_ message: String) {
        log(message, type: .info, category: ui)
    }
    
    static func metalTrace(_ message: String) {
        log(message, type: .debug, category: metal)
    }
}
