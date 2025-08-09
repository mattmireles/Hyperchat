// CrashRecovery.swift - WebView crash handling and recovery

import Foundation
import WebKit

extension ServiceManager {
    /// Handles WebView process crashes with automatic recovery.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard let serviceId = findServiceId(for: webView) else { return }
        
        print("⚠️ WebView process crashed for service: \(serviceId)")
        WebViewLogger.shared.log("⚠️ WebView process crashed, attempting recovery", for: serviceId, type: .error)
        
        updateLoadingState(for: serviceId, isLoading: false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + ServiceTimings.crashRecoveryDelay) { [weak self] in
            guard let self = self else { return }
            if let service = self.activeServices.first(where: { $0.id == serviceId }),
               let webService = self.webServices[serviceId] {
                self.loadDefaultPage(for: service, webView: webService.webView, forceReload: true)
                WebViewLogger.shared.log("🔄 WebView recovered from crash", for: serviceId, type: .info)
            }
        }
    }
}


