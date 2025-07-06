/// ServiceManager.swift - Core AI Service Orchestration
///
/// This file manages all WebView instances for AI services (ChatGPT, Claude, Perplexity, Google).
/// It coordinates prompt execution, handles sequential loading, and manages window-specific state.
///
/// Key responsibilities:
/// - Creates and manages WKWebView instances for each AI service
/// - Handles sequential loading to prevent memory spikes and race conditions
/// - Coordinates prompt execution across all active services
/// - Manages reply-to-all vs new-chat modes
/// - Implements window hibernation support for resource efficiency
///
/// Related files:
/// - `OverlayController.swift`: Creates ServiceManager instances for each window
/// - `AppDelegate.swift`: Triggers prompt execution via notifications
/// - `BrowserViewController.swift`: Displays the WebViews created here
/// - `WebViewFactory.swift`: Creates properly configured WKWebView instances
/// - `ServiceConfigurations.swift`: Defines URL patterns for each service
/// - `JavaScriptProvider.swift`: Provides JavaScript for service automation
///
/// Threading model:
/// - Main thread: All UI operations and WebView interactions
/// - globalStateQueue: Synchronizes shared state across ServiceManager instances
/// - stateQueue: Manages internal state for sequential loading

import Foundation
import WebKit
import SwiftUI
import Combine

// MARK: - Service Configuration

/// Defines the timing delays used throughout the service loading and prompt execution.
/// These values are carefully tuned to balance responsiveness with reliability.
private enum ServiceTimings {
    /// Delay before pasting into Claude to ensure page is fully loaded.
    /// Claude's React app requires ~1.5 seconds to initialize all JavaScript handlers.
    static let claudePasteDelay: TimeInterval = 1.5
    
    /// Delay after prompt execution to refocus the input field.
    /// Ensures paste operations complete before returning focus.
    static let promptRefocusDelay: TimeInterval = 1.5
    
    /// Delay after service loads to check if query was processed.
    /// Used for debugging URL parameter services.
    static let queryCheckDelay: TimeInterval = 2.0
    
    /// Delay between loading services sequentially.
    /// Prevents WebKit race conditions and GPU process conflicts.
    static let serviceLoadingDelay: TimeInterval = 0.5
    
    /// Delay before loading a service to prevent race conditions.
    /// WebKit needs this minimal delay between certain operations.
    static let webKitSafetyDelay: TimeInterval = 0.01
    
    /// Delay before executing paste operations.
    /// Ensures page JavaScript is ready to receive input.
    static let pasteExecutionDelay: TimeInterval = 1.0
    
    /// Delay after WebView crash before attempting recovery.
    /// Allows WebKit process cleanup before reload.
    static let crashRecoveryDelay: TimeInterval = 1.0
    
    /// Delay for gentle window activation.
    /// Prevents WebView disruption when making window key.
    static let windowActivationDelay: TimeInterval = 0.1
}

/// Defines how a service accepts prompt input.
/// Services either accept URL parameters or require clipboard paste automation.
enum ServiceActivationMethod {
    /// Service accepts prompts via URL query parameters (e.g., ?q=prompt)
    case urlParameter(baseURL: String, parameter: String)
    
    /// Service requires clipboard paste automation (e.g., Claude)
    case clipboardPaste(baseURL: String)
}

/// Represents an AI service that can be displayed in the app.
/// Each service runs in its own WKWebView with isolated process and cookies.
struct AIService {
    /// Unique identifier used throughout the app (e.g., "chatgpt", "claude")
    var id: String
    
    /// Display name shown in the UI (e.g., "ChatGPT", "Claude")
    var name: String
    
    /// Asset catalog name for the service's icon
    var iconName: String
    
    /// How this service accepts prompt input (URL params vs clipboard paste)
    var activationMethod: ServiceActivationMethod
    
    /// Whether this service is currently active and should be displayed
    var enabled: Bool
    
    /// Display order in the UI (1 = leftmost, higher numbers = further right)
    var order: Int
    
    /// Dynamic favicon URL extracted from the website
    var faviconURL: URL?
}

/// Default service configurations.
/// These values are used when no saved settings exist.
/// URLs and parameters come from ServiceConfigurations.
let defaultServices = [
    AIService(
        id: "google",
        name: "Google",
        iconName: "google-icon",
        activationMethod: .urlParameter(
            baseURL: ServiceConfigurations.google.baseURL,
            parameter: ServiceConfigurations.google.queryParam
        ),
        enabled: true,
        order: 3,  // Third position from left
        faviconURL: nil
    ),
    AIService(
        id: "perplexity",
        name: "Perplexity",
        iconName: "perplexity-icon",
        activationMethod: .urlParameter(
            baseURL: ServiceConfigurations.perplexity.baseURL,
            parameter: ServiceConfigurations.perplexity.queryParam
        ),
        enabled: true,
        order: 2,
        faviconURL: nil
    ),
    AIService(
        id: "chatgpt",
        name: "ChatGPT",
        iconName: "chatgpt-icon",
        activationMethod: .urlParameter(
            baseURL: ServiceConfigurations.chatGPT.baseURL,
            parameter: ServiceConfigurations.chatGPT.queryParam
        ),
        enabled: true,
        order: 1,
        faviconURL: nil
    ),
    AIService(
        id: "claude",
        name: "Claude",
        iconName: "claude-icon",
        activationMethod: .clipboardPaste(
            baseURL: ServiceConfigurations.claude.baseURL
        ),
        enabled: false,
        order: 4,
        faviconURL: nil
    )
]

