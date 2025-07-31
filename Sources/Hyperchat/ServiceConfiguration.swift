/// ServiceConfiguration.swift - AI Service URL Configuration and Settings
///
/// This file defines URL configurations for each AI service including home URLs,
/// query parameter formats, and user agent strings. It provides a centralized
/// location for service-specific URL building logic.
///
/// Key responsibilities:
/// - Stores base URLs and home URLs for each service
/// - Defines query parameter names and formats
/// - Provides user agent strings (desktop Safari or iPad)
/// - Builds complete URLs with encoded query parameters
/// - Maps service IDs to configurations
///
/// Related files:
/// - `AIService.swift`: Uses configurations for service URLs
/// - `ServiceManager.swift`: Uses to load initial pages and execute prompts
/// - `UserAgentGenerator.swift`: Generates dynamic Safari user agent
/// - `WebViewFactory.swift`: Applies user agent to WebView configuration
///
/// Architecture:
/// - Static configuration pattern (no instances)
/// - ServiceURLConfig struct for URL building logic
/// - ServiceConfigurations namespace for service definitions
/// - Dynamic user agent generation for compatibility

import Foundation

// MARK: - Service Backend Types

/// Defines the backend type for an AI service.
///
/// This enum makes explicit the fundamental architectural difference between
/// web-based services (which use WKWebView) and local inference services 
/// (which use the InferenceEngine). This clean separation prevents the need
/// for hacks like mock WebViews and allows each service type to have its
/// appropriate implementation.
///
/// Used by:
/// - `AIService` struct to specify its backend type
/// - Service creation logic to determine UI implementation
/// - ServiceManager to route prompts to appropriate handlers
public enum ServiceBackend {
    /// Web-based service using WKWebView with specified URL configuration
    case web(config: ServiceURLConfig)
    
    /// Local inference service using InferenceEngine with managed model
    case local(model: LocalModel)
}

// MARK: - Service URL Configuration

/// Configuration for building service-specific URLs.
///
/// Used by:
/// - `ServiceManager.loadDefaultPage()` for initial page load
/// - `URLParameterService.executePrompt()` for query submission
///
/// URL Building:
/// - homeURL: Initial page to load (may differ from baseURL)
/// - baseURL: Base for constructing query URLs
/// - queryParam: Parameter name (usually "q")
/// - additionalParams: Extra parameters (e.g., language)
///
/// Example:
/// - homeURL: "https://chatgpt.com"
/// - baseURL: "https://chatgpt.com"
/// - queryParam: "q"
/// - Result: "https://chatgpt.com?q=encoded+query"
public struct ServiceURLConfig: Codable {
    /// URL for initial page load (defaults to baseURL)
    let homeURL: String
    
    /// Base URL for building query parameters
    let baseURL: String
    
    /// Query parameter name (e.g., "q" for most services)
    let queryParam: String
    
    /// Additional URL parameters to always include
    let additionalParams: [String: String]
    
    /// Custom user agent string (nil uses default)
    let userAgent: String?
    
    init(homeURL: String? = nil, baseURL: String, queryParam: String, additionalParams: [String: String] = [:], userAgent: String? = nil) {
        self.homeURL = homeURL ?? baseURL  // Default to baseURL if homeURL not specified
        self.baseURL = baseURL
        self.queryParam = queryParam
        self.additionalParams = additionalParams
        self.userAgent = userAgent
    }
    
    /// Builds complete URL with encoded query.
    ///
    /// Called by:
    /// - `URLParameterService.executePrompt()` for URL navigation
    ///
    /// Process:
    /// 1. URL encodes the query string
    /// 2. Appends as main query parameter
    /// 3. Adds any additional parameters
    ///
    /// Example:
    /// - Query: "What is Swift?"
    /// - Result: "https://chatgpt.com?q=What%20is%20Swift%3F"
    ///
    /// - Parameter query: User's prompt text
    /// - Returns: Complete URL with encoded parameters
    func buildURL(with query: String) -> String {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        var urlString = "\(baseURL)?\(queryParam)=\(encodedQuery)"
        
        // Add any additional parameters
        for (key, value) in additionalParams {
            urlString += "&\(key)=\(value)"
        }
        
        return urlString
    }
}

