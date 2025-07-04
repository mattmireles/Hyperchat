import Foundation
import WebKit

struct UserAgentGenerator {
    static func generate() -> (applicationName: String, fullUserAgent: String) {
        // We generate a user agent that mimics Safari on the user's current OS.
        // We report the actual OS version to ensure services like Google serve modern UIs.
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osVersionString = "\(osVersion.majorVersion)_\(osVersion.minorVersion)\(osVersion.patchVersion > 0 ? "_\(osVersion.patchVersion)" : "")"
        
        // For maximum compatibility, we still report "Intel" even on Apple Silicon,
        // as this is what Safari itself does.
        let architecture = "Intel"

        // Get WebKit and Safari versions dynamically to stay current.
        let webKitVersion = getWebKitVersion()
        let safariVersion = getSafariVersion()

        // Build the final user agent string.
        let applicationName = "Version/\(safariVersion) Safari/\(webKitVersion)"
        let fullUserAgent = "Mozilla/5.0 (Macintosh; \(architecture) Mac OS X \(osVersionString)) AppleWebKit/\(webKitVersion) (KHTML, like Gecko) \(applicationName)"
        
        return (applicationName: applicationName, fullUserAgent: fullUserAgent)
    }

    private static func getWebKitVersion() -> String {
        if let webKitBundle = Bundle(identifier: "com.apple.WebKit"),
           let version = webKitBundle.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        // A modern, safe fallback.
        return "605.1.15"
    }

    private static func getSafariVersion() -> String {
        if let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari"),
           let safariBundle = Bundle(url: safariURL),
           let version = safariBundle.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        // If Safari isn't found, use a reasonable modern version.
        return "17.5"
    }
} 