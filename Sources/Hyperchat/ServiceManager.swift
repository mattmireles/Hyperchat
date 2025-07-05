import Foundation
import WebKit
import SwiftUI

// MARK: - Service Configuration

enum ServiceActivationMethod {
    case urlParameter(baseURL: String, parameter: String)
    case clipboardPaste(baseURL: String)
}

struct AIService {
    var id: String
    var name: String
    var iconName: String
    var activationMethod: ServiceActivationMethod
    var enabled: Bool
    var order: Int
}

let defaultServices = [
    AIService(
        id: "google",
        name: "Google",
        iconName: "google-icon",
        activationMethod: .urlParameter(
            baseURL: "placeholder", // Actual config is in ServiceConfigurations
            parameter: "placeholder"
        ),
        enabled: true,
        order: 3
    ),
    AIService(
        id: "perplexity",
        name: "Perplexity",
        iconName: "perplexity-icon",
        activationMethod: .urlParameter(
            baseURL: "placeholder", // Actual config is in ServiceConfigurations
            parameter: "placeholder"
        ),
        enabled: true,
        order: 2
    ),
    AIService(
        id: "chatgpt",
        name: "ChatGPT",
        iconName: "chatgpt-icon",
        activationMethod: .urlParameter(
            baseURL: "placeholder", // Actual config is in ServiceConfigurations
            parameter: "placeholder"
        ),
        enabled: true,
        order: 1
    ),
    AIService(
        id: "claude",
        name: "Claude",
        iconName: "claude-icon",
        activationMethod: .clipboardPaste(
            baseURL: "https://claude.ai"
        ),
        enabled: false,
        order: 4
    )
]

// MARK: - WebService Protocol and Implementations

protocol WebService {
    func executePrompt(_ prompt: String)
    func executePrompt(_ prompt: String, replyToAll: Bool)
    var webView: WKWebView { get }
    var service: AIService { get }
}

class URLParameterService: WebService {
    let webView: WKWebView
    let service: AIService
    
    init(webView: WKWebView, service: AIService) {
        self.webView = webView
        self.service = service
    }

    func executePrompt(_ prompt: String) {
        executePrompt(prompt, replyToAll: false)
    }
    
