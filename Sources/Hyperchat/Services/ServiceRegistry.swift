// ServiceRegistry.swift - Global ServiceManager tracking and lookups

import Foundation
import WebKit

extension ServiceManager {
    /// Array of weak references to all ServiceManager instances.
    /// Automatically cleaned up when managers are deallocated.
    static var allManagers: [WeakServiceManagerWrapper] = []
    
    /// Wrapper to hold weak references and prevent retain cycles.
    class WeakServiceManagerWrapper {
        weak var manager: ServiceManager?
        init(_ manager: ServiceManager) {
            self.manager = manager
        }
    }
    
    func registerManager() {
        ServiceManager.allManagers.append(WeakServiceManagerWrapper(self))
        // Clean up nil references
        ServiceManager.allManagers = ServiceManager.allManagers.filter { $0.manager != nil }
    }
    
    func getAllServiceManagers() -> [ServiceManager] {
        ServiceManager.allManagers.compactMap { $0.manager }
    }
    
    func findServiceId(for webView: WKWebView) -> String? {
        for (serviceId, webService) in webServices {
            if webService.webView == webView {
                return serviceId
            }
        }
        return nil
    }
    
    func updateLoadingState(for serviceId: String, isLoading: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.loadingStates[serviceId] = isLoading
        }
    }
}


