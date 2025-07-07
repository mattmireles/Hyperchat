/// BrowserViewController.swift - WebView Display and Navigation Management
///
/// This file manages the browser interface for each AI service, including navigation controls,
/// URL display, and WebView delegation. Each service gets its own BrowserViewController instance.
///
/// Key responsibilities:
/// - Displays WKWebView with navigation toolbar
/// - Manages back/forward/reload navigation
/// - Handles URL display with smart formatting
/// - Implements WKNavigationDelegate for page load tracking
/// - Manages focus behavior to prevent unwanted text selection
/// - Provides URL copying functionality
///
/// Related files:
/// - `ServiceManager.swift`: Creates BrowserViewController for each service
/// - `BrowserView.swift`: SwiftUI view that provides the UI layout
/// - `WebViewLogger.swift`: Logs navigation events and errors
/// - `GradientToolbarButton.swift`: Custom toolbar button component
/// - `ButtonState.swift`: Observable state for button enable/disable
///
/// Architecture:
/// - Uses NSViewController with SwiftUI view for modern UI
/// - Delegates navigation events to WebViewLogger for debugging
/// - Prevents focus stealing during initial page load
/// - Takes over navigation delegation after ServiceManager completes initial load

import AppKit
import WebKit
import SwiftUI
import Combine

// MARK: - Timing Constants

/// Timing constants for browser behavior.
private enum BrowserTimings {
    /// Delay before allowing WebView to capture focus
    /// Prevents unwanted text selection during initial page load
    static let focusCaptureDelay: TimeInterval = 3.0
}

// MARK: - Focus Indicator Components

/// Observable state model for focus indicators.
///
/// This allows SwiftUI views to reactively update when focus state changes
/// without recreating the entire view hierarchy.
private class FocusIndicatorState: ObservableObject {
    @Published var isVisible: Bool = false
    
    init(isVisible: Bool = false) {
        self.isVisible = isVisible
    }
}

/// NSHostingView subclass that passes through all mouse events.
///
/// This ensures the focus indicator border doesn't block any clicks or interactions
/// with the underlying browser content.
private class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Always return nil to pass through all mouse events
        return nil
    }
    
    override var acceptsFirstResponder: Bool {
        return false
    }
}

/// Reusable animated glowing border component for focus indication.
///
/// Provides a consistent visual language for focus states using
/// the same pink-to-blue animated gradient pattern as other app components.
private struct FocusIndicatorView: View {
    @ObservedObject var focusState: FocusIndicatorState
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    
    @State private var phase: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?
    
    private enum Appearance {
        static let pinkColor = Color(red: 1.0, green: 0.0, blue: 0.8)
        static let blueColor = Color(red: 0.0, green: 0.6, blue: 1.0)
        static let outerGlowOpacity: Double = 0.4
        static let middleGlowOpacity: Double = 0.6
        static let outerGlowBlur: CGFloat = 6
        static let middleGlowBlur: CGFloat = 3
        static let innerGlowBlur: CGFloat = 0.5
        static let outerGlowMultiplier: CGFloat = 1.2
        static let middleGlowMultiplier: CGFloat = 0.8
        static let innerGlowMultiplier: CGFloat = 0.3
        static let gradientRotationDuration: TimeInterval = 3.0
        static let fadeDuration: TimeInterval = 0.2
    }
    
