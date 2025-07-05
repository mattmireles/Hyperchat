/// WebViewFactory.swift - WebView Creation and Configuration
///
/// This file handles the creation of properly configured WKWebView instances for each AI service.
/// It ensures consistent configuration, proper cleanup, and debugging support.
///
/// Key responsibilities:
/// - Creates WKWebView instances with shared process pool
/// - Configures user agents for service compatibility
/// - Injects JavaScript for console logging and monitoring
/// - Manages script message handlers lifecycle
/// - Prevents common WebView issues (white flash, focus stealing)
///
/// Related files:
/// - `ServiceManager.swift`: Uses factory to create WebViews for each service
/// - `WebViewLogger.swift`: Provides JavaScript injection scripts
/// - `UserAgentGenerator.swift`: Creates Safari-compatible user agents
/// - `ServiceConfigurations.swift`: Provides service-specific settings
///
/// Critical patterns:
/// - Always use WKProcessPool.shared (never create new pools)
/// - Clean up message handlers before WebView deallocation
/// - Use associated objects to retain message handlers

import Foundation
import WebKit

// MARK: - Console Message Handler for WebViewFactory

/// Handles JavaScript messages from WebViews.
///
/// Each handler is specific to:
/// - A service (ChatGPT, Claude, etc.)
/// - A message type (consoleLog, networkRequest, etc.)
///
/// Lifecycle:
/// 1. Created during WebView setup
/// 2. Added to WKUserContentController
/// 3. Receives messages from JavaScript
/// 4. Must be cleaned up before WebView deallocation
///
/// The isCleanedUp flag prevents crashes from messages arriving
/// after the WebView has started cleanup.
private class WebViewFactoryMessageHandler: NSObject, WKScriptMessageHandler {
    let service: String
    let messageType: String
    private var isCleanedUp = false
    
    init(service: String, messageType: String) {
        self.service = service
        self.messageType = messageType
        super.init()
    }
    
    func markCleanedUp() {
        isCleanedUp = true
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard !isCleanedUp else {
            print("⚠️ [\(Date().timeIntervalSince1970)] Message received after cleanup for \(service)")
            return
        }
        
        guard let messageBody = message.body as? String else { return }
        
        // Parse the message based on type
        if messageType == "consoleLog" {
            if let data = messageBody.data(using: .utf8),
               let logData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let level = logData["level"] as? String ?? "log"
                let args = logData["args"] as? [String] ?? []
                let logMessage = args.joined(separator: " ")
                
                // Route to appropriate log type
                let logType: LogType
                switch level {
                case "error": logType = .error
                case "warn": logType = .warning
                default: logType = .info
                }
                
                WebViewLogger.shared.log(logMessage, for: service, type: logType)
            }
        }
        // Add other message type handling as needed
    }
}

// MARK: - WebViewFactory

/// Factory for creating properly configured WKWebView instances.
///
/// Singleton pattern ensures:
/// - Consistent WebView configuration
/// - Shared WKProcessPool usage
/// - Centralized cleanup logic
///
/// Used by:
/// - `ServiceManager.setupServices()` to create WebViews
///
/// Creates WebViews with:
/// - Shared cookies and authentication (WKWebsiteDataStore.default)
/// - Console logging injection
/// - Service-specific user agents
/// - Black background to prevent white flash
class WebViewFactory {
    static let shared = WebViewFactory()
    
    /// Names of all script message handlers.
    /// Used for both registration and cleanup.
    static let scriptMessageHandlerNames = [
        "consoleLog",      // Console.log() messages
        "networkRequest",  // XHR/Fetch requests
        "networkResponse", // Network responses
        "userInteraction" // Click/input events
    ]
    
    private init() {}
    
    /// Creates a configured WKWebView for an AI service.
    ///
    /// Called by:
    /// - `ServiceManager.setupServices()` for each enabled service
    ///
    /// Configuration includes:
    /// - Shared process pool (critical for performance)
    /// - Shared data store (maintains login state)
    /// - Service-specific user agent
    /// - JavaScript injection for debugging
    /// - Visual optimizations (black background, rounded corners)
    ///
    /// - Parameter service: The AI service this WebView will display
    /// - Returns: Configured WKWebView ready for use
    func createWebView(for service: AIService) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()  // Share cookies, passwords, and login state with Safari
        if #available(macOS 11.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        // Use shared process pool for all services
        configuration.processPool = WKProcessPool.shared
        
        // Prevent loading cancellations
        configuration.suppressesIncrementalRendering = false
        
        // Setup logging scripts and message handlers
        let handlers = setupLoggingScripts(for: configuration, service: service)
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // Store handlers with webView to ensure they're retained
        objc_setAssociatedObject(webView, &messageHandlerKey, handlers, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Set the background to black to prevent white flash
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = NSColor.black
        }
        
        // Prevent web view from taking focus during initial load
        webView.isHidden = false
        webView.allowsBackForwardNavigationGestures = false  // Temporarily disable
        
        // Set user agent from service configuration
        if let config = ServiceConfigurations.config(for: service.id),
           let userAgent = config.userAgent {
            webView.customUserAgent = userAgent
            // Extract application name from user agent if needed
            if userAgent.contains("Safari/") {
                let components = userAgent.components(separatedBy: " ")
                if let safariComponent = components.last(where: { $0.contains("Safari/") }) {
                    configuration.applicationNameForUserAgent = safariComponent
                }
            }
        } else {
            // Fallback to desktop Safari user agent
            let userAgent = UserAgentGenerator.generate()
            webView.customUserAgent = userAgent.fullUserAgent
            configuration.applicationNameForUserAgent = userAgent.applicationName
        }
        