// MARK: - WebService Protocol and Implementations

/// Protocol defining the interface for all AI service implementations.
/// Each service must provide prompt execution and WebView access.

protocol WebService {
    /// Executes a prompt using the service's default mode.
    /// Delegates to the replyToAll variant with false parameter.
    func executePrompt(_ prompt: String)
    
    /// Executes a prompt with specific mode control.
    /// - Parameters:
    ///   - prompt: The text to send to the AI service
    ///   - replyToAll: If true, pastes into existing chat; if false, creates new chat
    func executePrompt(_ prompt: String, replyToAll: Bool)
    
    /// The WebView instance displaying this service
    var webView: WKWebView { get }
    
    /// The service configuration for this instance
    var service: AIService { get }
}

/// Handles services that accept prompts via URL parameters.
/// Used by ChatGPT, Perplexity, and Google Search.
///
/// Prompt execution flow:
/// 1. New Chat mode: Navigate to service URL with ?q=prompt parameter
/// 2. Reply to All mode: Use clipboard paste into current page
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
    
    /// Executes a prompt based on the current mode.
    ///
    /// Called by:
    /// - `ServiceManager.executePrompt()` for all URL parameter services
    ///
    /// Execution modes:
    /// - New Chat (replyToAll=false): Navigates to service URL with query parameter
    /// - Reply to All (replyToAll=true): Pastes prompt into current page
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
                DispatchQueue.main.asyncAfter(deadline: .now() + ServiceTimings.queryCheckDelay) {
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
    
    /// Pastes a prompt into the currently loaded page using clipboard automation.
    ///
    /// This method:
    /// 1. Copies the prompt to system clipboard
    /// 2. Waits for page JavaScript to be ready
    /// 3. Executes paste and submit JavaScript from JavaScriptProvider
    /// 4. Handles service-specific post-paste actions (e.g., Perplexity sidebar)
    ///
    /// Used when in Reply to All mode to paste into existing chat sessions.
    private func pastePromptIntoCurrentPage(_ prompt: String) {
        // Copy prompt to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(prompt, forType: .string)
        
        print("PASTE \(service.name): Pasting prompt '\(prompt.prefix(50))...' into current page")
        
        // Execute JavaScript to find and paste into text field
        DispatchQueue.main.asyncAfter(deadline: .now() + ServiceTimings.pasteExecutionDelay) {
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

/// Handles Claude.ai which requires clipboard paste automation.
/// Claude doesn't support URL parameters, so all prompts use paste method.
///
/// Execution flow:
/// 1. Copy prompt to clipboard
/// 2. Navigate to Claude.ai (if not already there)
/// 3. Wait 3 seconds for React app to initialize
/// 4. Execute paste JavaScript from JavaScriptProvider
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
    
    /// Executes a prompt on Claude using clipboard paste.
    /// Claude requires special handling as it doesn't support URL parameters.
    ///
    /// Note: The replyToAll parameter is ignored for Claude as it always uses paste.
    func executePrompt(_ prompt: String, replyToAll: Bool) {
        guard case .clipboardPaste(let baseURL) = service.activationMethod else { 
            print("❌ [Claude] Not a clipboard paste service")
            return 
        }
        
        print("🤖 [Claude] Executing prompt: '\(prompt.prefix(50))...' replyToAll: \(replyToAll)")
        
        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(prompt, forType: .string)
        print("📋 [Claude] Clipboard set success: \(success)")
        
        // Check current URL to decide if we need to navigate
        let currentURL = webView.url?.absoluteString ?? "none"
        print("🌐 [Claude] Current URL: \(currentURL)")
        
        // Check if we need to navigate to Claude
        let needsNavigation = !replyToAll || !currentURL.hasPrefix(baseURL)
        
        if needsNavigation {
            if let url = URL(string: baseURL) {
                print("🔗 [Claude] Navigating to: \(baseURL)")
                webView.load(URLRequest(url: url))
                
                // Only delay when navigating to a new page
                DispatchQueue.main.asyncAfter(deadline: .now() + ServiceTimings.claudePasteDelay) {
                    print("⏰ [Claude] Executing paste script after \(ServiceTimings.claudePasteDelay)s delay (page was loading)")
                    let script = JavaScriptProvider.claudePasteScript(prompt: prompt)
                    self.webView.evaluateJavaScript(script) { result, error in
                        if let error = error {
                            print("❌ [Claude] JavaScript error: \(error)")
                        } else {
                            self.logClaudeDiagnostics(result)
                        }
                    }
                }
            }
        } else {
            print("✅ [Claude] Already at Claude, executing immediately")
            // Execute paste script immediately - no delay!
            let script = JavaScriptProvider.claudePasteScript(prompt: prompt)
            self.webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("❌ [Claude] JavaScript error: \(error)")
                } else {
                    self.logClaudeDiagnostics(result)
                }
            }
        }
    }
    
    /// Parses and logs the diagnostic JSON report from Claude script execution.
    ///
    /// This method extracts diagnostic information from the JavaScript response
    /// to help debug submission issues. It logs:
    /// - Whether the input field was found and which selector worked
    /// - Whether text was successfully inserted
    /// - Whether the Enter key event was dispatched
    /// - Whether a submit button was found (for fallback options)
    /// - Any error messages
    private func logClaudeDiagnostics(_ result: Any?) {
        guard let jsonString = result as? String,
              let jsonData = jsonString.data(using: .utf8) else {
            print("❌ [Claude] Invalid diagnostic response: \(String(describing: result))")
            return
        }
        
        do {
            if let report = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                print("📊 [Claude] DIAGNOSTIC REPORT:")
                print("   └─ Page URL: \(report["pageURL"] ?? "unknown")")
                print("   └─ Input Found: \(report["inputFound"] ?? false)")
                print("   └─ Input Selector: \(report["inputSelector"] ?? "none")")
                print("   └─ Text Inserted: \(report["textInserted"] ?? false)")
                print("   └─ Enter Dispatched: \(report["enterDispatched"] ?? false)")
                print("   └─ Submit Button Found: \(report["submitButtonFound"] ?? false)")
                print("   └─ Submit Button Selector: \(report["submitButtonSelector"] ?? "none")")
                print("   └─ Error: \(report["errorMessage"] ?? "none")")
                print("   └─ Timestamp: \(report["timestamp"] ?? "unknown")")
                
                // Analyze the results
                let inputFound = report["inputFound"] as? Bool ?? false
                let textInserted = report["textInserted"] as? Bool ?? false
                let enterDispatched = report["enterDispatched"] as? Bool ?? false
                let submitButtonFound = report["submitButtonFound"] as? Bool ?? false
                
                if inputFound && textInserted && enterDispatched {
                    print("✅ [Claude] All steps completed successfully but submission may have failed")
                    if submitButtonFound {
                        print("💡 [Claude] Submit button detected - could try clicking it as fallback")
                    }
                } else if !inputFound {
                    print("❌ [Claude] Failed to find input field - check selectors")
                } else if !textInserted {
                    print("❌ [Claude] Failed to insert text - input field may be readonly")
                } else if !enterDispatched {
                    print("❌ [Claude] Enter key event failed - event may be blocked")
                }
            }
        } catch {
            print("❌ [Claude] Failed to parse diagnostic JSON: \(error)")
        }
    }
}