    func executePrompt(_ prompt: String, replyToAll: Bool) {
        if replyToAll {
            // Reply to All mode: Use clipboard paste with auto-submit
            pastePromptIntoCurrentPage(prompt)
        } else {
            // New Chat mode: Use URL parameters for all services (no auto-submit)
            guard case .urlParameter = service.activationMethod,
                  let config = ServiceConfigurations.config(for: service.id) else { return }
            
            let urlString = config.buildURL(with: prompt)
            print("🔗 \(service.name): Loading URL: \(urlString)")
            
            if let url = URL(string: urlString) {
                print("🔍 \(service.name): URL object created: \(url.absoluteString)")
                let request = URLRequest(url: url)
                print("📋 \(service.name): URLRequest created: \(request.url?.absoluteString ?? "nil")")
                webView.load(request)
                
                // Add debugging to monitor when services auto-submit
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    let serviceName = self.service.name
                    self.webView.evaluateJavaScript("""
                        console.log('DEBUG \(serviceName): Checking if query was processed...');
                        const inputs = document.querySelectorAll('textarea, input[type="text"], div[contenteditable="true"]');
                        let foundInput = false;
                        for (const input of inputs) {
                            const value = input.value || input.textContent || '';
                            if (value.length > 0) {
                                console.log('DEBUG \(serviceName): Found populated input:', value.substring(0, 50));
                                foundInput = true;
                                break;
                            }
                        }
                        if (!foundInput) {
                            console.log('DEBUG \(serviceName): No populated input found yet');
                        }
                    """)
                }
            } else {
                print("❌ \(service.name): Failed to create URL from: \(urlString)")
            }
        }
    }
    
    private func loadHomePage() {
        let defaultURL: String
        
        switch service.id {
        case "google":
            defaultURL = "https://www.google.com"
        case "perplexity":
            defaultURL = "https://www.perplexity.ai"
        case "chatgpt":
            defaultURL = "https://chatgpt.com"
        case "claude":
            defaultURL = "https://claude.ai"
        default:
            return
        }
        
        if let url = URL(string: defaultURL) {
            webView.load(URLRequest(url: url))
        }
    }
    
    private func pastePromptIntoCurrentPage(_ prompt: String) {
        // Copy prompt to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(prompt, forType: .string)
        
        print("PASTE \(service.name): Pasting prompt '\(prompt.prefix(50))...' into current page")
        
        // Execute JavaScript to find and paste into text field
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let script = JavaScriptProvider.pasteAndSubmitScript(prompt: prompt, for: self.service)
            self.webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("PASTE ERROR \(self.service.name): \(error)")
                } else {
                    print("PASTE RESULT \(self.service.name): \(result ?? "unknown")")
                    
                    // For Perplexity, lightly suppress sidebar expansion
                    if self.service.name == "Perplexity" {
                        // Brief sidebar suppression
                        self.suppressPerplexitySidebar()
                    }
                }
            }
        }
    }
    
    private func suppressPerplexitySidebar() {
        webView.evaluateJavaScript("""
            console.log('SIDEBAR DEBUG: Starting comprehensive sidebar analysis...');
            
            // First, let's find all potential sidebar elements
            const allSidebarElements = {
                'group/sidebar': document.querySelector('.group\\/sidebar'),
                'group/sidebar-menu': document.querySelector('.group\\/sidebar-menu'),
                'sidebar-testid': document.querySelector('[data-testid="sidebar"]'),
                'width216px': document.querySelector('div[style*="width:216px"]'),
                'width200px': document.querySelector('div[style*="width:200px"]'),
                'pointer-events-none': document.querySelector('.pointer-events-none.absolute.inset-y-0')
            };
            
            console.log('SIDEBAR DEBUG: Found elements:', allSidebarElements);
            
            // Log initial state of all elements
            Object.entries(allSidebarElements).forEach(([name, element]) => {
                if (element) {
                    const style = window.getComputedStyle(element);
                    console.log(`SIDEBAR DEBUG: ${name} initial state:`, {
                        opacity: style.opacity,
                        transform: style.transform,
                        visibility: style.visibility,
                        pointerEvents: style.pointerEvents,
                        className: element.className,
                        style: element.getAttribute('style')
                    });
                }
            });
            
            // Function to log current state of all sidebar elements
            const logSidebarState = (reason) => {
                console.log(`SIDEBAR DEBUG: State check (${reason}):`);
                Object.entries(allSidebarElements).forEach(([name, element]) => {
                    if (element) {
                        const style = window.getComputedStyle(element);
                        const isVisible = style.opacity !== '0' && style.visibility !== 'hidden';
                        console.log(`  ${name}: opacity=${style.opacity}, visible=${isVisible}, transform=${style.transform}`);
                    }
                });
            };
            
            // Monitor the main sidebar container
            const mainSidebar = allSidebarElements['group/sidebar'];
            if (mainSidebar) {
                console.log('SIDEBAR DEBUG: Setting up monitoring on main sidebar');
                
                // Set up mutation observer
                const observer = new MutationObserver((mutations) => {
                    mutations.forEach((mutation) => {
                        console.log('SIDEBAR DEBUG: Mutation detected:', {
                            type: mutation.type,
                            attributeName: mutation.attributeName,
                            target: mutation.target.className,
                            oldValue: mutation.oldValue
                        });
                        
                        if (mutation.attributeName === 'class') {
                            console.log('SIDEBAR DEBUG: Class changed from', mutation.oldValue, 'to', mutation.target.className);
                        }
                        
                        logSidebarState('mutation detected');
                    });
                });
                
                // Observe with detailed options
                observer.observe(mainSidebar, {
                    attributes: true,
                    subtree: true,
                    attributeOldValue: true,
                    attributeFilter: ['style', 'class']
                });
                
                // Periodic state logging
                let checkCount = 0;
                const intervalId = setInterval(() => {
                    checkCount++;
                    logSidebarState(`periodic check #${checkCount}`);
                }, 500);
                
                // Clean up after 10 seconds
                setTimeout(() => {
                    console.log('SIDEBAR DEBUG: Cleaning up monitoring');
                    observer.disconnect();
                    clearInterval(intervalId);
                }, 10000);
            } else {
                console.log('SIDEBAR DEBUG: No main sidebar found to monitor');
            }
        """)
    }
}

class ClaudeService: WebService {
    let webView: WKWebView
    let service: AIService
    
    init(webView: WKWebView, service: AIService) {
        self.webView = webView
        self.service = service
    }

    func executePrompt(_ prompt: String) {
        executePrompt(prompt, replyToAll: false)
    }
    
    func executePrompt(_ prompt: String, replyToAll: Bool) {
        guard case .clipboardPaste(let baseURL) = service.activationMethod else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(prompt, forType: .string)
        
        if let url = URL(string: baseURL) {
            webView.load(URLRequest(url: url))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            let script = JavaScriptProvider.claudePasteScript(prompt: prompt)
            self.webView.evaluateJavaScript(script)
        }
    }
}

// MARK: - ServiceManager