    var body: some View {
        ZStack {
            // Outer glow layer
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Appearance.pinkColor, Appearance.blueColor,
                            Appearance.pinkColor, Appearance.blueColor, Appearance.pinkColor
                        ]),
                        center: .center,
                        startAngle: .degrees(phase),
                        endAngle: .degrees(phase + 360)
                    ),
                    lineWidth: lineWidth * Appearance.outerGlowMultiplier
                )
                .blur(radius: Appearance.outerGlowBlur)
                .opacity(Appearance.outerGlowOpacity)
            
            // Middle glow layer
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Appearance.pinkColor, Appearance.blueColor,
                            Appearance.pinkColor, Appearance.blueColor, Appearance.pinkColor
                        ]),
                        center: .center,
                        startAngle: .degrees(phase),
                        endAngle: .degrees(phase + 360)
                    ),
                    lineWidth: lineWidth * Appearance.middleGlowMultiplier
                )
                .blur(radius: Appearance.middleGlowBlur)
                .opacity(Appearance.middleGlowOpacity)
            
            // Inner sharp layer
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Appearance.pinkColor, Appearance.blueColor,
                            Appearance.pinkColor, Appearance.blueColor, Appearance.pinkColor
                        ]),
                        center: .center,
                        startAngle: .degrees(phase),
                        endAngle: .degrees(phase + 360)
                    ),
                    lineWidth: lineWidth * Appearance.innerGlowMultiplier
                )
                .blur(radius: Appearance.innerGlowBlur)
        }
        .opacity(focusState.isVisible ? 1 : 0)
        .animation(.easeInOut(duration: Appearance.fadeDuration), value: focusState.isVisible)
        .allowsHitTesting(false)
        .onChange(of: focusState.isVisible) { oldValue, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
        .onAppear {
            if focusState.isVisible {
                startAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        animationTask?.cancel()
        animationTask = Task {
            while !Task.isCancelled {
                withAnimation(.linear(duration: Appearance.gradientRotationDuration)) {
                    phase += 360
                }
                try? await Task.sleep(nanoseconds: UInt64(Appearance.gradientRotationDuration * 1_000_000_000))
            }
        }
    }
    
    private func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }
}

// MARK: - Browser View Controller

/// Manages the browser interface for a single AI service.
///
/// Created by:
/// - `ServiceManager.createBrowserView()` for each enabled service
///
/// Lifecycle:
/// 1. Created with pre-configured WKWebView from WebViewFactory
/// 2. ServiceManager performs initial page load
/// 3. Takes over navigation delegation via `takeOverNavigationDelegate()`
/// 4. Manages navigation and URL display throughout service lifetime
///
/// Navigation delegation handoff:
/// - ServiceManager needs delegate during initial load for state tracking
/// - After load completes, this controller takes over for navigation tracking
/// - This prevents race conditions during startup
class BrowserViewController: NSViewController, ObservableObject {
    /// The WKWebView instance for this service (created by WebViewFactory)
    private let webView: WKWebView
    
    /// The AI service configuration (ChatGPT, Claude, etc.)
    private let service: AIService
    
    /// Public accessor for the service name (for debugging and logging)
    public var serviceName: String {
        return service.name
    }
    
    /// SwiftUI view that provides the browser UI layout
    private let browserView: BrowserView
    
    /// Whether this is the first service (leftmost in UI)
    /// Used for keyboard shortcuts (Cmd+1 focuses first service)
    private let isFirstService: Bool
    
    // MARK: - Button States
    
    /// Observable state for back button (disabled when can't go back)
    private let backButtonState = ButtonState(isEnabled: false)
    
    /// Observable state for forward button (disabled when can't go forward)
    private let forwardButtonState = ButtonState(isEnabled: false)
    
    // MARK: - Focus Management
    
    /// Controls whether WebView can capture focus
    /// Prevents unwanted text selection during initial page load
    private var allowFocusCapture = false
    
    /// Published property indicating whether this webview's content has focus.
    ///
    /// This tracks JavaScript focus state within the webview (e.g., cursor in text inputs).
    /// Used by UI components to show/hide focus indicator borders.
    ///
    /// Updated by:
    /// - JavaScript focus/blur event listeners in the webview
    /// - `evaluateWebViewFocusState()` periodic checks
    /// - `becomeFirstResponder()` when webview gains native focus
    @Published public private(set) var hasWebViewFocus: Bool = false
    
    /// Timer for periodic focus state checking
    private var focusCheckTimer: Timer?
    
    /// Focus indicator hosting view that displays animated border around WebView
    private var focusIndicatorHostingView: ClickThroughHostingView<FocusIndicatorView>?
    
