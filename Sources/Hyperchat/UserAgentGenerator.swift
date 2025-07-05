/// UserAgentGenerator.swift - Dynamic Safari-Compatible User Agent Generation
///
/// This file generates user agent strings that match the current system's Safari
/// browser, ensuring maximum compatibility with web services that may block or
/// limit non-standard browsers.
///
/// Key responsibilities:
/// - Detects current macOS version dynamically
/// - Retrieves actual WebKit version from system
/// - Retrieves actual Safari version if installed
/// - Constructs RFC-compliant user agent string
/// - Reports Intel architecture for compatibility
///
/// Related files:
/// - `ServiceConfiguration.swift`: Uses generated user agent for services
/// - `WebViewFactory.swift`: Applies user agent to WKWebView configuration
///
/// Architecture:
/// - Static utility struct (no instances)
/// - Dynamic version detection at runtime
/// - Safe fallbacks if detection fails

import Foundation
import WebKit

/// Fallback version numbers for resilience.
private enum UserAgentDefaults {
    /// Default WebKit version if detection fails
    static let webKitVersion = "605.1.15"
    
    /// Default Safari version if detection fails
    static let safariVersion = "17.5"
    
    /// Architecture string (always Intel for compatibility)
    static let architecture = "Intel"
}

/// Generates Safari-compatible user agent strings.
///
/// Why this matters:
/// - Some services block non-standard user agents
/// - Services may serve different UIs based on browser
/// - Reporting accurate OS version gets modern features
/// - Using "Intel" maintains compatibility on Apple Silicon
struct UserAgentGenerator {
    /// Generates complete user agent matching system Safari.
    ///
    /// Called by:
    /// - `ServiceConfigurations.desktopSafariUserAgent` static initializer
    ///
    /// Returns tuple with:
    /// - applicationName: Version/Safari string portion
    /// - fullUserAgent: Complete Mozilla-compatible string
    ///
    /// Example output:
    /// - applicationName: "Version/17.5 Safari/605.1.15"
    /// - fullUserAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
    static func generate() -> (applicationName: String, fullUserAgent: String) {
        // We generate a user agent that mimics Safari on the user's current OS.
        // We report the actual OS version to ensure services like Google serve modern UIs.
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osVersionString = "\(osVersion.majorVersion)_\(osVersion.minorVersion)\(osVersion.patchVersion > 0 ? "_\(osVersion.patchVersion)" : "")"
        
        // For maximum compatibility, we still report "Intel" even on Apple Silicon,
        // as this is what Safari itself does.
        let architecture = UserAgentDefaults.architecture

        // Get WebKit and Safari versions dynamically to stay current.
        let webKitVersion = getWebKitVersion()
        let safariVersion = getSafariVersion()

        // Build the final user agent string.
        let applicationName = "Version/\(safariVersion) Safari/\(webKitVersion)"
        let fullUserAgent = "Mozilla/5.0 (Macintosh; \(architecture) Mac OS X \(osVersionString)) AppleWebKit/\(webKitVersion) (KHTML, like Gecko) \(applicationName)"
        
        return (applicationName: applicationName, fullUserAgent: fullUserAgent)
    }

    /// Retrieves WebKit version from system framework.
    ///
    /// Process:
    /// 1. Locates WebKit.framework bundle
    /// 2. Reads CFBundleShortVersionString
    /// 3. Falls back to safe default if not found
    ///
    /// The WebKit version is critical for compatibility
    /// as it identifies the rendering engine version.
    private static func getWebKitVersion() -> String {
        if let webKitBundle = Bundle(identifier: "com.apple.WebKit"),
           let version = webKitBundle.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        // A modern, safe fallback.
        return UserAgentDefaults.webKitVersion
    }

    /// Retrieves Safari version from installed application.
    ///
    /// Process:
    /// 1. Locates Safari.app via NSWorkspace
    /// 2. Loads bundle at that URL
    /// 3. Reads version from Info.plist
    /// 4. Falls back if Safari not found
    ///
    /// Note: Safari may not be installed on all systems
    /// (rare but possible), so fallback is essential.
    private static func getSafariVersion() -> String {
        if let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari"),
           let safariBundle = Bundle(url: safariURL),
           let version = safariBundle.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        // If Safari isn't found, use a reasonable modern version.
        return UserAgentDefaults.safariVersion
    }
} 