// MARK: - ServiceManager

/// Central orchestrator for all AI service WebViews in a window.
///
/// Each window creates its own ServiceManager instance to ensure WebView isolation.
/// ServiceManagers coordinate through shared global state for prompt execution.
///
/// Key responsibilities:
/// - Creates and manages WebView instances for each AI service
/// - Implements sequential loading to prevent GPU process conflicts
/// - Coordinates prompt execution across all services
/// - Manages reply-to-all vs new-chat mode transitions
/// - Handles WebView crashes and recovery
/// - Supports window hibernation for resource efficiency
///
/// Created by:
/// - `OverlayController.createNormalWindow()` for each new window
/// - `OverlayController.showOverlay()` for the overlay window
///
/// Lifecycle:
/// - Created when window is created
/// - Destroyed when window closes (extensive cleanup in deinit)
/// - Can be hibernated/resumed for inactive windows
class ServiceManager: NSObject, ObservableObject {
    // MARK: - Published Properties (UI State)
    
    /// List of AI services that are currently enabled and displayed.
    /// Observed by ContentView to render service tabs.
    @Published var activeServices: [AIService] = []
    
    /// The current prompt text entered by the user.
    /// Bound to UnifiedInputBar in ContentView.
    @Published var sharedPrompt: String = ""
    
    /// Whether to paste into existing chats (true) or create new chats (false).
    /// Synchronized with UI toggle in UnifiedInputBar.
    @Published var replyToAll: Bool = true
    
    /// Loading state for each service, keyed by service ID.
    /// Used by UI to show loading indicators.
    @Published var loadingStates: [String: Bool] = [:]
    
    /// Whether all services have completed initial loading.
    /// Replaces the old allServicesDidLoad notification pattern.
    @Published var areAllServicesLoaded: Bool = false
    
    // MARK: - Publishers
    
    /// Signals when the prompt input field should regain focus.
    /// Triggered after prompt execution to return focus to input.
    let focusInputPublisher = PassthroughSubject<Void, Never>()
    
    // MARK: - Service Management
    
    /// Map of service ID to WebService implementation.
    /// Each service has either URLParameterService or ClaudeService.
    var webServices: [String: WebService] = [:]
    
    /// Shared process pool for critical WebKit optimization.
    /// NEVER create new WKProcessPool instances - always use this shared one.
    private let processPool = WKProcessPool.shared
    
    /// BrowserViewControllers displaying each service's WebView.
    /// Used for navigation delegate handoff after initial load.
    var browserViewControllers: [String: BrowserViewController] = [:]
    
    
    // MARK: - Global State Management
    