        // Enable interactions (navigation gestures will be enabled after initial load)
        webView.allowsMagnification = true
        
        // Enable text selection
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        // Ensure the WebView can become first responder for text selection
        webView.wantsLayer = true
        webView.layer?.cornerRadius = 8
        webView.layer?.masksToBounds = true
        
        // Re-enable navigation gestures after initial load
        // Delay prevents gesture conflicts during page loading
        let navigationGestureDelay: TimeInterval = 3.0
        DispatchQueue.main.asyncAfter(deadline: .now() + navigationGestureDelay) {
            webView.allowsBackForwardNavigationGestures = true
        }
        
        return webView
    }
    
    /// Sets up JavaScript logging and monitoring scripts.
    ///
    /// Called during WebView creation to inject:
    /// - Console logging capture
    /// - Network request/response monitoring
    /// - User interaction tracking
    /// - DOM change monitoring (disabled for performance)
    ///
    /// Message flow:
    /// 1. JavaScript events occur in WebView
    /// 2. Injected scripts capture events
    /// 3. Scripts send messages via webkit.messageHandlers
    /// 4. Message handlers route to WebViewLogger
    ///
    /// - Parameters:
    ///   - configuration: WebView configuration to modify
    ///   - service: Service for logging context
    /// - Returns: Dictionary of message handlers for retention
    private func setupLoggingScripts(for configuration: WKWebViewConfiguration, service: AIService) -> [String: WebViewFactoryMessageHandler] {
        let userContentController = configuration.userContentController
        
        print("📋 [\(Date().timeIntervalSince1970)] Setting up logging scripts for \(service.name)")
        
        // Create separate message handlers for each type
        let consoleHandler = WebViewFactoryMessageHandler(service: service.name, messageType: "consoleLog")
        let networkRequestHandler = WebViewFactoryMessageHandler(service: service.name, messageType: "networkRequest")
        let networkResponseHandler = WebViewFactoryMessageHandler(service: service.name, messageType: "networkResponse")
        let userInteractionHandler = WebViewFactoryMessageHandler(service: service.name, messageType: "userInteraction")
        
        // Store handlers for cleanup
        let handlers: [String: WebViewFactoryMessageHandler] = [
            "consoleLog": consoleHandler,
            "networkRequest": networkRequestHandler,
            "networkResponse": networkResponseHandler,
            "userInteraction": userInteractionHandler
        ]
        
        // Add message handlers using centralized names
        for handlerName in WebViewFactory.scriptMessageHandlerNames {
            if let handler = handlers[handlerName] {
                userContentController.add(handler, name: handlerName)
            }
        }
        
        print("✅ [\(Date().timeIntervalSince1970)] Added \(handlers.count) message handlers for \(service.name)")
        
        // Inject console logging script
        let consoleScript = WKUserScript(
            source: WebViewLogger.shared.consoleLogScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(consoleScript)
        
        // Inject network monitoring script
        let networkScript = WKUserScript(
            source: WebViewLogger.shared.networkMonitorScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(networkScript)
        
        // DOM monitoring disabled due to performance issues
        // Uncomment to re-enable DOM change tracking
        /*
        let domScript = WKUserScript(
            source: WebViewLogger.shared.domMonitorScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(domScript)
        */
        
        // Inject user interaction tracking script
        let interactionScript = WKUserScript(
            source: WebViewLogger.shared.userInteractionScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(interactionScript)
        
        WebViewLogger.shared.log("Logging initialized for \(service.name)", for: service.name, type: .info)
        
        return handlers
    }
    
    /// Cleans up message handlers before WebView deallocation.
    ///
    /// Called by:
    /// - `ServiceManager.deinit` during cleanup
    /// - Window close operations
    ///
    /// CRITICAL: Must be called before WebView deallocation to prevent:
    /// - JavaScript messages arriving after cleanup
    /// - Crashes in WKScriptMessageHandler
    /// - Memory leaks from retained handlers
    ///
    /// Cleanup process:
    /// 1. Remove all script message handlers from controller
    /// 2. Mark handlers as cleaned up
    /// 3. Clear associated object references
    func cleanupMessageHandlers(for webView: WKWebView) {
        print("🧹 [\(Date().timeIntervalSince1970)] Cleaning up message handlers for WebView")
        
        let userContentController = webView.configuration.userContentController
        
        // Remove all script message handlers
        for handlerName in WebViewFactory.scriptMessageHandlerNames {
            userContentController.removeScriptMessageHandler(forName: handlerName)
        }
        
        // Mark handlers as cleaned up
        if let handlers = objc_getAssociatedObject(webView, &messageHandlerKey) as? [String: WebViewFactoryMessageHandler] {
            for (_, handler) in handlers {
                handler.markCleanedUp()
            }
        }
        
        // Clear associated object
        objc_setAssociatedObject(webView, &messageHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

/// Key for associated object storage.
/// Used to retain message handlers with the WebView instance.
/// This prevents handlers from being deallocated while WebView is active.
private var messageHandlerKey: UInt8 = 0