class ServiceManager: NSObject, ObservableObject {
    @Published var activeServices: [AIService] = []
    @Published var sharedPrompt: String = ""
    @Published var replyToAll: Bool = true
    @Published var loadingStates: [String: Bool] = [:]  // Track loading state per service (for UI only)
    @Published var areAllServicesLoaded: Bool = false  // Replaces allServicesDidLoad notification
    let focusInputPublisher = PassthroughSubject<Void, Never>()  // Replaces focusUnifiedInput notification
    var webServices: [String: WebService] = [:]
    private let processPool = WKProcessPool.shared  // Critical optimization
    
    // Track BrowserViewControllers for delegate handoff
    var browserViewControllers: [String: BrowserViewController] = []
    
    
    // Thread-safe shared prompt execution state across all ServiceManager instances
    private static let globalStateQueue = DispatchQueue(label: "com.hyperchat.servicemanager.globalstate")
    private static var _globalIsFirstSubmit: Bool = true
    private var isFirstSubmit: Bool {
        get { 
            ServiceManager.globalStateQueue.sync { ServiceManager._globalIsFirstSubmit }
        }
        set { 
            ServiceManager.globalStateQueue.sync { ServiceManager._globalIsFirstSubmit = newValue }
        }
    }
    private var perplexityInitialLoadComplete: Bool = false  // Track if Perplexity has completed initial load
    private var lastAttemptedURLs: [WKWebView: URL] = [:]  // Track last attempted URL per WebView
    // Thread-safe state management
    private let stateQueue = DispatchQueue(label: "com.hyperchat.servicemanager.state", qos: .userInitiated)
    private var serviceLoadingQueue: [AIService] = []  // Queue for sequential loading
    private var currentlyLoadingService: String? = nil  // Track which service is currently being loaded
    private var isForceReloading: Bool = false  // Track if we're in force reload mode
    private var loadedServicesCount: Int = 0  // Track how many services have finished loading
    private var hasNotifiedAllServicesLoaded: Bool = false  // Prevent duplicate notifications
    
    // Cleanup state tracking
    private var isCleaningUp = false
    private let instanceId = UUID().uuidString.prefix(8)
    
    override init() {
        super.init()
        
        let address = Unmanaged.passUnretained(self).toOpaque()
        print("🟢 [\(Date().timeIntervalSince1970)] ServiceManager INIT \(instanceId) at \(address)")
        
        // Initialize logging configuration for minimal output
        LoggingSettings.shared.setMinimalLogging()
        
        // Log ServiceManager creation for debugging
        if LoggingSettings.shared.debugPrompts {
            WebViewLogger.shared.log("🚀 ServiceManager created - globalIsFirstSubmit: \(isFirstSubmit)", for: "system", type: .info)
        }
        
        setupServices()
        registerManager()
    }
    
    deinit {
        print("🔴 [\(Date().timeIntervalSince1970)] ServiceManager DEINIT \(instanceId) starting cleanup")
        
        // Wrap all cleanup in autoreleasepool to ensure WebKit's autoreleased objects
        // are released immediately, preventing over-release crashes
        autoreleasepool {
            isCleaningUp = true
            
            // Clean up all WebViews
            print("🧹 [\(Date().timeIntervalSince1970)] Cleaning up \(webServices.count) WebViews")
            for (serviceId, webService) in webServices {
                print("🧹 [\(Date().timeIntervalSince1970)] Cleaning up WebView for \(serviceId)")
                let webView = webService.webView
                
                // Stop any ongoing loads
                webView.stopLoading()
                
                // Remove all JavaScript message handlers
                webView.configuration.userContentController.removeAllUserScripts()
                
                // Note: Script message handlers are now removed in windowWillClose
                // to ensure they're cleaned up before deallocation begins
                
                // Clear delegates
                webView.navigationDelegate = nil
                webView.uiDelegate = nil
                
                // Remove from superview
                webView.removeFromSuperview()
            }
            
            // Clear all references
            webServices.removeAll()
            activeServices.removeAll()
            loadingStates.removeAll()
            serviceLoadingQueue.removeAll()
            
            // Remove from global managers list by clearing weak references
            ServiceManager.allManagers = ServiceManager.allManagers.filter { $0.manager != nil && $0.manager !== self }
            
            print("✅ [\(Date().timeIntervalSince1970)] ServiceManager DEINIT \(instanceId) cleanup complete")
        }
    }
    