    /// Queue for synchronizing shared state across all ServiceManager instances.
    /// Ensures thread-safe access to global prompt execution state.
    private static let globalStateQueue = DispatchQueue(label: "com.hyperchat.servicemanager.globalstate")
    
    /// Backing storage for global isFirstSubmit flag.
    private static var _globalIsFirstSubmit: Bool = true
    
    /// Tracks whether this is the first prompt submission in the current session.
    ///
    /// State transitions:
    /// - Starts as `true` when app launches or "New Chat" clicked
    /// - Set to `false` after first prompt execution
    /// - Reset to `true` by `resetThreadState()` or `reloadAllServices()`
    ///
    /// Why this matters:
    /// - First submission: Always uses URL navigation (creates new chat threads)
    /// - Subsequent submissions: Uses reply-to-all mode (pastes into existing chats)
    ///
    /// This flag is:
    /// - Shared globally across all ServiceManager instances via thread-safe queue
    /// - Synchronized with `replyToAll` UI toggle in ContentView
    private var isFirstSubmit: Bool {
        get { 
            ServiceManager.globalStateQueue.sync { ServiceManager._globalIsFirstSubmit }
        }
        set { 
            ServiceManager.globalStateQueue.sync { ServiceManager._globalIsFirstSubmit = newValue }
        }
    }
    
    // MARK: - Service Loading State
    
    /// Whether Perplexity has completed its initial page load.
    /// Perplexity requires special handling as it needs to load before accepting URL parameters.
    private var perplexityInitialLoadComplete: Bool = false
    
    /// Maps WebViews to their last attempted URL.
    /// Used to detect navigation cancellations (error -999) for query URLs.
    private var lastAttemptedURLs: [WKWebView: URL] = [:]
    
    /// Queue for managing internal state operations.
    /// Ensures thread-safe access to loading queue and state variables.
    private let stateQueue = DispatchQueue(label: "com.hyperchat.servicemanager.state", qos: .userInitiated)
    
    /// Queue of services waiting to be loaded.
    /// Services are loaded sequentially to prevent WebKit race conditions.
    private var serviceLoadingQueue: [AIService] = []
    
    /// ID of the service currently being loaded.
    /// Nil when no service is loading.
    private var currentlyLoadingService: String? = nil
    
    /// Whether we're performing a force reload of all services.
    /// Set by reloadAllServices() to ensure fresh page loads.
    private var isForceReloading: Bool = false
    
    /// Count of services that have finished loading (successfully or failed).
    /// Used to determine when all services are ready.
    private var loadedServicesCount: Int = 0
    
    /// Whether we've already notified that all services are loaded.
    /// Prevents duplicate notifications and state updates.
    private var hasNotifiedAllServicesLoaded: Bool = false
    
    // MARK: - Cleanup State
    
    /// Whether this ServiceManager is currently being deallocated.
    /// Used to prevent navigation delegate callbacks during cleanup.
    private var isCleaningUp = false
    
    /// Unique identifier for this ServiceManager instance.
    /// Used for debugging lifecycle and memory management.
    private let instanceId = UUID().uuidString.prefix(8)
    
    /// Initializes a new ServiceManager for a window.
    ///
    /// Called by:
    /// - `OverlayController.createNormalWindow()`
    /// - `OverlayController.showOverlay()`
    ///
    /// Initialization steps:
    /// 1. Configure logging settings
    /// 2. Create WebViews for all enabled services
    /// 3. Add services to sequential loading queue
    /// 4. Register this instance for global tracking
    /// 5. Start loading the first service
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
        