    /// Publisher for app focus state from OverlayController
    private let appFocusPublisher: AnyPublisher<Bool, Never>
    
    /// Combine cancellables for focus binding
    private var cancellables = Set<AnyCancellable>()
    
    /// Unique identifier for debugging lifecycle (first 8 chars of UUID)
    private let instanceId = UUID().uuidString.prefix(8)
    
    init(webView: WKWebView, service: AIService, isFirstService: Bool = false, appFocusPublisher: AnyPublisher<Bool, Never>) {
        self.webView = webView
        self.service = service
        self.isFirstService = isFirstService
        self.appFocusPublisher = appFocusPublisher
        self.browserView = BrowserView(webView: webView, isFirstService: isFirstService)
        
        super.init(nibName: nil, bundle: nil)
        
        // CRITICAL: Don't claim navigation delegate here
        // ServiceManager needs it for initial load state tracking
        // We'll take over via takeOverNavigationDelegate() after load completes
        
        let wvAddress = Unmanaged.passUnretained(webView).toOpaque()
        let retainCount = CFGetRetainCount(webView)
        print("🟢 [\(Date().timeIntervalSince1970)] BrowserViewController INIT \(instanceId) for \(service.name), WebView at \(wvAddress), retain count: \(retainCount)")
        
        // Enable focus capture after initial load delay
        DispatchQueue.main.asyncAfter(deadline: .now() + BrowserTimings.focusCaptureDelay) {
            self.allowFocusCapture = true
        }
        
        // Set up focus detection after initial load delay
        DispatchQueue.main.asyncAfter(deadline: .now() + BrowserTimings.focusCaptureDelay + 1.0) {
            self.setupFocusDetection()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        focusCheckTimer?.invalidate()
        focusCheckTimer = nil
        focusIndicatorHostingView?.removeFromSuperview()
        focusIndicatorHostingView = nil
        cancellables.removeAll()
        print("🔴 [\(Date().timeIntervalSince1970)] BrowserViewController DEINIT \(instanceId) for \(service.name)")
    }
    
    /// Takes over navigation delegation from ServiceManager.
    ///
    /// Called by:
    /// - `ServiceManager` after initial page load completes
    ///
    /// This handoff allows:
    /// - ServiceManager to track initial load state
    /// - BrowserViewController to handle subsequent navigation
    /// - Clean separation of concerns during startup
    func takeOverNavigationDelegate() {
        webView.navigationDelegate = self
        print("🎯 [\(Date().timeIntervalSince1970)] BrowserViewController \(instanceId) took over navigation delegate for \(service.name)")
    }
    
    override func loadView() {
        self.view = browserView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupToolbarButtons()
        setupFocusIndicator()
    }
    
    /// Sets up navigation toolbar buttons with actions.
    ///
    /// Called by:
    /// - `viewDidLoad()` during view setup
    ///
    /// Creates four toolbar buttons:
    /// 1. Back (chevron.backward) - disabled until navigation history exists
    /// 2. Forward (chevron.forward) - disabled until forward history exists
    /// 3. Reload (arrow.clockwise) - always enabled
    /// 4. Copy URL (clipboard) - always enabled
    ///
    /// Each button is a SwiftUI GradientToolbarButton wrapped in NSHostingView.
    private func setupToolbarButtons() {
        // Create SwiftUI gradient buttons
        let backButtonView = NSHostingView(rootView: GradientToolbarButton(
            systemName: "chevron.backward",
            state: backButtonState,
            action: { [weak self] in self?.goBack() }
        ))
        backButtonView.translatesAutoresizingMaskIntoConstraints = false
        backButtonView.setFrameSize(NSSize(width: 20, height: 20))
        
        let forwardButtonView = NSHostingView(rootView: GradientToolbarButton(
            systemName: "chevron.forward",
            state: forwardButtonState,
            action: { [weak self] in self?.goForward() }
        ))
        forwardButtonView.translatesAutoresizingMaskIntoConstraints = false
        forwardButtonView.setFrameSize(NSSize(width: 20, height: 20))
        
        let reloadButtonView = NSHostingView(rootView: GradientToolbarButton(
            systemName: "arrow.clockwise",
            state: ButtonState(isEnabled: true),
            action: { [weak self] in self?.reload() }
        ))
        reloadButtonView.translatesAutoresizingMaskIntoConstraints = false
        reloadButtonView.setFrameSize(NSSize(width: 20, height: 20))
        
        let copyButtonView = NSHostingView(rootView: GradientToolbarButton(
            systemName: "clipboard",
            state: ButtonState(isEnabled: true),
            fontSize: 12,
            action: { [weak self] in self?.copyURL() }
        ))
        copyButtonView.translatesAutoresizingMaskIntoConstraints = false
        copyButtonView.setFrameSize(NSSize(width: 20, height: 20))
        
        // Set up the toolbar buttons in the view
        browserView.setupToolbarButtons(backButtonView, forwardButtonView, reloadButtonView, copyButtonView)
        
        // Set up URL field action
        browserView.urlField.target = self
        browserView.urlField.action = #selector(loadURL)
    }
    
    /// Sets up focus indicator that displays animated border around WebView.
    ///
    /// Called by:
    /// - `viewDidLoad()` after toolbar setup
    ///
    /// This creates a focus indicator border that:
    /// - Combines WebView focus state AND app focus state (both must be true)
    /// - Is pinned directly to the WebView using Auto Layout constraints  
    /// - Passes through all mouse events to the underlying WebView
    /// - Displays animated pink-to-blue gradient border when both conditions are met
    private func setupFocusIndicator() {
        // Create focus state for reactivity - starts as false
        let focusState = FocusIndicatorState(isVisible: false)
        
        // Create focus indicator view bound to reactive state
        let focusIndicator = FocusIndicatorView(
            focusState: focusState,
            cornerRadius: 8,
            lineWidth: 2
        )
        
        // Create click-through hosting view
        let hostingView = ClickThroughHostingView(rootView: focusIndicator)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Add to view hierarchy - hostingView and webView are now siblings in BrowserView
        view.addSubview(hostingView)
        
        // Pin focus indicator directly to WebView bounds
        // This is much simpler than coordinate conversion since they're siblings
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: browserView.webView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: browserView.webView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: browserView.webView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: browserView.webView.bottomAnchor)
        ])
        
        // Store reference for cleanup
        self.focusIndicatorHostingView = hostingView
        
        // CRITICAL: Bind focus state to BOTH webview focus AND app focus
        // Border only shows when BOTH conditions are true
        Publishers.CombineLatest(
            self.$hasWebViewFocus,
            appFocusPublisher
        )
        .map { webViewFocused, appFocused in
            return webViewFocused && appFocused
        }
        .removeDuplicates()
        .sink { [weak focusState, weak self] shouldShowBorder in
            guard let state = focusState, let self = self else { return }
            
            // Update the focus state reactively - SwiftUI will handle the UI update
            DispatchQueue.main.async {
                if state.isVisible != shouldShowBorder {
                    print("🔄 [FOCUS UPDATE] \(self.service.name): webView=\(self.hasWebViewFocus), border=\(state.isVisible) -> \(shouldShowBorder)")
                    state.isVisible = shouldShowBorder
                } else {
                    print("➖ [FOCUS UNCHANGED] \(self.service.name): border state already \(shouldShowBorder)")
                }
            }
        }
        .store(in: &cancellables)
        
        print("🎯 [FOCUS INDICATOR] Set up for \(service.name) - pinned directly to WebView with proper focus binding")
    }
    
    /// Navigates back in WebView history.
    ///
    /// Called by:
    /// - Back button action in toolbar
    ///
    /// Only enabled when webView.canGoBack is true.
    @objc private func goBack() {
        webView.goBack()
    }
    
    /// Navigates forward in WebView history.
    ///
    /// Called by:
    /// - Forward button action in toolbar
    ///
    /// Only enabled when webView.canGoForward is true.
    @objc private func goForward() {
        webView.goForward()
    }
    
    /// Reloads the current page.
    ///
    /// Called by:
    /// - Reload button action in toolbar
    ///
    /// Always enabled, triggers full page reload.
    @objc private func reload() {
        webView.reload()
    }
    
    /// Loads URL from the URL text field.
    ///
    /// Called by:
    /// - URL field when user presses Enter
    ///
    /// URL processing:
    /// 1. Gets text from URL field
    /// 2. Adds https:// prefix if missing
    /// 3. Creates URL and loads in WebView
    ///
    /// The URL field shows cleaned URLs (no https://)
    /// but this method reconstructs the full URL.
    @objc private func loadURL() {
        guard let urlString = browserView.urlField.stringValue.isEmpty ? nil : browserView.urlField.stringValue else { return }
        
        // Reconstruct full URL if user entered a cleaned version
        var fullURLString = urlString
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            // Default to https://
            fullURLString = "https://\(urlString)"
        }
        
        guard let url = URL(string: fullURLString) else { return }
        webView.load(URLRequest(url: url))
    }
    
    /// Copies the current URL to clipboard.
    ///
    /// Called by:
    /// - Copy URL button action in toolbar
    ///
    /// Copies the full URL including protocol (https://)
    /// even though the display shows cleaned version.
    @objc private func copyURL() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        // Copy the full URL, not the cleaned display version
        if let fullURL = webView.url?.absoluteString {
            pasteboard.setString(fullURL, forType: .string)
        }
    }
    
    /// Updates navigation button states based on WebView history.
    ///
    /// Called by:
    /// - All WKNavigationDelegate methods after navigation changes
    ///
    /// Updates:
    /// - Back button: enabled if canGoBack
    /// - Forward button: enabled if canGoForward
    ///
    /// SwiftUI buttons observe these states and update automatically.
    private func updateBackButton() {
        // Update the SwiftUI button states
        backButtonState.isEnabled = webView.canGoBack
        forwardButtonState.isEnabled = webView.canGoForward
    }
    
    /// Cleans URL for display in the URL field.
    ///
    /// Called by:
    /// - All navigation delegate methods when updating URL field
    ///
    /// Removes common prefixes for cleaner display:
    /// - https://www. -> (removed)
    /// - https:// -> (removed)
    /// - http://www. -> (removed)
    /// - http:// -> (removed)
    ///
    /// Example: "https://www.google.com" -> "google.com"
    ///
    /// The full URL is preserved in the tooltip.
    private func cleanURLForDisplay(_ urlString: String?) -> String {
        guard let urlString = urlString else { return "" }
        
        // Remove https:// and https://www. prefixes
        var cleanedURL = urlString
        if cleanedURL.hasPrefix("https://www.") {
            cleanedURL = String(cleanedURL.dropFirst(12))
        } else if cleanedURL.hasPrefix("https://") {
            cleanedURL = String(cleanedURL.dropFirst(8))
        } else if cleanedURL.hasPrefix("http://www.") {
            cleanedURL = String(cleanedURL.dropFirst(11))
        } else if cleanedURL.hasPrefix("http://") {
            cleanedURL = String(cleanedURL.dropFirst(7))
        }
        
        return cleanedURL
    }
    
    // MARK: - WebView Focus Detection
    
    /// Sets up JavaScript-based focus detection within the webview.
    ///
    /// Called after initial page load delay to avoid interfering with page setup.
    /// Sets up message handler and starts periodic focus checking.
    /// Focus listeners are injected after each navigation in didFinish.
    ///
    /// Focus detection methods:
    /// 1. JavaScript event listeners for real-time focus/blur detection (re-injected per page)
    /// 2. Periodic polling as backup for missed events
    /// 3. Integration with native responder chain events
    private func setupFocusDetection() {
        // Add message handler for focus state updates (only once)
        webView.configuration.userContentController.add(self, name: "focusHandler")
        
        // Start periodic focus checking as backup
        startPeriodicFocusChecking()
    }
    
    /// Returns the JavaScript code for focus detection.
    ///
    /// Extracted as separate method so it can be re-injected after every navigation.
    /// This ensures every page has focus listeners, even after navigation changes.
    private func focusDetectionScript() -> String {
        return """
            (function() {
                function updateFocusState() {
                    const hasFocus = document.hasFocus() && 
                                   (document.activeElement && 
                                    document.activeElement !== document.body &&
                                    document.activeElement.tagName !== 'HTML');
                    window.webkit.messageHandlers.focusHandler.postMessage({
                        type: 'focusChange',
                        hasFocus: hasFocus,
                        activeElement: document.activeElement ? document.activeElement.tagName : 'none'
                    });
                }
                
                // Set up event listeners for focus changes
                window.addEventListener('focus', updateFocusState, true);
                window.addEventListener('blur', updateFocusState, true);
                document.addEventListener('focusin', updateFocusState, true);
                document.addEventListener('focusout', updateFocusState, true);
                
                // Initial state check
                updateFocusState();
            })();
            """
    }
    
    /// Injects focus detection script into the current page.
    ///
    /// Called after every navigation to ensure focus listeners are present.
    /// Uses evaluateJavaScript instead of userScript to avoid accumulation.
    private func injectFocusDetectionScript() {
        let script = focusDetectionScript()
        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error = error {
                print("⚠️ Failed to inject focus detection script for \(self?.service.name ?? "unknown"): \(error)")
            } else {
                print("✅ Focus detection script injected for \(self?.service.name ?? "unknown")")
            }
        }
    }
    
    /// Starts periodic checking of webview focus state.
    ///
    /// Runs every 500ms as a backup to JavaScript event listeners.
    /// This ensures focus state stays accurate even if events are missed.
    private func startPeriodicFocusChecking() {
        focusCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.evaluateWebViewFocusState()
        }
    }
    
    /// Evaluates the current focus state within the webview using JavaScript.
    ///
    /// Called periodically and on demand to ensure focus state accuracy.
    /// Updates `hasWebViewFocus` property based on document.hasFocus() and activeElement.
    private func evaluateWebViewFocusState() {
        let focusScript = """
            (function() {
                const hasFocus = document.hasFocus() && 
                               (document.activeElement && 
                                document.activeElement !== document.body &&
                                document.activeElement.tagName !== 'HTML');
                return {
                    hasFocus: hasFocus,
                    activeElement: document.activeElement ? document.activeElement.tagName : 'none'
                };
            })();
            """
        
        webView.evaluateJavaScript(focusScript) { [weak self] result, error in
            guard let self = self else { return }
            
            if error != nil {
                // Silent failure - focus checking is not critical
                return
            }
            
            if let resultDict = result as? [String: Any],
               let hasFocus = resultDict["hasFocus"] as? Bool {
                let activeElement = resultDict["activeElement"] as? String ?? "unknown"
                DispatchQueue.main.async {
                    if self.hasWebViewFocus != hasFocus {
                        print("⏰ [PERIODIC DEBUG] Focus changed for \(self.service.name): \(self.hasWebViewFocus) -> \(hasFocus), activeElement: \(activeElement)")
                        self.hasWebViewFocus = hasFocus
                    }
                }
            }
        }
    }
}