    private func setupServices() {
        // Sort services by their order property to ensure correct loading sequence
        let sortedServices = defaultServices.filter { $0.enabled }.sorted { $0.order < $1.order }
        
        for service in sortedServices {
            let webView = WebViewFactory.shared.createWebView(for: service)
            
            // Set ServiceManager as navigation delegate for sequential loading
            webView.navigationDelegate = self
            webView.uiDelegate = self
            
            let webService: WebService
            switch service.activationMethod {
            case .urlParameter:
                webService = URLParameterService(webView: webView, service: service)
            case .clipboardPaste:
                webService = ClaudeService(webView: webView, service: service)
            }
            
            webServices[service.id] = webService
            activeServices.append(service)
            loadingStates[service.id] = false
            
            // Add to loading queue for sequential loading
            serviceLoadingQueue.append(service)
        }
        
        // Start loading the first service
        loadNextServiceFromQueue()
    }
    
    private func loadNextServiceFromQueue(forceReload: Bool = false) {
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
        
        // Use isForceReloading flag if no explicit forceReload parameter provided
        let shouldForceReload = forceReload || isForceReloading
        
        // Get the next service to load
        let service = serviceLoadingQueue.removeFirst()
        
        // Get the webView for this service
        guard let webService = webServices[service.id] else { 
            print("❌ No webService found for \(service.id)")
            // Try loading the next one
            loadNextServiceFromQueue()
            return 
        }
        let webView = webService.webView
        
        // Mark which service we're loading
        currentlyLoadingService = service.id
        print("🔄 Loading service from queue: \(service.name)")
        
        // Load the service
        loadDefaultPage(for: service, webView: webView, forceReload: shouldForceReload)
    }
    