        // Listen for service updates from settings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(servicesUpdated),
            name: .servicesUpdated,
            object: nil
        )
        
        // Listen for favicon discoveries
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFaviconFound(_:)),
            name: .faviconFound,
            object: nil
        )
    }
    
    /// Cleans up all WebView resources when the window closes.
    ///
    /// CRITICAL WebKit cleanup requirements:
    /// - Must wrap all cleanup in autoreleasepool
    /// - Must stop loading before removing delegates
    /// - Must clear all JavaScript handlers
    /// - Must remove from superview
    ///
    /// Without proper cleanup:
    /// - WebKit objects can be over-released causing EXC_BAD_ACCESS
    /// - Navigation delegates can be called on deallocated objects
    /// - Memory leaks from retained WebView references
    ///
    /// This cleanup pattern is also used in:
    /// - `OverlayController.cleanupWindowResources()`
    /// - `BrowserViewController.cleanup()`
    deinit {
        print("🔴 [\(Date().timeIntervalSince1970)] ServiceManager DEINIT \(instanceId) starting cleanup")
        
        // Remove notification observer
        NotificationCenter.default.removeObserver(self)
        
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
    
    /// Sets up WebViews for all enabled AI services.
    ///
    /// Called during init to:
    /// 1. Filter and sort services by display order
    /// 2. Create WebView for each service via WebViewFactory
    /// 3. Create appropriate WebService implementation (URL vs Clipboard)
    /// 4. Add services to sequential loading queue
    /// 5. Start loading the first service
    ///
    /// Services are loaded sequentially to prevent:
    /// - GPU process conflicts (multiple WebViews starting simultaneously)
    /// - Memory spikes from parallel loading
    /// - Race conditions in WebKit initialization
    private func setupServices() {
        // Filter out disabled services and sort by display order
        // Order values: ChatGPT=1, Perplexity=2, Google=3, Claude=4
        // This ensures consistent left-to-right display in the UI
        let allServices = SettingsManager.shared.getServices()
        let enabledServices = allServices.filter { service in
            return service.enabled == true
        }
        let sortedServices = enabledServices.sorted { firstService, secondService in
            return firstService.order < secondService.order
        }
        
        for service in sortedServices {
            // Create WebView with proper configuration from WebViewFactory
            let webView = WebViewFactory.shared.createWebView(for: service)
            
            // Set ServiceManager as navigation delegate for sequential loading
            // We'll hand off to BrowserViewController after initial load
            webView.navigationDelegate = self
            webView.uiDelegate = self
            
            // Create appropriate WebService implementation based on activation method
            let webService: WebService
            switch service.activationMethod {
            case .urlParameter:
                webService = URLParameterService(webView: webView, service: service)
                print("📱 Created URLParameterService for: \(service.name)")
            case .clipboardPaste:
                webService = ClaudeService(webView: webView, service: service)
                print("📋 Created ClaudeService for: \(service.name)")
            }
            
            // Store references and initialize state
            webServices[service.id] = webService
            activeServices.append(service)
            loadingStates[service.id] = false
            
            // Add to loading queue for sequential loading
            serviceLoadingQueue.append(service)
        }
        
        // Start loading the first service
        loadNextServiceFromQueue()
    }
    
    /// Handles notification when services are updated in settings.
    ///
    /// Called by:
    /// - Notification from SettingsManager when services are changed
    ///
    /// Process:
    /// 1. Clear existing WebViews
    /// 2. Reload services from SettingsManager
    /// 3. Create new WebViews for enabled services
    /// 4. Start loading sequence
    @objc private func servicesUpdated() {
        print("🔄 Services updated notification received, reloading services...")
        
        // Get previous service list for comparison
        let previousServiceIds = Set(webServices.keys)
        
        // Clear existing WebViews
        stateQueue.sync {
            for (_, webService) in webServices {
                let webView = webService.webView
                webView.stopLoading()
                webView.navigationDelegate = nil
                webView.uiDelegate = nil
                webView.removeFromSuperview()
            }
            
            webServices.removeAll()
            activeServices.removeAll()
            loadingStates.removeAll()
            serviceLoadingQueue.removeAll()
            currentlyLoadingService = nil
            loadedServicesCount = 0
            hasNotifiedAllServicesLoaded = false
        }
        
        // Set up services again with updated settings
        setupServices()
        
        // Get new service list
        let newServiceIds = Set(webServices.keys)
        
        // Check if services were added/removed
        if previousServiceIds != newServiceIds {
            print("📱 Service enable/disable detected - notifying overlay to reload")
            // Post notification to reload overlay UI
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .reloadOverlayUI, object: nil)
            }
        }
        
        // Notify UI to update
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    /// Handles favicon discovery notifications from WebView message handlers.
    ///
    /// Called by:
    /// - Notification from WebViewFactory when JavaScript extracts a favicon URL
    ///
    /// Process:
    /// 1. Extract service name and favicon URL from notification
    /// 2. Find the corresponding service in activeServices
    /// 3. Update the service's faviconURL property
    /// 4. Notify SettingsManager to persist the change
    /// 5. Trigger UI update
    @objc private func handleFaviconFound(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let serviceName = userInfo["service"] as? String,
              let faviconURLString = userInfo["faviconURL"] as? String,
              let faviconURL = URL(string: faviconURLString) else {
            print("⚠️ Invalid favicon notification data")
            return
        }
        
        print("🎨 Favicon found for \(serviceName): \(faviconURL)")
        
        // Find the service and update its favicon URL
        if let index = activeServices.firstIndex(where: { $0.name == serviceName }) {
            print("📌 Updating favicon for service \(activeServices[index].id) at index \(index)")
            activeServices[index].faviconURL = faviconURL
            
            // Update the service in SettingsManager to persist the change
            SettingsManager.shared.updateServiceFavicon(serviceId: activeServices[index].id, faviconURL: faviconURL)
            print("💾 Favicon URL saved to SettingsManager")
            
            // Notify UI to update
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        } else {
            print("⚠️ Could not find service with name: \(serviceName)")
        }
    }
    
    /// Loads the next service from the sequential loading queue.
    ///
    /// Called by:
    /// - `setupServices()` to start initial loading
    /// - `webView(_:didFinish:)` after each service loads
    /// - `webView(_:didFail:)` if a service fails to load
    ///
    /// Sequential loading ensures:
    /// - Only one WebView loads at a time
    /// - GPU process has time to initialize
    /// - Memory usage stays manageable
    /// - Navigation delegates fire in predictable order
    ///
    /// - Parameter forceReload: If true, reloads even if already at home URL
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
    
    /// Executes a prompt across all active AI services.
    ///
    /// This method is called from:
    /// - `executeSharedPrompt()` when user submits via Enter key
    /// - `PromptWindowController.submitPrompt()` via notification
    /// - `AppDelegate.handlePromptSubmission()` via notification
    ///
    /// Execution strategy to prevent clipboard race conditions:
    /// - URL parameter services (ChatGPT, Perplexity, Google): Execute in parallel
    /// - Clipboard services (Claude): Execute sequentially with completion handlers
    ///
    /// Execution modes:
    /// - New Chat (replyToAll=false): Navigate to service URL with query parameter
    /// - Reply to All (replyToAll=true): Paste prompt into existing chat sessions
    ///
    /// The execution flow continues to:
    /// - `URLParameterService.executePrompt()` for ChatGPT/Perplexity/Google
    /// - `ClaudeService.executePrompt()` for Claude's clipboard method
    ///
    /// - Parameters:
    ///   - prompt: The user's text to send to AI services
    ///   - replyToAll: If true, pastes into existing chats; if false, creates new chats
    func executePrompt(_ prompt: String, replyToAll: Bool = false) {
        if LoggingSettings.shared.debugPrompts {
            WebViewLogger.shared.log("🔄 executePrompt called - replyToAll: \(replyToAll), services: \(activeServices.map { $0.id }.joined(separator: ", "))", for: "system", type: .info)
        }
        
        // Categorize services by execution method to prevent clipboard conflicts
        let urlParameterServices = activeServices.filter { service in
            switch service.activationMethod {
            case .urlParameter:
                return true
            case .clipboardPaste:
                return false
            }
        }
        
        let clipboardServices = activeServices.filter { service in
            switch service.activationMethod {
            case .urlParameter:
                return false
            case .clipboardPaste:
                return true
            }
        }
        
        // Execute URL parameter services in parallel (no clipboard conflicts)
        for service in urlParameterServices {
            if let webService = webServices[service.id] {
                print("🎯 Executing prompt on URL service: \(service.name) (id: \(service.id))")
                if replyToAll {
                    // Reply to All mode: immediate execution
                    webService.executePrompt(prompt, replyToAll: true)
                } else {
                    // New Chat mode: use URL navigation with minimal delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + ServiceTimings.webKitSafetyDelay) {
                        webService.executePrompt(prompt, replyToAll: false)
                    }
                }
            } else {
                print("⚠️ No webService found for URL service: \(service.name) (id: \(service.id))")
            }
        }
        
        // Execute clipboard services sequentially to prevent race conditions
        executeClipboardServicesSequentially(clipboardServices, prompt: prompt, replyToAll: replyToAll, currentIndex: 0)
        
        // Refocus the prompt input field after a delay to ensure paste operations complete
        DispatchQueue.main.asyncAfter(deadline: .now() + ServiceTimings.promptRefocusDelay) { [weak self] in
            self?.focusInputPublisher.send()
        }
    }
    
    /// Executes clipboard services one by one to prevent clipboard race conditions.
    ///
    /// This method ensures that each clipboard-based service (like Claude) completes
    /// its clipboard operation before the next service begins. This prevents the
    /// clipboard from being overwritten by multiple services executing in parallel.
    ///
    /// - Parameters:
    ///   - services: Array of clipboard-based services to execute
    ///   - prompt: The user's text to send to AI services
    ///   - replyToAll: If true, pastes into existing chats; if false, creates new chats
    ///   - currentIndex: Current index in the services array (for recursion)
    private func executeClipboardServicesSequentially(_ services: [AIService], prompt: String, replyToAll: Bool, currentIndex: Int) {
        // Base case: all services have been executed
        guard currentIndex < services.count else {
            return
        }
        
        let service = services[currentIndex]
        
        if let webService = webServices[service.id] {
            print("🎯 Executing prompt on clipboard service: \(service.name) (id: \(service.id))")
            
            // Execute current service
            if replyToAll {
                // Reply to All mode: immediate execution with clipboard paste
                webService.executePrompt(prompt, replyToAll: true)
            } else {
                // New Chat mode: use URL navigation with minimal delay
                DispatchQueue.main.asyncAfter(deadline: .now() + ServiceTimings.webKitSafetyDelay) {
                    webService.executePrompt(prompt, replyToAll: false)
                }
            }
            
            // Wait for clipboard operation to complete before next service
            // Use claudePasteDelay as it's the longest clipboard operation delay
            DispatchQueue.main.asyncAfter(deadline: .now() + ServiceTimings.claudePasteDelay + 0.5) {
                // Execute next service recursively
                self.executeClipboardServicesSequentially(services, prompt: prompt, replyToAll: replyToAll, currentIndex: currentIndex + 1)
            }
            
        } else {
            print("⚠️ No webService found for clipboard service: \(service.name) (id: \(service.id))")
            // Skip to next service if current one is not found
            executeClipboardServicesSequentially(services, prompt: prompt, replyToAll: replyToAll, currentIndex: currentIndex + 1)
        }
    }
    
    /// Executes the current shared prompt based on submission mode.
    ///
    /// Called by:
    /// - `UnifiedInputBar` when user presses Enter
    /// - `ContentView.handleShortcutAction()` for keyboard shortcuts
    ///
    /// State-based execution logic:
    /// 1. First submission (isFirstSubmit=true):
    ///    - Always uses URL navigation to create new chat threads
    ///    - Sets isFirstSubmit=false for subsequent submissions
    ///    - Updates UI to show reply-to-all mode is now active
    ///
    /// 2. Subsequent submissions (isFirstSubmit=false):
    ///    - Uses replyToAll toggle state from UI
    ///    - If replyToAll=true: Pastes into existing chats
    ///    - If replyToAll=false: Creates new chats via URL
    ///
    /// This method manages the complex state transitions between
    /// "new chat" and "reply to all" modes across the app lifecycle.
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
    
    /// Reloads all services to their home pages.
    ///
    /// Called by:
    /// - "New Chat" button in UI
    /// - `resetThreadState()` when starting fresh conversations
    ///
    /// This method:
    /// 1. Clears and repopulates the loading queue
    /// 2. Resets to "first submit" mode for new threads
    /// 3. Forces reload of all services sequentially
    /// 4. Resets loading state tracking
    ///
    /// Force reload ensures:
    /// - All services return to home page
    /// - Previous chat sessions are cleared
    /// - Fresh state for new conversations
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
    
    /// Resets the thread state without reloading services.
    ///
    /// Called when:
    /// - User wants to start new conversations
    /// - After navigation to preserve state
    ///
    /// Unlike `reloadAllServices()`, this method:
    /// - Only resets the isFirstSubmit flag
    /// - Doesn't reload WebViews
    /// - Preserves current page state
    func resetThreadState() {
        // Reset to first submit mode to create new threads
        isFirstSubmit = true
        replyToAll = true  // Reset UI to default state
        
        // Don't clear the prompt here - let the UI handle it after submission
        
        // Don't reload all services - this was causing unwanted reloads after GET param navigation
        // reloadAllServices()
    }
    
    /// Starts new chat threads with optional prompt via URL navigation.
    ///
    /// Called by:
    /// - Plus button in UI for new chat
    /// - Keyboard shortcuts for new thread
    ///
    /// This method bypasses the sequential loading queue and navigates
    /// all services directly to their new thread URLs. This prevents
    /// the cascade of reloads that would occur with queue processing.
    ///
    /// Critical: Clears loading queue to prevent interference.
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
    
    /// Pauses all WebViews to reduce resource usage for inactive windows.
    ///
    /// Called by:
    /// - `OverlayController.hibernateWindow()` when window loses focus
    ///
    /// Hibernation steps:
    /// 1. Inject JavaScript to disable timers and animations
    /// 2. Stop any ongoing page loads
    /// 3. Hide WebViews to prevent GPU rendering
    ///
    /// This dramatically reduces CPU and memory usage for background windows.
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
    
    /// Resumes all WebViews when window regains focus.
    ///
    /// Called by:
    /// - `OverlayController.restoreWindow()` when window becomes active
    ///
    /// Restoration steps:
    /// 1. Restore JavaScript timer functions
    /// 2. Show WebViews to enable rendering
    /// 3. Force small scroll to trigger re-render
    ///
    /// WebViews become immediately interactive without reload.
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
    
    /// Extracts favicon from a loaded web page as a fallback.
    ///
    /// Called by:
    /// - `webView(_:didFinish:)` when BrowserViewController handoff fails
    ///
    /// This ensures favicon extraction happens even if the normal
    /// delegate handoff doesn't work properly.
    private func extractFavicon(for webView: WKWebView, service: AIService?, retryCount: Int = 0) {
        guard let service = service else { return }
        
        print("🔍 [Fallback] Extracting favicon for \(service.name) from URL: \(webView.url?.absoluteString ?? "unknown")")
        let faviconScript = JavaScriptProvider.faviconExtractionScript()
        webView.evaluateJavaScript(faviconScript) { [weak self] result, error in
            if let error = error {
                print("⚠️ [Fallback] Failed to extract favicon for \(service.name): \(error)")
                
                // Retry up to 3 times with exponential backoff
                if retryCount < 3 {
                    let delay = TimeInterval(pow(2.0, Double(retryCount))) // 1s, 2s, 4s
                    print("🔄 [Fallback] Retrying favicon extraction for \(service.name) in \(delay)s (attempt \(retryCount + 1)/3)")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        self?.extractFavicon(for: webView, service: service, retryCount: retryCount + 1)
                    }
                } else {
                    print("❌ [Fallback] Failed to extract favicon for \(service.name) after 3 attempts")
                    
                    // Fall back to FaviconFetcher for HTTP-based extraction
                    print("🌐 [Fallback] Attempting HTTP-based favicon fetch for \(service.name)")
                    FaviconFetcher.shared.fetchFaviconWithKnownURL(for: service) { url in
                        if let url = url {
                            print("✅ [Fallback] HTTP favicon fetch succeeded for \(service.name): \(url)")
                        } else {
                            print("❌ [Fallback] HTTP favicon fetch also failed for \(service.name)")
                        }
                    }
                }
            } else {
                print("✅ [Fallback] Favicon extraction script executed for \(service.name)")
            }
        }
    }
}

