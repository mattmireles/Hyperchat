/// FaviconFetcher.swift - Lightweight Favicon Loading
///
/// This file provides a lightweight way to fetch favicons without creating WebViews.
/// It's used by the Settings window to ensure all services show their icons.
///
/// Key features:
/// - Direct HTTP fetching of favicon URLs
/// - Multiple fallback strategies (favicon.ico, apple-touch-icon, etc.)
/// - Caching to avoid redundant network requests
/// - Works for both enabled and disabled services
///
/// Related files:
/// - `SettingsWindowController.swift`: Uses this to prefetch missing favicons
/// - `SettingsManager.swift`: Stores the fetched favicon URLs
/// - `ServiceManager.swift`: Primary favicon extraction via WebView
///
/// Why this exists:
/// - ServiceManager only loads favicons for enabled services
/// - Settings window needs to show icons for ALL services
/// - Creating WebViews just for favicons is resource-intensive

import Foundation

/// Fetches favicons for services without creating WebViews.
///
/// This class provides a lightweight alternative to WebView-based favicon extraction.
/// It tries multiple strategies to find a service's favicon:
/// 1. Check common favicon paths (/favicon.ico, /apple-touch-icon.png)
/// 2. Parse HTML to find icon links
/// 3. Use fallback URLs based on service configuration
///
/// Usage:
/// ```swift
/// let fetcher = FaviconFetcher()
/// fetcher.fetchFavicon(for: service) { url in
///     // Update service with favicon URL
/// }
/// ```
class FaviconFetcher {
    /// Shared instance for global access
    static let shared = FaviconFetcher()
    
    /// URLSession configured for favicon fetching
    private let session: URLSession
    
    /// Cache of already-fetched favicon URLs to avoid redundant requests
    private var faviconCache: [String: URL] = [:]
    
    /// Queue for thread-safe cache access
    private let cacheQueue = DispatchQueue(label: "com.hyperchat.faviconcache")
    
    private init() {
        // Configure URLSession with short timeout for favicon requests
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
    }
    
    /// Fetches favicon for a service if it doesn't already have one.
    ///
    /// Called by:
    /// - `SettingsWindowController.prefetchMissingFavicons()`
    ///
    /// Process:
    /// 1. Check if service already has favicon
    /// 2. Check cache for previously fetched URL
    /// 3. Try multiple favicon URLs in order
    /// 4. Save successful result to SettingsManager
    ///
    /// - Parameters:
    ///   - service: The AI service to fetch favicon for
    ///   - completion: Called with favicon URL if found, nil otherwise
    func fetchFaviconIfNeeded(for service: AIService, completion: @escaping (URL?) -> Void) {
        // Skip if service already has favicon
        if service.faviconURL != nil {
            print("✅ Service \(service.name) already has favicon")
            completion(service.faviconURL)
            return
        }
        
        // Check cache
        if let cachedURL = getCachedFavicon(for: service.id) {
            print("📦 Using cached favicon for \(service.name): \(cachedURL)")
            completion(cachedURL)
            return
        }
        
        // Determine base URL for the service
        let baseURL: String
        switch service.activationMethod {
        case .urlParameter(let url, _):
            baseURL = url
        case .clipboardPaste(let url):
            baseURL = url
        }
        
        guard let url = URL(string: baseURL) else {
            print("❌ Invalid base URL for \(service.name): \(baseURL)")
            completion(nil)
            return
        }
        
        // Try multiple favicon URLs
        let faviconPaths = [
            "/favicon.ico",
            "/favicon.png", 
            "/apple-touch-icon.png",
            "/apple-touch-icon-precomposed.png"
        ]
        
        tryFaviconPaths(
            host: url.host ?? "",
            scheme: url.scheme ?? "https",
            paths: faviconPaths,
            service: service,
            completion: completion
        )
    }
    
    /// Tries multiple favicon paths for a given host.
    private func tryFaviconPaths(
        host: String,
        scheme: String,
        paths: [String],
        service: AIService,
        completion: @escaping (URL?) -> Void
    ) {
        var remainingPaths = paths
        
        func tryNextPath() {
            guard !remainingPaths.isEmpty else {
                print("❌ No favicon found for \(service.name)")
                completion(nil)
                return
            }
            
            let path = remainingPaths.removeFirst()
            let urlString = "\(scheme)://\(host)\(path)"
            
            guard let url = URL(string: urlString) else {
                tryNextPath()
                return
            }
            
            // Try to fetch the favicon
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD" // Just check if it exists
            
            let task = session.dataTask(with: request) { [weak self] _, response, error in
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    print("✅ Found favicon for \(service.name): \(url)")
                    self?.cacheFavicon(url, for: service.id)
                    
                    // Update service in SettingsManager
                    DispatchQueue.main.async {
                        SettingsManager.shared.updateServiceFavicon(
                            serviceId: service.id,
                            faviconURL: url
                        )
                    }
                    
                    completion(url)
                } else {
                    // Try next path
                    tryNextPath()
                }
            }
            
            task.resume()
        }
        
        tryNextPath()
    }
    
    /// Gets cached favicon URL for a service.
    private func getCachedFavicon(for serviceId: String) -> URL? {
        cacheQueue.sync {
            return faviconCache[serviceId]
        }
    }
    
    /// Caches favicon URL for a service.
    private func cacheFavicon(_ url: URL, for serviceId: String) {
        cacheQueue.async {
            self.faviconCache[serviceId] = url
        }
    }
    
    /// Clears the favicon cache.
    ///
    /// Useful for forcing re-fetch of all favicons.
    func clearCache() {
        cacheQueue.async {
            self.faviconCache.removeAll()
        }
    }
}

/// Extension to provide service-specific favicon URLs.
///
/// Some services use non-standard favicon locations.
/// This extension provides known good favicon URLs.
extension FaviconFetcher {
    /// Known favicon URLs for specific services.
    ///
    /// These are hardcoded fallbacks for services with unusual favicon locations.
    private func knownFaviconURL(for serviceId: String) -> URL? {
        switch serviceId {
        case "chatgpt":
            return URL(string: "https://cdn.oaistatic.com/assets/favicon-o20kmmos.ico")
        case "claude":
            return URL(string: "https://claude.ai/favicon.ico")
        case "perplexity":
            return URL(string: "https://www.perplexity.ai/favicon.ico")
        case "google":
            return URL(string: "https://www.google.com/favicon.ico")
        default:
            return nil
        }
    }
    
    /// Fetches favicon using known URL if available.
    ///
    /// Some services have non-standard favicon locations that won't be found
    /// by the standard path search. This method tries known good URLs first.
    func fetchFaviconWithKnownURL(for service: AIService, completion: @escaping (URL?) -> Void) {
        // Try known URL first
        if let knownURL = knownFaviconURL(for: service.id) {
            var request = URLRequest(url: knownURL)
            request.httpMethod = "HEAD"
            
            let task = session.dataTask(with: request) { [weak self] _, response, error in
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    print("✅ Found favicon using known URL for \(service.name): \(knownURL)")
                    self?.cacheFavicon(knownURL, for: service.id)
                    
                    // Update service in SettingsManager
                    DispatchQueue.main.async {
                        SettingsManager.shared.updateServiceFavicon(
                            serviceId: service.id,
                            faviconURL: knownURL
                        )
                    }
                    
                    completion(knownURL)
                } else {
                    // Fall back to standard search
                    self?.fetchFaviconIfNeeded(for: service, completion: completion)
                }
            }
            
            task.resume()
        } else {
            // No known URL, use standard search
            fetchFaviconIfNeeded(for: service, completion: completion)
        }
    }
}