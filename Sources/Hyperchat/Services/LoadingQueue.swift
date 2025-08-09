// LoadingQueue.swift - Sequential WebView loading logic

import Foundation
import WebKit

extension ServiceManager {
    /// Loads the next service from the sequential loading queue.
    /// Extracted from ServiceManager for clarity.
    func loadNextServiceFromQueue(forceReload: Bool = false) {
        // Check if we're already loading or if queue is empty
        guard currentlyLoadingService == nil, !serviceLoadingQueue.isEmpty else {
            print("⏭️ Skipping loadNextServiceFromQueue - already loading: \(currentlyLoadingService ?? "none"), queue count: \(serviceLoadingQueue.count)")
            
            // If queue is empty and we were force reloading, clear the flag
            if serviceLoadingQueue.isEmpty && isForceReloading {
                isForceReloading = false
                print("✅ Force reload completed for all services")
            }
            return
        }
        
        let shouldForceReload = forceReload || isForceReloading
        let service = serviceLoadingQueue.removeFirst()
        
        guard let webService = webServices[service.id] else {
            print("❌ No webService found for \(service.id)")
            loadNextServiceFromQueue()
            return
        }
        let webView = webService.webView
        
        currentlyLoadingService = service.id
        print("🔄 Loading service from queue: \(service.name)")
        
        loadDefaultPage(for: service, webView: webView, forceReload: shouldForceReload)
    }
    
    /// Loads a service's default page, honoring force reload.
    func loadDefaultPage(for service: AIService, webView: WKWebView, forceReload: Bool = false) {
        let expectedHomeURL: String
        if let config = ServiceConfigurations.config(for: service.id) {
            expectedHomeURL = config.homeURL
        } else if service.id == "claude" {
            expectedHomeURL = "https://claude.ai"
        } else {
            return
        }
        
        if !forceReload {
            if webView.isLoading { return }
            if let currentURL = webView.url?.absoluteString,
               currentURL.hasPrefix(expectedHomeURL) || currentURL.contains("?q=") {
                return
            }
        }
        
        loadingStates[service.id] = true
        
        let defaultURL: String
        if let config = ServiceConfigurations.config(for: service.id) {
            defaultURL = config.homeURL
        } else {
            switch service.id {
            case "claude": defaultURL = "https://claude.ai"
            default: return
            }
        }
        
        if let url = URL(string: defaultURL) {
            var request = URLRequest(url: url)
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                if forceReload || (!webView.isLoading && webView.url?.absoluteString.contains("?q=") != true) {
                    webView.load(request)
                }
            }
        }
    }
}