// MARK: - Service Configurations

/// Static namespace for all service URL configurations.
///
/// User Agent Strategy:
/// - Desktop Safari: For ChatGPT, Claude, Perplexity
/// - iPad Safari: For Google (better mobile-optimized UI)
///
/// The desktop user agent is dynamically generated to match
/// the current macOS and Safari versions for compatibility.
struct ServiceConfigurations {
    // MARK: User Agents
    
    /// iPad user agent for mobile-optimized interfaces.
    /// Google uses this for a cleaner, touch-friendly UI.
    static let iPadUserAgent = "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    
    /// Desktop Safari user agent generated dynamically.
    /// Matches current system for maximum compatibility.
    static let desktopSafariUserAgent: String = {
        // Generate dynamic Safari user agent
        let userAgent = UserAgentGenerator.generate()
        return userAgent.fullUserAgent
    }()
    
    // MARK: Service Definitions
    
    /// ChatGPT configuration.
    ///
    /// URL behavior:
    /// - Accepts "q" parameter for new conversations
    /// - Desktop user agent for full features
    /// - Same URL for home and queries
    static let chatGPT = ServiceURLConfig(
        homeURL: "https://chatgpt.com",
        baseURL: "https://chatgpt.com",
        queryParam: "q",
        userAgent: desktopSafariUserAgent
    )
    
    /// Perplexity configuration.
    ///
    /// URL behavior:
    /// - Home page must load first before queries work
    /// - Queries go to /search/new endpoint
    /// - Desktop user agent required
    static let perplexity = ServiceURLConfig(
        homeURL: "https://www.perplexity.ai",
        baseURL: "https://www.perplexity.ai/search/new",
        queryParam: "q",
        userAgent: desktopSafariUserAgent
    )
    
    /// Google Search configuration.
    ///
    /// URL behavior:
    /// - Standard Google search parameters
    /// - iPad user agent for cleaner UI
    /// - Additional params for consistent results
    ///
    /// Additional parameters:
    /// - hl=en: Forces English interface
    /// - safe=off: Disables SafeSearch filtering
    static let google = ServiceURLConfig(
        homeURL: "https://www.google.com",
        baseURL: "https://www.google.com/search",
        queryParam: "q",
        additionalParams: [
            "hl": "en",        // Language
            "safe": "off"      // Safe search
        ],
        userAgent: iPadUserAgent
    )
    
    /// Claude configuration.
    ///
    /// URL behavior:
    /// - Does NOT support URL parameters currently
    /// - Uses clipboard paste method instead
    /// - Config kept for consistency and future use
    ///
    /// Note: The queryParam is placeholder only.
    /// Claude requires ClipboardPasteService approach.
    static let claude = ServiceURLConfig(
        homeURL: "https://claude.ai",
        baseURL: "https://claude.ai",
        queryParam: "q",  // If Claude starts supporting URL params
        userAgent: desktopSafariUserAgent
    )
    
    /// Maps service ID to configuration.
    ///
    /// Called by:
    /// - `ServiceManager` to get URLs for each service
    /// - `URLParameterService` to build query URLs
    ///
    /// Service IDs:
    /// - "chatgpt": ChatGPT configuration
    /// - "perplexity": Perplexity configuration  
    /// - "google": Google Search configuration
    /// - "claude": Claude configuration
    ///
    /// - Parameter serviceId: Service identifier string
    /// - Returns: Configuration or nil if unknown ID
    static func config(for serviceId: String) -> ServiceURLConfig? {
        switch serviceId {
        case "chatgpt":
            return chatGPT
        case "perplexity":
            return perplexity
        case "google":
            return google
        case "claude":
            return claude
        default:
            return nil
        }
    }
} 