    private func loadDefaultPage(for service: AIService, webView: WKWebView, forceReload: Bool = false) {
        // Get the expected home URL for this service
        let expectedHomeURL: String
        if let config = ServiceConfigurations.config(for: service.id) {
            expectedHomeURL = config.homeURL
        } else if service.id == "claude" {
            expectedHomeURL = "https://claude.ai"
        } else {
            return
        }
        
        // Check if WebView is already at the home URL or loading it
        if !forceReload {
            if webView.isLoading {
                print("⏭️ \(service.name): Skipping default page load - already loading")
                return
            }
            
            if let currentURL = webView.url?.absoluteString {
                // Check if already at home URL or has query params
                if currentURL.hasPrefix(expectedHomeURL) || currentURL.contains("?q=") {
                    print("⏭️ \(service.name): Skipping default page load - already at correct URL")
                    return
                }
            }
        } else {
            print("🔄 \(service.name): Force reloading to home URL")
            // When force reload is requested, always reload regardless of current URL
            // This ensures "new chat" button always creates a fresh session
        }
        
        // Update loading state
        loadingStates[service.id] = true
        
        let defaultURL: String
        
        // Use ServiceConfiguration for URL parameter services
        if let config = ServiceConfigurations.config(for: service.id) {
            defaultURL = config.homeURL
        } else {
            // Fallback for services without config (e.g., Claude if not using URL params)
            switch service.id {
            case "claude":
                defaultURL = "https://claude.ai"
            default:
                return
            }
        }
        
        if let url = URL(string: defaultURL) {
            var request = URLRequest(url: url)
            // Add headers to prevent loading conflicts
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            // User-Agent is already set on the webView itself, no need to set it here
            
            // Add minimal delay to prevent race conditions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                // Double-check before loading in case state changed (unless force reloading)
                if forceReload || (!webView.isLoading && webView.url?.absoluteString.contains("?q=") != true) {
                    webView.load(request)
                    
                    // Log service loads for debugging
                    if service.id == "perplexity" {
                        WebViewLogger.shared.log("🔵 Perplexity: Starting default page load - \(defaultURL)", for: "perplexity", type: .info)
                    }
                }
            }
        }
    }
    
    func executePrompt(_ prompt: String, replyToAll: Bool = false) {
        if LoggingSettings.shared.debugPrompts {
            WebViewLogger.shared.log("🔄 executePrompt called - replyToAll: \(replyToAll), services: \(activeServices.map { $0.id }.joined(separator: ", "))", for: "system", type: .info)
        }
        
        // Execute prompt on all services
        for service in activeServices {
            if let webService = webServices[service.id] {
                if replyToAll {
                    // Reply to All mode: immediate execution with clipboard paste
                    webService.executePrompt(prompt, replyToAll: true)
                } else {
                    // New Chat mode: use URL navigation with minimal delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        webService.executePrompt(prompt, replyToAll: false)
                    }
                }
            }
        }
        
        // Refocus the prompt input field after a delay to ensure paste operations complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            focusInputPublisher.send()
        }
    }
    
    func executeSharedPrompt() {
        guard !sharedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let promptToExecute = sharedPrompt // Store the prompt before clearing
        
        // Use "new chat" mode for first submit, then switch to "reply to all"
        let useReplyToAll = !isFirstSubmit && replyToAll
        
        // Debug logging for prompt execution
        if LoggingSettings.shared.debugPrompts {
            WebViewLogger.shared.log("📝 Executing prompt - isFirstSubmit: \(isFirstSubmit), replyToAll: \(replyToAll), useReplyToAll: \(useReplyToAll), windowCount: \(getAllServiceManagers().count)", for: "system", type: .info)
        }
        
        if useReplyToAll {
            // Reply to All Mode: Paste into current pages immediately
            executePrompt(promptToExecute, replyToAll: true)
            // Clear the prompt after sending
            sharedPrompt = ""
        } else {
            // New Chat Mode: Navigate directly to URL with query parameters
            // Clear the prompt immediately for UI feedback
            sharedPrompt = ""
            
            // Execute prompt immediately - no need to reload first
            executePrompt(promptToExecute, replyToAll: false)
        }
        
        // After first submit, mark as no longer first
        if isFirstSubmit {
            isFirstSubmit = false
            // Also update the UI to show we're now in reply to all mode
            replyToAll = true
            
            if LoggingSettings.shared.debugPrompts {
                WebViewLogger.shared.log("✅ First submit completed - switching to reply-to-all mode", for: "system", type: .info)
            }
        }
    }
    
    func reloadAllServices() {
        print("🔥 reloadAllServices() called from: \(Thread.callStackSymbols[1])")
        
        // Clear and repopulate the loading queue
        serviceLoadingQueue.removeAll()
        
        // Sort services by their order property to ensure correct loading sequence
        let sortedServices = activeServices.sorted { $0.order < $1.order }
        serviceLoadingQueue = sortedServices
        
        // Reset to first submit mode after reload
        isFirstSubmit = true
        replyToAll = true  // Reset UI to default state
        
        // Reset loading tracking for the loading overlay
        loadedServicesCount = 0
        hasNotifiedAllServicesLoaded = false
        
        // Set force reload mode
        isForceReloading = true
        
        // Start loading the first service with force reload
        loadNextServiceFromQueue(forceReload: true)
    }
    
    func resetThreadState() {
        // Reset to first submit mode to create new threads
        isFirstSubmit = true
        replyToAll = true  // Reset UI to default state
        
        // Don't clear the prompt here - let the UI handle it after submission
        
        // Don't reload all services - this was causing unwanted reloads after GET param navigation
        // reloadAllServices()
    }
    
    func startNewThreadWithPrompt() {
        // Store the current prompt (may be empty)
        let promptToExecute = sharedPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clear the prompt immediately for UI feedback
        sharedPrompt = ""
        
        // Reset to first submit mode for new threads
        isFirstSubmit = true
        // Don't set replyToAll here - we want URL navigation, not paste
        
        // CRITICAL: Clear all loading state to prevent queue processing
        serviceLoadingQueue.removeAll()
        currentlyLoadingService = nil
        
        // Mark all services as loaded to prevent sequential loading from continuing
        hasNotifiedAllServicesLoaded = true
        
        // Navigate each service to a new thread with the prompt as URL parameter
        for (serviceId, webService) in webServices {
            guard let service = activeServices.first(where: { $0.id == serviceId }),
                  let config = ServiceConfigurations.config(for: serviceId) else { continue }
            
            let urlString: String
            if promptToExecute.isEmpty {
                // No prompt - just load the home page
                urlString = config.homeURL
            } else {
                // Build URL with query parameters
                urlString = config.buildURL(with: promptToExecute)
            }
            
            // Navigate directly to the URL
            if let url = URL(string: urlString) {
                print("🔗 \(service.name): New thread navigation to: \(urlString)")
                webService.webView.load(URLRequest(url: url))
            }
        }
        
        // Don't reset loading tracking - we're not using the queue mechanism here
        // This prevents the cascade of reloads after navigation
    }
    
    
    func resetForNewPrompt() {
        // Don't stop loading during normal operation as it causes -999 errors
        // Only stop if absolutely necessary
    }
    
    
    // MARK: - Window Hibernation Support
    
    func pauseAllWebViews() {
        for (_, webService) in webServices {
            let webView = webService.webView
            
            // Pause execution by injecting JavaScript
            let pauseScript = JavaScriptProvider.hibernationPauseScript()
            webView.evaluateJavaScript(pauseScript)
            
            // Stop any ongoing loads
            if webView.isLoading {
                webView.stopLoading()
            }
            
            // Hide the WebView to prevent rendering
            webView.isHidden = true
        }
    }
    
    func resumeAllWebViews() {
        for (_, webService) in webServices {
            let webView = webService.webView
            
            // Resume execution by restoring JavaScript functions
            let resumeScript = JavaScriptProvider.hibernationResumeScript()
            webView.evaluateJavaScript(resumeScript)
            
            // Show the WebView
            webView.isHidden = false
            
            // Optionally trigger a small scroll to force re-render
            webView.evaluateJavaScript("window.scrollBy(0, 1); window.scrollBy(0, -1);")
        }
    }
}

