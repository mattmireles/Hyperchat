// ViewProvider.swift - Centralized creation of service views
//
// Responsibility:
// - Given an AIService and its dependencies, return the correct NSView to display
// - Local services: return NSHostingController(LocalChatView).view
// - Web services: return BrowserViewController(viewing the service WebView).view
// - Apply consistent styling to all returned views
//
// Notes:
// - WebViews are created and owned by ServiceManager via WebViewFactory.
// - This provider only wraps them in the appropriate controller/view for display.

import AppKit
import SwiftUI
import WebKit
import Combine

/// Bundle containing the produced view and any controller references the caller may need
struct ServiceViewBundle {
    let view: NSView
    let browserController: BrowserViewController?
    let localHostingController: NSHostingController<LocalChatView>?
}

/// Centralized factory for creating the correct view for a given AIService
final class ViewProvider {
    static let shared = ViewProvider()
    private init() {}
    
    /// Creates a view for the provided service.
    /// - Parameters:
    ///   - service: The AI service to display
    ///   - serviceManager: Source of pre-configured WebViews for web services
    ///   - isFirstService: Whether this service is the leftmost (used for shortcuts)
    ///   - appFocusPublisher: Publisher indicating app focus state for focus indicators
    /// - Returns: A bundle containing the view and any created controllers, or nil if unavailable
    func makeServiceView(
        for service: AIService,
        serviceManager: ServiceManager,
        isFirstService: Bool,
        appFocusPublisher: AnyPublisher<Bool, Never>
    ) -> ServiceViewBundle? {
        switch service.backend {
        case .local(let model):
            let chatView = LocalChatView(model: model, serviceId: service.id)
            let hostingController = NSHostingController(rootView: chatView)
            let view = hostingController.view
            configureAppearance(for: view)
            return ServiceViewBundle(
                view: view,
                browserController: nil,
                localHostingController: hostingController
            )
            
        case .web:
            guard let webService = serviceManager.webServices[service.id] else {
                return nil
            }
            let controller = BrowserViewController(
                webView: webService.webView,
                service: service,
                isFirstService: isFirstService,
                appFocusPublisher: appFocusPublisher
            )
            let browserView = controller.view
            configureAppearance(for: browserView)
            return ServiceViewBundle(
                view: browserView,
                browserController: controller,
                localHostingController: nil
            )
        }
    }
    
    private func configureAppearance(for view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.layer?.cornerRadius = 8
        view.layer?.masksToBounds = true
    }
}


