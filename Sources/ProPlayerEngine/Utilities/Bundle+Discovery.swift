import Foundation

private class BundleFinder {}

extension Bundle {
    /// A robust replacement for Bundle.module that won't crash if the bundle
    /// is moved or the binary is renamed.
    public static var proPlayerEngine: Bundle {
        let bundleName = "ElysiumVanguardProPlayer8K_ProPlayerEngine"
        
        // 1. Try the default Bundle.module logic (but safely)
        let candidates = [
            // Bundle should be next to the executable
            Bundle.main.resourceURL,
            // Bundle should be in the main bundle's resources
            Bundle.main.resourceURL?.appendingPathComponent("\(bundleName).bundle"),
            // For command-line tools
            Bundle.main.bundleURL,
        ]
        
        for candidate in candidates {
            if let bundlePath = candidate, let bundle = Bundle(url: bundlePath) {
                if bundle.bundleIdentifier?.contains("ProPlayerEngine") == true {
                    return bundle
                }
            }
        }
        
        // 2. Search for the bundle by name in common locations
        let searchPath = Bundle.main.resourcePath ?? ""
        if let enumerator = FileManager.default.enumerator(atPath: searchPath) {
            while let file = enumerator.nextObject() as? String {
                if file.hasSuffix("\(bundleName).bundle") {
                    let fullPath = (searchPath as NSString).appendingPathComponent(file)
                    if let bundle = Bundle(path: fullPath) {
                        return bundle
                    }
                }
            }
        }
        
        // 3. Last resort: Return main bundle and hope for the best, 
        // rather than crashing with assertionFailure.
        print("[ProPlayerEngine] WARNING: Falling back to Bundle.main for resources.")
        return Bundle.main
    }
}