extension WKProcessPool {
    static let shared = WKProcessPool()
}

// MARK: - Global ServiceManager Tracking
extension ServiceManager {
    private static var allManagers: [WeakServiceManagerWrapper] = []
    
    private class WeakServiceManagerWrapper {
        weak var manager: ServiceManager?
        init(_ manager: ServiceManager) {
            self.manager = manager
        }
    }
    
    private func registerManager() {
        ServiceManager.allManagers.append(WeakServiceManagerWrapper(self))
        // Clean up nil references
        ServiceManager.allManagers = ServiceManager.allManagers.filter { $0.manager != nil }
    }
    
    private func getAllServiceManagers() -> [ServiceManager] {
        ServiceManager.allManagers.compactMap { $0.manager }
    }
    
    private func findServiceId(for webView: WKWebView) -> String? {
        for (serviceId, webService) in webServices {
            if webService.webView == webView {
                return serviceId
            }
        }
        return nil
    }
    
    private func updateLoadingState(for serviceId: String, isLoading: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.loadingStates[serviceId] = isLoading
        }
    }
}

// MARK: - WKNavigationDelegate for ServiceManager

extension ServiceManager: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Defensive check: Ensure we're not cleaning up
        guard !isCleaningUp else {
            print("⚠️ [\(Date().timeIntervalSince1970)] Ignoring didFail - ServiceManager is cleaning up")
            return
        }
        
        let nsError = error as NSError
        print("ERROR WebView navigation failed: \(nsError.code) - \(nsError.localizedDescription)")
        
        // Forward to BrowserView's delegate method for UI updates
        for (serviceId, webService) in webServices {
            if webService.webView == webView {
                // Navigation delegate will be handled by BrowserViewController
                
                // Mark as not loading
                loadingStates[serviceId] = false
                
                // Check if this was the service we were waiting for
                if serviceId == currentlyLoadingService && !hasNotifiedAllServicesLoaded {
                    print("❌ Service \(serviceId) failed during navigation - proceeding to next service")
                    currentlyLoadingService = nil
                    
                    // Continue with the next service after a small delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.loadNextServiceFromQueue()
                    }
                }
                
                // Count this as a finished service (even though it failed)
                if !hasNotifiedAllServicesLoaded {
                    loadedServicesCount += 1
                    print("📊 Service failed but counted as finished: \(serviceId) (\(loadedServicesCount)/\(activeServices.count))")
                    
                    // Check if all services have finished (loaded or failed)
                    if loadedServicesCount >= activeServices.count && serviceLoadingQueue.isEmpty && currentlyLoadingService == nil {
                        hasNotifiedAllServicesLoaded = true
                        print("🎉 All services have finished (some may have failed)!")
                        areAllServicesLoaded = true
                    }
                }
                break
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // Defensive check: Ensure we're not cleaning up
        guard !isCleaningUp else {
            print("⚠️ [\(Date().timeIntervalSince1970)] Ignoring didFailProvisionalNavigation - ServiceManager is cleaning up")
            return
        }
        
        let nsError = error as NSError
        
        // Special handling for -999 errors (NSURLErrorCancelled)
        if nsError.code == NSURLErrorCancelled {
            print("⚠️ Navigation cancelled (error -999) - this is usually harmless")
            
            // Find the service for better logging
            var serviceName = "Unknown"
            for (serviceId, webService) in webServices {
                if webService.webView == webView {
                    if let service = activeServices.first(where: { $0.id == serviceId }) {
                        serviceName = service.name
                    }
                    break
                }
            }
            
            print("📍 \(serviceName): Navigation was cancelled, likely due to a new navigation request")
            
            // Don't treat cancellations as failures - just return
            return
        }
        
        print("ERROR WebView provisional navigation failed: \(nsError.code) - \(nsError.localizedDescription)")
        
        // Forward to BrowserView's delegate method for UI updates
        for (serviceId, webService) in webServices {
            if webService.webView == webView {
                // Navigation delegate will be handled by BrowserViewController
                
                // Mark as not loading
                loadingStates[serviceId] = false
                
                // Check if this was the service we were waiting for
                if serviceId == currentlyLoadingService && !hasNotifiedAllServicesLoaded {
                    print("❌ Service \(serviceId) failed to load - proceeding to next service anyway")
                    currentlyLoadingService = nil
                    
                    // Continue with the next service after a small delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.loadNextServiceFromQueue()
                    }
                }
                
                // Don't count as finished if this was a query parameter URL that failed (likely due to cancellation)
                if nsError.code == NSURLErrorCancelled,
                   let failedURL = lastAttemptedURLs[webView],
                   failedURL.absoluteString.contains("?q=") {
                    print("⚠️ Ignoring cancelled navigation for query URL: \(failedURL.absoluteString)")
                    return
                }
                
                // Count this as a finished service (even though it failed)
                if !hasNotifiedAllServicesLoaded {
                    loadedServicesCount += 1
                    print("📊 Service failed but counted as finished: \(serviceId) (\(loadedServicesCount)/\(activeServices.count))")
                    
                    // Check if all services have finished (loaded or failed)
                    if loadedServicesCount >= activeServices.count && serviceLoadingQueue.isEmpty && currentlyLoadingService == nil {
                        hasNotifiedAllServicesLoaded = true
                        print("🎉 All services have finished (some may have failed)!")
                        areAllServicesLoaded = true
                    }
                }
                break
            }
        }
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // Forward to BrowserView's delegate method for UI updates
        for (_, webService) in webServices {
            if webService.webView == webView {
                // Navigation delegate will be handled by BrowserViewController
                break
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Check if we're cleaning up
        if isCleaningUp {
            print("⚠️ [\(Date().timeIntervalSince1970)] Navigation delegate called during cleanup - didFinish")
            return
        }
        
        let urlString = webView.url?.absoluteString ?? "unknown"
        print("SUCCESS WebView loaded successfully: \(urlString)")
        
        // Forward to BrowserView's delegate method for UI updates
        for (serviceId, webService) in webServices {
            if webService.webView == webView {
                // Navigation delegate will be handled by BrowserViewController
                
                // Update loading state
                loadingStates[serviceId] = false
                
                // Check if this was the service we were waiting for
                if serviceId == currentlyLoadingService && !hasNotifiedAllServicesLoaded {
                    print("✅ Service \(serviceId) finished loading - proceeding to next service")
                    currentlyLoadingService = nil
                    
                    // Hand off navigation delegate to BrowserViewController if available
                    if let browserViewController = browserViewControllers[serviceId] {
                        browserViewController.takeOverNavigationDelegate()
                    }
                    
                    // Load the next service after a small delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.loadNextServiceFromQueue()
                    }
                }
                
                // Track service as loaded if this is initial load (not a query URL)
                if !urlString.contains("?q=") && !hasNotifiedAllServicesLoaded {
                    loadedServicesCount += 1
                    print("📊 Service loaded: \(serviceId) (\(loadedServicesCount)/\(activeServices.count))")
                    
                    // If this wasn't the currently loading service, still hand off delegate
                    // This handles cases where services load out of order or were pre-loaded
                    if serviceId != currentlyLoadingService, let browserViewController = browserViewControllers[serviceId] {
                        browserViewController.takeOverNavigationDelegate()
                    }
                    
                    // Check if all services have loaded
                    if loadedServicesCount >= activeServices.count && serviceLoadingQueue.isEmpty && currentlyLoadingService == nil {
                        hasNotifiedAllServicesLoaded = true
                        print("🎉 All services have finished loading!")
                        areAllServicesLoaded = true
                    }
                }
                break
            }
        }
        
        // Handle Perplexity successful load
        if urlString.contains("perplexity.ai") {
            WebViewLogger.shared.log("✅ Perplexity: Page loaded successfully - \(urlString)", for: "perplexity", type: .info)
            
            // Mark Perplexity as ready to accept queries
            if !urlString.contains("?q=") {
                perplexityInitialLoadComplete = true
                WebViewLogger.shared.log("✅ Perplexity: Initial load complete, ready for queries", for: "perplexity", type: .info)
                
                // Return focus to main prompt bar after Perplexity loads
                // Wait 2 seconds to ensure Perplexity's JavaScript has executed
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    print("🎯 Returning focus to main prompt bar after Perplexity load")
                    focusInputPublisher.send()
                }
            }
            
            // Update loading state
            if let service = activeServices.first(where: { $0.id == "perplexity" }) {
                loadingStates[service.id] = false
            }
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Defensive check: Ensure we're not cleaning up
        guard !isCleaningUp else {
            print("⚠️ [\(Date().timeIntervalSince1970)] Ignoring decidePolicyFor - ServiceManager is cleaning up")
            decisionHandler(.cancel)
            return
        }
        
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        
        // Allow special schemes
        let scheme = url.scheme?.lowercased() ?? ""
        if ["javascript", "data", "about", "blob"].contains(scheme) {
            decisionHandler(.allow)
            return
        }
        
        // Find which service this webView belongs to
        var allowedHosts: [String] = []
        for (serviceId, webService) in webServices {
            if webService.webView == webView {
                // Get the allowed domains for this service
                switch serviceId {
                case "google":
                    allowedHosts = ["google.com", "gstatic.com", "googleapis.com", "googleusercontent.com"]
                case "perplexity":
                    allowedHosts = ["perplexity.ai"]
                case "chatgpt":
                    allowedHosts = ["chatgpt.com", "openai.com", "oaistatic.com", "oaiusercontent.com"]
                case "claude":
                    allowedHosts = ["claude.ai", "anthropic.com"]
                default:
                    break
                }
                break
            }
        }
        
        // If we can't determine the allowed hosts, allow the navigation
        if allowedHosts.isEmpty {
            decisionHandler(.allow)
            return
        }
        
        let currentHost = url.host?.lowercased() ?? ""
        
        // Allow navigation within the same service domain or subdomains
        let isAllowedHost = allowedHosts.contains { allowedHost in
            currentHost == allowedHost || currentHost.hasSuffix(".\(allowedHost)")
        }
        
        if isAllowedHost {
            decisionHandler(.allow)
            return
        }
        
        // For external links, open in default browser
        if navigationAction.navigationType == .linkActivated {
            print("🔗 Opening external link in browser: \(url.absoluteString)")
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        
        // Allow other types of navigation (redirects, form submissions, etc.)
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Defensive check: Ensure we're not cleaning up
        guard !isCleaningUp else {
            print("⚠️ [\(Date().timeIntervalSince1970)] Ignoring didStartProvisionalNavigation - ServiceManager is cleaning up")
            return
        }
        
        let urlString = webView.url?.absoluteString ?? "unknown"
        print("🔄 WebView started loading: \(urlString)")
        
        // Forward to BrowserView's delegate method for UI updates
        for (_, webService) in webServices {
            if webService.webView == webView {
                // Navigation delegate will be handled by BrowserViewController
                break
            }
        }
        
        // Track the URL being loaded
        if let url = webView.url {
            lastAttemptedURLs[webView] = url
        }
        
        // Update loading state for Perplexity
        if urlString.contains("perplexity.ai"),
           let service = activeServices.first(where: { $0.id == "perplexity" }) {
            loadingStates[service.id] = true
            WebViewLogger.shared.log("🔄 Perplexity: Started loading - \(urlString)", for: "perplexity", type: .info)
        }
        
        // Check if this is the service we're expecting to load
        if let loadingServiceId = currentlyLoadingService {
            // Find which service this webView belongs to
            var foundService: AIService? = nil
            for (serviceId, webService) in webServices {
                if webService.webView == webView {
                    foundService = activeServices.first { $0.id == serviceId }
                    break
                }
            }
            
            // Just log that loading started - don't process queue yet
            if let service = foundService, service.id == loadingServiceId {
                print("✅ Service \(service.name) started loading successfully")
                // Don't clear currentlyloadingService or call loadNextServiceFromQueue here
                // Wait for didFinish to ensure the service fully loads before starting the next one
            }
        }
    }
    
    // Handle WebView process crashes
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard let serviceId = findServiceId(for: webView) else { return }
        
        print("⚠️ WebView process crashed for service: \(serviceId)")
        WebViewLogger.shared.log("⚠️ WebView process crashed, attempting recovery", for: serviceId, type: .error)
        
        // Mark service as not loading to prevent hanging (thread-safe)
        updateLoadingState(for: serviceId, isLoading: false)
        
        // Reload the service with a small delay to allow process cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            if let service = self.activeServices.first(where: { $0.id == serviceId }),
               let webService = self.webServices[serviceId] {
                self.loadDefaultPage(for: service, webView: webService.webView, forceReload: true)
                WebViewLogger.shared.log("🔄 WebView recovered from crash", for: serviceId, type: .info)
            }
        }
    }
}

// MARK: - WKUIDelegate for ServiceManager

extension ServiceManager: WKUIDelegate {
    // Handle JavaScript alerts
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        // Defensive check: Always call completion handler even during cleanup
        defer { completionHandler() }
        
        guard !isCleaningUp else {
            print("⚠️ [\(Date().timeIntervalSince1970)] Ignoring JavaScript alert - ServiceManager is cleaning up")
            return
        }
    }
} 