// MARK: - Responder Chain Handling

/// Focus management to prevent unwanted text selection.
///
/// Problem solved:
/// - WebViews can steal focus during page load
/// - This causes unwanted text selection in input fields
/// - Users lose their place when typing prompts
///
/// Solution:
/// - Delay focus capture for 3 seconds after creation
/// - Only allow focus on explicit mouse clicks
/// - Let WebView handle focus after initial delay
extension BrowserViewController {
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        let eventType = NSApp.currentEvent?.type
        print("🖱️ [RESPONDER DEBUG] becomeFirstResponder called for \(service.name), allowFocusCapture: \(allowFocusCapture), eventType: \(eventType?.rawValue ?? 999)")
        
        // Only allow the webView to become first responder if:
        // 1. Focus capture is allowed (after 3-second delay), AND
        // 2. It's been explicitly clicked (left or right mouse)
        //
        // This prevents WebView from stealing focus during page loads
        if allowFocusCapture && (NSApp.currentEvent?.type == .leftMouseDown || 
                                  NSApp.currentEvent?.type == .rightMouseDown) {
            let didBecome = webView.becomeFirstResponder()
            print("📱 [RESPONDER DEBUG] WebView becomeFirstResponder for \(service.name): \(didBecome)")
            if didBecome {
                // Update focus state when webview gains native focus
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.evaluateWebViewFocusState()
                }
            }
            return didBecome
        }
        print("❌ [RESPONDER DEBUG] Blocked becomeFirstResponder for \(service.name)")
        return false
    }
}

