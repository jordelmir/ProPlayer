import Foundation

extension Bundle {
    /// A robust replacement for Bundle.module for the main ProPlayer app.
    public static var proPlayerApp: Bundle {
        let bundleName = "ElysiumVanguardProPlayer8K_ProPlayer"
        
        let candidates = [
            Bundle.main.resourceURL,
            Bundle.main.resourceURL?.appendingPathComponent("\(bundleName).bundle"),
            Bundle.main.bundleURL,
        ]
        
        for candidate in candidates {
            if let bundlePath = candidate, let bundle = Bundle(url: bundlePath) {
                // Check if this bundle contains our expected resources (like ElysiumLogo)
                if bundle.path(forResource: "ElysiumLogo", ofType: "png") != nil {
                    return bundle
                }
            }
        }
        
        // Manual search
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
        
        print("[ProPlayer] WARNING: Falling back to Bundle.main for app resources.")
        return Bundle.main
    }
}