/// Shared WKProcessPool extension for critical optimization.
/// NEVER create new WKProcessPool instances - always use this shared one.
/// Creating multiple process pools causes:
/// - Duplicate GPU processes
/// - Increased memory usage
/// - WebView loading conflicts
extension WKProcessPool {
    static let shared = WKProcessPool()
}

// MARK: - Global ServiceManager Tracking

/// Extension for tracking all ServiceManager instances globally.
/// Used to coordinate prompt execution across multiple windows.
extension ServiceManager {
    /// Array of weak references to all ServiceManager instances.
    /// Automatically cleaned up when managers are deallocated.
    private static var allManagers: [WeakServiceManagerWrapper] = []
    
    /// Wrapper to hold weak references and prevent retain cycles.
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

/// Navigation delegate implementation for sequential service loading.
///
/// ServiceManager acts as the navigation delegate during initial loading,
/// then hands off to BrowserViewController after each service loads.
///
/// Key responsibilities:
/// - Track loading progress for sequential queue
/// - Handle navigation errors and recovery
/// - Determine when all services are loaded
/// - Hand off delegate to BrowserViewController
extension ServiceManager: WKNavigationDelegate {
    /// Handles navigation failures after content has started loading.
    ///
    /// This method:
    /// - Continues loading queue even if a service fails
    /// - Updates loading state for UI
    /// - Tracks failed services as "finished" for progress
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + ServiceTimings.serviceLoadingDelay) { [weak self] in
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
    
    /// Handles navigation failures before content starts loading.
    ///
    /// Special handling for:
    /// - Error -999 (NSURLErrorCancelled): Usually harmless, ignored
    /// - Other errors: Treated as failures, queue continues
    ///
    /// This is the most common failure point for WebView loads.
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + ServiceTimings.serviceLoadingDelay) { [weak self] in
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
    
    /// Called when WebView starts receiving content.
    ///
    /// This method just forwards to BrowserViewController for UI updates.
    /// The actual loading state is tracked in didStartProvisionalNavigation.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // Forward to BrowserView's delegate method for UI updates
        for (_, webService) in webServices {
            if webService.webView == webView {
                // Navigation delegate will be handled by BrowserViewController
                break
            }
        }
    }
    