// MARK: - WKNavigationDelegate

/// Handles WebView navigation events and updates UI accordingly.
///
/// Delegate methods called during page navigation:
/// 1. didStartProvisionalNavigation - Navigation initiated
/// 2. didCommit - Server responded, content loading
/// 3. didFinish - Page fully loaded
/// 4. didFail/didFailProvisionalNavigation - Errors occurred
///
/// Each method:
/// - Logs to WebViewLogger for debugging
/// - Updates URL field with cleaned display
/// - Sets full URL as tooltip
/// - Updates navigation button states
extension BrowserViewController: WKNavigationDelegate {
    /// Called when navigation starts (user clicks link or loads URL).
    ///
    /// This is the earliest navigation event, fired when:
    /// - User clicks a link
    /// - JavaScript changes location
    /// - loadRequest is called
    ///
    /// Updates URL field immediately for responsive UI.
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("🌐 \(service.name): didStartProvisionalNavigation")
        // Log navigation start
        if let url = webView.url {
            WebViewLogger.shared.logNavigation(navigation, request: URLRequest(url: url), service: service.name)
        }
        
        // Update URL as soon as navigation starts
        DispatchQueue.main.async { [weak self] in
            let fullURL = webView.url?.absoluteString ?? ""
            self?.browserView.urlField.stringValue = self?.cleanURLForDisplay(fullURL) ?? ""
            self?.browserView.urlField.toolTip = fullURL.isEmpty ? "Enter URL..." : fullURL
            self?.updateBackButton()
        }
    }
    
    /// Called when server responds and content starts loading.
    ///
    /// At this point:
    /// - Server has responded with content
    /// - Page is starting to render
    /// - URL is finalized (after redirects)
    ///
    /// This is a good time to update UI with final URL.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        WebViewLogger.shared.logPageLoad(start: true, service: service.name, url: webView.url)
        
        // Update URL when navigation commits
        DispatchQueue.main.async { [weak self] in
            let fullURL = webView.url?.absoluteString ?? ""
            self?.browserView.urlField.stringValue = self?.cleanURLForDisplay(fullURL) ?? ""
            self?.browserView.urlField.toolTip = fullURL.isEmpty ? "Enter URL..." : fullURL
            self?.updateBackButton()
        }
    }
    
    /// Called when page finishes loading completely.
    ///
    /// At this point:
    /// - All resources loaded
    /// - JavaScript executed
    /// - Page is interactive
    ///
    /// Final UI update to ensure consistency.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        WebViewLogger.shared.logPageLoad(start: false, service: service.name, url: webView.url)
        
        // Final update when navigation finishes
        DispatchQueue.main.async { [weak self] in
            let fullURL = webView.url?.absoluteString ?? ""
            self?.browserView.urlField.stringValue = self?.cleanURLForDisplay(fullURL) ?? ""
            self?.browserView.urlField.toolTip = fullURL.isEmpty ? "Enter URL..." : fullURL
            self?.updateBackButton()
        }
        
        // Re-inject focus detection script after navigation to ensure every page has listeners
        injectFocusDetectionScript()
        
        // Extract favicon after page loads
        print("🔍 Extracting favicon for \(service.name) from URL: \(webView.url?.absoluteString ?? "unknown")")
        let faviconScript = JavaScriptProvider.faviconExtractionScript()
        webView.evaluateJavaScript(faviconScript) { result, error in
            if let error = error {
                print("⚠️ Failed to extract favicon for \(self.service.name): \(error)")
            } else {
                print("✅ Favicon extraction script executed for \(self.service.name)")
            }
        }
    }
    
    /// Called when navigation fails after starting.
    ///
    /// Common errors:
    /// - Network timeout
    /// - Server errors (500, etc.)
    /// - SSL certificate issues
    ///
    /// Still updates UI to show current state.
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        WebViewLogger.shared.logNavigationError(error, service: service.name)
        
        // Update even on failure
        DispatchQueue.main.async { [weak self] in
            let fullURL = webView.url?.absoluteString ?? ""
            self?.browserView.urlField.stringValue = self?.cleanURLForDisplay(fullURL) ?? ""
            self?.browserView.urlField.toolTip = fullURL.isEmpty ? "Enter URL..." : fullURL
            self?.updateBackButton()
        }
    }
    
    /// Called when navigation fails before receiving response.
    ///
    /// Common errors:
    /// - Invalid URL
    /// - DNS lookup failure  
    /// - No internet connection
    /// - Cancelled navigation (-999)
    ///
    /// Updates UI even on early failures.
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        WebViewLogger.shared.logNavigationError(error, service: service.name)
        
        // Handle provisional navigation failures
        DispatchQueue.main.async { [weak self] in
            let fullURL = webView.url?.absoluteString ?? ""
            self?.browserView.urlField.stringValue = self?.cleanURLForDisplay(fullURL) ?? ""
            self?.browserView.urlField.toolTip = fullURL.isEmpty ? "Enter URL..." : fullURL
            self?.updateBackButton()
        }
    }
    
    /// Called to decide whether to allow navigation based on response.
    ///
    /// Can inspect:
    /// - HTTP status code
    /// - MIME type
    /// - Headers
    ///
    /// Currently allows all responses, but logs for debugging.
    /// Could be extended to block certain content types.
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        WebViewLogger.shared.logNavigationResponse(navigationResponse.response, service: service.name)
        decisionHandler(.allow)
    }
}

// MARK: - Focus Message Handler

/// Handles JavaScript messages for focus state updates.
///
/// Receives messages from injected JavaScript that monitors focus/blur events
/// within the webview content. This provides real-time focus state tracking
/// for showing/hiding focus indicator borders.
extension BrowserViewController: WKScriptMessageHandler {
    /// Processes focus state messages from JavaScript.
    ///
    /// Message format:
    /// ```javascript
    /// {
    ///   type: 'focusChange',
    ///   hasFocus: boolean,
    ///   activeElement: string
    /// }
    /// ```
    ///
    /// Updates `hasWebViewFocus` property which triggers UI updates for focus indicators.
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "focusHandler",
              let messageBody = message.body as? [String: Any],
              let messageType = messageBody["type"] as? String,
              messageType == "focusChange",
              let hasFocus = messageBody["hasFocus"] as? Bool else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let activeElement = messageBody["activeElement"] as? String ?? "unknown"
            
            if self.hasWebViewFocus != hasFocus {
                print("🎯 [FOCUS DEBUG] WebView focus changed for \(self.service.name): \(self.hasWebViewFocus) -> \(hasFocus), activeElement: \(activeElement)")
                self.hasWebViewFocus = hasFocus
            } else {
                print("🔍 [FOCUS DEBUG] WebView focus message for \(self.service.name): \(hasFocus) (no change), activeElement: \(activeElement)")
            }
        }
    }
}