    /// Called when WebView successfully completes loading.
    ///
    /// This is the key method for sequential loading:
    /// 1. Updates loading state for the finished service
    /// 2. Hands off navigation delegate to BrowserViewController
    /// 3. Loads the next service in the queue
    /// 4. Tracks overall loading progress
    /// 5. Notifies when all services are loaded
    ///
    /// Special handling:
    /// - Perplexity: Extra delay and focus management
    /// - Query URLs (?q=): Not counted as initial load
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
                        print("✅ Successfully handed off navigation delegate for \(serviceId) to BrowserViewController")
                    } else {
                        print("⚠️ No BrowserViewController found for \(serviceId) - will extract favicon here as fallback")
                        // Extract favicon as fallback if BrowserViewController isn't ready
                        extractFavicon(for: webView, service: activeServices.first { $0.id == serviceId })
                    }
                    
                    // Load the next service after a small delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + ServiceTimings.serviceLoadingDelay) { [weak self] in
                        self?.loadNextServiceFromQueue()
                    }
                }
                
                // Track service as loaded if this is initial load (not a query URL)
                if !urlString.contains("?q=") && !hasNotifiedAllServicesLoaded {
                    loadedServicesCount += 1
                    print("📊 Service loaded: \(serviceId) (\(loadedServicesCount)/\(activeServices.count))")
                    
                    // If this wasn't the currently loading service, still hand off delegate
                    // This handles cases where services load out of order or were pre-loaded
                    if serviceId != currentlyLoadingService {
                        if let browserViewController = browserViewControllers[serviceId] {
                            browserViewController.takeOverNavigationDelegate()
                            print("✅ Successfully handed off navigation delegate for \(serviceId) to BrowserViewController (out-of-order load)")
                        } else {
                            print("⚠️ No BrowserViewController found for \(serviceId) (out-of-order load) - will extract favicon here as fallback")
                            // Extract favicon as fallback if BrowserViewController isn't ready
                            extractFavicon(for: webView, service: activeServices.first { $0.id == serviceId })
                        }
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
                // Wait for Perplexity's JavaScript to fully execute
                DispatchQueue.main.asyncAfter(deadline: .now() + ServiceTimings.queryCheckDelay) { [weak self] in
                    print("🎯 Returning focus to main prompt bar after Perplexity load")
                    self?.focusInputPublisher.send()
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
    
    /// Handles WebView process crashes with automatic recovery.
    ///
    /// WebKit processes can crash due to:
    /// - Memory pressure
    /// - JavaScript errors
    /// - GPU process issues
    ///
    /// Recovery process:
    /// 1. Log the crash for debugging
    /// 2. Update loading state to prevent hanging
    /// 3. Wait for process cleanup
    /// 4. Force reload the crashed service
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard let serviceId = findServiceId(for: webView) else { return }
        
        print("⚠️ WebView process crashed for service: \(serviceId)")
        WebViewLogger.shared.log("⚠️ WebView process crashed, attempting recovery", for: serviceId, type: .error)
        
        // Mark service as not loading to prevent hanging (thread-safe)
        updateLoadingState(for: serviceId, isLoading: false)
        
        // Reload the service with a delay to allow process cleanup
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
