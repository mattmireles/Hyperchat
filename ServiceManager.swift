import Foundation
import WebKit
import SwiftUI

// MARK: - Browser View with Controls

// MARK: - Gradient Toolbar Button

class ButtonState: ObservableObject {
    @Published var isEnabled: Bool
    
    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}

struct GradientToolbarButton: View {
    let systemName: String
    @ObservedObject var state: ButtonState
    let action: () -> Void
    @State private var isHovering = false
    @State private var isPressed = false
    @State private var rotationAngle: Double = 0
    @State private var bounceOffset: CGFloat = 0
    @State private var wigglePhase: Double = 0
    @State private var showReplaceIcon = false
    
    var body: some View {
        VStack(spacing: 0) {  // Add this wrapper
            Button(action: {
                // Trigger animations based on icon type
                switch systemName {
                case "arrow.clockwise":
                    // Rotate animation
                    withAnimation(.easeInOut(duration: 0.6)) {
                        rotationAngle += 360
                    }
                case "chevron.backward", "chevron.forward":
                    // Bounce animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        bounceOffset = -5
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1)) {
                        bounceOffset = 0
                    }
                case "document.on.document":
                    // Replace animation
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showReplaceIcon = true
                    }
                    withAnimation(.easeInOut(duration: 0.3).delay(0.6)) {
                        showReplaceIcon = false
                    }
                default:
                    break
                }
                action()
            }) {
                ZStack {
                    if state.isEnabled && isHovering {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.0, green: 0.6, blue: 1.0),  // Blue
                                Color(red: 1.0, green: 0.0, blue: 0.8)   // Pink/Magenta
                            ]),
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                        .mask(
                            Image(systemName: currentIconName)
                                .font(.system(size: 14, weight: .semibold))
                                .rotationEffect(.degrees(systemName == "arrow.clockwise" ? rotationAngle : 0))
                                .offset(y: systemName == "chevron.backward" || systemName == "chevron.forward" ? bounceOffset : 0)
                        )
                    } else {
                        Image(systemName: currentIconName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(state.isEnabled ? .secondary.opacity(0.7) : .secondary.opacity(0.7))
                            .rotationEffect(.degrees(systemName == "arrow.clockwise" ? rotationAngle : 0))
                            .offset(y: systemName == "chevron.backward" || systemName == "chevron.forward" ? bounceOffset : 0)
                    }
                }
                .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .disabled(!state.isEnabled)
            .offset(y: -11)  // Move the offset here instead
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
        }
        .frame(width: 20, height: 20, alignment: .center)  // Explicit alignment
    }
    
    private var currentIconName: String {
        if systemName == "document.on.document" && showReplaceIcon {
            return "square.and.arrow.up"
        }
        return systemName
    }
}

class BrowserView: NSView {
    let webView: WKWebView
    private let urlField: NSTextField
    private let backButton: NSButton
    private let forwardButton: NSButton
    private let reloadButton: NSButton
    private let copyButton: NSButton
    private let service: AIService
    private var topToolbar: NSStackView!
    private var bottomToolbar: NSStackView!
    private let isFirstService: Bool
    private var allowFocusCapture = false
    
    // SwiftUI button views
    private var backButtonView: NSHostingView<GradientToolbarButton>!
    private var forwardButtonView: NSHostingView<GradientToolbarButton>!
    private var reloadButtonView: NSHostingView<GradientToolbarButton>!
    private var copyButtonView: NSHostingView<GradientToolbarButton>!
    
    // Button states
    private let backButtonState = ButtonState(isEnabled: false)
    private let forwardButtonState = ButtonState(isEnabled: false)
    
    init(webView: WKWebView, service: AIService, isFirstService: Bool = false) {
        self.webView = webView
        self.service = service
        self.isFirstService = isFirstService
        
        // Create controls
        self.backButton = NSButton()
        self.forwardButton = NSButton()
        self.reloadButton = NSButton()
        self.copyButton = NSButton()
        self.urlField = NSTextField()
        
        super.init(frame: .zero)
        
        // Add visual styling
        self.wantsLayer = true
        self.layer?.cornerRadius = 8
        self.layer?.masksToBounds = true
        self.layer?.borderWidth = 0.5
        self.layer?.borderColor = NSColor.separatorColor.cgColor
        
        setupControls()
        setupLayout()
        setupWebViewDelegate()
        
        // Enable focus capture after initial load delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.allowFocusCapture = true
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        // Only allow the webView to become first responder if:
        // 1. It's been explicitly clicked, or
        // 2. Focus capture is allowed (after initial load period)
        if allowFocusCapture && (NSApp.currentEvent?.type == .leftMouseDown || 
                                  NSApp.currentEvent?.type == .rightMouseDown) {
            return webView.becomeFirstResponder()
        }
        return false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupControls() {
        // Create SwiftUI gradient buttons
        let backButtonView = NSHostingView(rootView: GradientToolbarButton(
            systemName: "chevron.backward",
            state: backButtonState,
            action: { [weak self] in self?.goBack() }
        ))
        backButtonView.translatesAutoresizingMaskIntoConstraints = false
        backButtonView.setFrameSize(NSSize(width: 20, height: 20))  // Explicit size
        
        let forwardButtonView = NSHostingView(rootView: GradientToolbarButton(
            systemName: "chevron.forward",
            state: forwardButtonState,
            action: { [weak self] in self?.goForward() }
        ))
        forwardButtonView.translatesAutoresizingMaskIntoConstraints = false
        forwardButtonView.setFrameSize(NSSize(width: 20, height: 20))  // Explicit size
        
        let reloadButtonView = NSHostingView(rootView: GradientToolbarButton(
            systemName: "arrow.clockwise",
            state: ButtonState(isEnabled: true),
            action: { [weak self] in self?.reload() }
        ))
        reloadButtonView.translatesAutoresizingMaskIntoConstraints = false
        reloadButtonView.setFrameSize(NSSize(width: 20, height: 20))  // Explicit size
        
        let copyButtonView = NSHostingView(rootView: GradientToolbarButton(
            systemName: "document.on.document",
            state: ButtonState(isEnabled: true),
            action: { [weak self] in self?.copyURL() }
        ))
        copyButtonView.translatesAutoresizingMaskIntoConstraints = false
        copyButtonView.setFrameSize(NSSize(width: 20, height: 20))  // Explicit size
        
        // Store references for later updates
        self.backButtonView = backButtonView
        self.forwardButtonView = forwardButtonView
        self.reloadButtonView = reloadButtonView
        self.copyButtonView = copyButtonView
        
        // URL field
        urlField.isEditable = true
        urlField.cell?.sendsActionOnEndEditing = true
        urlField.target = self
        urlField.action = #selector(loadURL)
        urlField.placeholderString = "Enter URL..."
        urlField.font = NSFont.systemFont(ofSize: 11)
        urlField.bezelStyle = .roundedBezel
        urlField.focusRingType = .none
        urlField.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3)
        urlField.textColor = NSColor.secondaryLabelColor
        urlField.maximumNumberOfLines = 1
        urlField.lineBreakMode = .byTruncatingTail
        urlField.alignment = .left
        
        // Create top toolbar - different layout for first service
        let topToolbar: NSStackView
        if isFirstService {
            // For Google: add spacing for traffic lights, then nav buttons
            let spacer = NSView()
            spacer.widthAnchor.constraint(equalToConstant: 70).isActive = true // Space for traffic lights
            
            topToolbar = NSStackView(views: [spacer, backButtonView, forwardButtonView, reloadButtonView, urlField, copyButtonView])
        } else {
            // Standard toolbar for other services
            topToolbar = NSStackView(views: [backButtonView, forwardButtonView, reloadButtonView, urlField, copyButtonView])
        }
        topToolbar.orientation = .horizontal
        topToolbar.spacing = 6
        topToolbar.distribution = .fill
        topToolbar.alignment = .centerY
        
        // Make URL field take up available space
        urlField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // Set priorities to make URL field expand
        urlField.setContentHuggingPriority(NSLayoutConstraint.Priority(249), for: .horizontal)
        backButtonView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        forwardButtonView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        reloadButtonView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        copyButtonView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        // Set fixed size for button views
        for buttonView in [backButtonView, forwardButtonView, reloadButtonView, copyButtonView] {
            NSLayoutConstraint.activate([
                buttonView.widthAnchor.constraint(equalToConstant: 20),
                buttonView.heightAnchor.constraint(equalToConstant: 20)
            ])
        }
        
        // Set URL field height to match buttons
        NSLayoutConstraint.activate([
            urlField.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        addSubview(topToolbar)
        addSubview(webView)
        
        self.topToolbar = topToolbar
        self.bottomToolbar = nil
        
        // Layout constraints
        topToolbar.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Top toolbar with URL
            topToolbar.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            topToolbar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            topToolbar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            topToolbar.heightAnchor.constraint(equalToConstant: 32),
            
            // WebView fills remaining space
            webView.topAnchor.constraint(equalTo: topToolbar.bottomAnchor, constant: 1),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func setupLayout() {
        // Layout is handled in setupControls()
    }
    
    private func setupWebViewDelegate() {
        webView.navigationDelegate = self
    }
    
    @objc private func goBack() {
        webView.goBack()
    }
    
    @objc private func goForward() {
        webView.goForward()
    }
    
    @objc private func reload() {
        webView.reload()
    }
    
    @objc private func loadURL() {
        guard let urlString = urlField.stringValue.isEmpty ? nil : urlField.stringValue,
              let url = URL(string: urlString.hasPrefix("http") ? urlString : "https://\(urlString)") else { return }
        webView.load(URLRequest(url: url))
    }
    
    @objc private func copyURL() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(urlField.stringValue, forType: .string)
    }
    
    func updateBackButton() {
        // Update the SwiftUI button states
        backButtonState.isEnabled = webView.canGoBack
        forwardButtonState.isEnabled = webView.canGoForward
    }
}

extension BrowserView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("🌐 \(service.name): didStartProvisionalNavigation")
        // Log navigation start
        if let url = webView.url {
            WebViewLogger.shared.logNavigation(navigation, request: URLRequest(url: url), service: service.name)
        }
        
        // Update URL as soon as navigation starts
        DispatchQueue.main.async { [weak self] in
            self?.urlField.stringValue = webView.url?.absoluteString ?? ""
            self?.updateBackButton()
        }
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        WebViewLogger.shared.logPageLoad(start: true, service: service.name, url: webView.url)
        
        // Update URL when navigation commits
        DispatchQueue.main.async { [weak self] in
            self?.urlField.stringValue = webView.url?.absoluteString ?? ""
            self?.updateBackButton()
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        WebViewLogger.shared.logPageLoad(start: false, service: service.name, url: webView.url)
        
        // Final update when navigation finishes
        DispatchQueue.main.async { [weak self] in
            self?.urlField.stringValue = webView.url?.absoluteString ?? ""
            self?.updateBackButton()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        WebViewLogger.shared.logNavigationError(error, service: service.name)
        
        // Update even on failure
        DispatchQueue.main.async { [weak self] in
            self?.urlField.stringValue = webView.url?.absoluteString ?? ""
            self?.updateBackButton()
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        WebViewLogger.shared.logNavigationError(error, service: service.name)
        
        // Handle provisional navigation failures
        DispatchQueue.main.async { [weak self] in
            self?.urlField.stringValue = webView.url?.absoluteString ?? ""
            self?.updateBackButton()
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        WebViewLogger.shared.logNavigationResponse(navigationResponse.response, service: service.name)
        decisionHandler(.allow)
    }
}

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
        order: 1
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
        order: 3
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
    var browserView: BrowserView { get }
    var service: AIService { get }
}

class URLParameterService: WebService {
    let browserView: BrowserView
    let service: AIService
    
    init(browserView: BrowserView, service: AIService) {
        self.browserView = browserView
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
                browserView.webView.load(URLRequest(url: url))
                
                // Add debugging to monitor when services auto-submit
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    let serviceName = self.service.name
                    self.browserView.webView.evaluateJavaScript("""
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
            browserView.webView.load(URLRequest(url: url))
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
            self.browserView.webView.evaluateJavaScript("""
                (function() {
                    const promptText = `\(prompt.replacingOccurrences(of: "`", with: "\\`"))`;
                    console.log('PASTE: Starting with prompt:', promptText.substring(0, 50));
                    
                    // Enhanced service-specific selectors with latest ChatGPT selectors
                    const selectors = [
                        // ChatGPT - latest selectors (2024/2025)
                        'textarea[data-testid="textbox"]',
                        'div[contenteditable="true"][data-testid="textbox"]',
                        'textarea[placeholder*="Message ChatGPT"]',
                        'textarea[placeholder*="Send a message"]',
                        'div[contenteditable="true"][data-id="root"]',
                        '#prompt-textarea',
                        'textarea[data-id="root"]',
                        'div[contenteditable="true"][role="textbox"]',
                        
                        // Perplexity - comprehensive selectors
                        'textarea[placeholder*="Ask anything"]',
                        'textarea[placeholder*="Ask follow-up"]',
                        'textarea[placeholder*="Ask"]',
                        'textarea[aria-label*="Ask"]',
                        'div[contenteditable="true"][aria-label*="Ask"]',
                        
                        // Google Search - all variations
                        'input[name="q"]',
                        'textarea[name="q"]',
                        'input[title="Search"]',
                        'input[aria-label*="Search"]',
                        'input[role="combobox"]',
                        'input[type="search"]',
                        
                        // General fallbacks with better filtering
                        'textarea:not([readonly]):not([disabled]):not([style*="display: none"]):not([style*="visibility: hidden"])',
                        'input[type="text"]:not([readonly]):not([disabled]):not([style*="display: none"]):not([style*="visibility: hidden"])',
                        'div[contenteditable="true"]:not([style*="display: none"]):not([style*="visibility: hidden"])'
                    ];
                    
                    let input = null;
                    let inputType = 'unknown';
                    
                    // Find the first visible and interactable input
                    for (const selector of selectors) {
                        const elements = document.querySelectorAll(selector);
                        for (const el of elements) {
                            const rect = el.getBoundingClientRect();
                            const style = window.getComputedStyle(el);
                            
                            if (rect.width > 0 && rect.height > 0 && 
                                style.display !== 'none' && 
                                style.visibility !== 'hidden' &&
                                !el.disabled && !el.readOnly) {
                                input = el;
                                inputType = el.tagName.toLowerCase();
                                break;
                            }
                        }
                        if (input) break;
                    }
                    
                    if (input) {
                        try {
                            // For Perplexity, be extra careful to avoid sidebar expansion
                            const isPerplexity = window.location.hostname.includes('perplexity');
                            
                            // For Perplexity, skip focus to avoid sidebar expansion
                            if (!isPerplexity) {
                                input.focus();
                            }
                            
                            // Wait for any focus effects to settle
                            setTimeout(() => {
                                try {
                                    // Direct text insertion instead of clipboard paste
                                    if (inputType === 'div') {
                                        // For contenteditable divs
                                        input.textContent = promptText;
                                        input.innerHTML = promptText; // Fallback
                                    } else {
                                        // For input/textarea elements
                                        input.value = promptText;
                                    }
                                    
                                    console.log('DIRECT SET: Set text to', promptText.substring(0, 50));
                                    
                                    // Fire comprehensive events to notify frameworks
                                    // For Perplexity, skip focus/blur events that might trigger UI changes
                                    const events = isPerplexity ? [
                                        new Event('input', { bubbles: true, cancelable: true }),
                                        new Event('change', { bubbles: true, cancelable: true })
                                    ] : [
                                        new Event('input', { bubbles: true, cancelable: true }),
                                        new Event('change', { bubbles: true, cancelable: true }),
                                        new Event('keyup', { bubbles: true, cancelable: true }),
                                        new Event('blur', { bubbles: true, cancelable: true }),
                                        new Event('focus', { bubbles: true, cancelable: true })
                                    ];
                                    
                                    events.forEach(event => {
                                        try {
                                            input.dispatchEvent(event);
                                        } catch (e) {
                                            console.log('Event error:', e);
                                        }
                                    });
                                    
                                    // React-specific events
                                    if (input._valueTracker) {
                                        input._valueTracker.setValue('');
                                    }
                                    
                                    const reactInputEvent = new Event('input', { bubbles: true });
                                    reactInputEvent.simulated = true;
                                    input.dispatchEvent(reactInputEvent);
                                    
                                    // Auto-submit after a short delay - PRIMARY METHOD: Click submit button
                                    setTimeout(() => {
                                        try {
                                            // Service-specific submit button selectors
                                            const submitSelectors = {
                                                chatgpt: [
                                                    'button[data-testid="send-button"]',
                                                    'button[data-testid="fruitjuice-send-button"]', 
                                                    'button#composer-submit-button',
                                                    'button[aria-label="Send message"]',
                                                    'button[aria-label="Send prompt"]'
                                                ],
                                                perplexity: [
                                                    'button[aria-label="Submit"]',
                                                    'button[aria-label="Submit Search"]',
                                                    'button[type="submit"]',
                                                    'button.bg-super',
                                                    'button:has(svg[data-icon="arrow-right"])'
                                                ],
                                                google: [
                                                    'button[aria-label="Search"]',
                                                    'button[type="submit"]',
                                                    'input[type="submit"]'
                                                ],
                                                default: [
                                                    'button[type="submit"]',
                                                    'button[aria-label*="Send"]',
                                                    'button[aria-label*="Submit"]',
                                                    'button:has(svg)',
                                                    'input[type="submit"]'
                                                ]
                                            };
                                            
                                            // Determine which selectors to use based on the current site
                                            const hostname = window.location.hostname;
                                            let selectors = submitSelectors.default;
                                            
                                            if (hostname.includes('chatgpt.com') || hostname.includes('chat.openai.com')) {
                                                selectors = submitSelectors.chatgpt;
                                            } else if (hostname.includes('perplexity.ai')) {
                                                selectors = submitSelectors.perplexity;
                                            } else if (hostname.includes('google.com')) {
                                                selectors = submitSelectors.google;
                                            }
                                            
                                            // Try to find and click the submit button
                                            let buttonClicked = false;
                                            for (const selector of selectors) {
                                                const submitBtn = document.querySelector(selector);
                                                if (submitBtn && !submitBtn.disabled) {
                                                    // For some sites, we might need to ensure the button is visible
                                                    const rect = submitBtn.getBoundingClientRect();
                                                    if (rect.width > 0 && rect.height > 0) {
                                                        submitBtn.click();
                                                        console.log('AUTO-SUBMIT: Clicked submit button with selector:', selector);
                                                        buttonClicked = true;
                                                        break;
                                                    }
                                                }
                                            }
                                            
                                            // FALLBACK: If button click didn't work, try Enter key as backup
                                            if (!buttonClicked) {
                                                console.log('AUTO-SUBMIT: No submit button found, trying Enter key fallback');
                                                
                                                const keydownEvent = new KeyboardEvent('keydown', {
                                                    key: 'Enter',
                                                    code: 'Enter',
                                                    keyCode: 13,
                                                    which: 13,
                                                    bubbles: true,
                                                    cancelable: true,
                                                    composed: true
                                                });
                                                
                                                const keyupEvent = new KeyboardEvent('keyup', {
                                                    key: 'Enter',
                                                    code: 'Enter',
                                                    keyCode: 13,
                                                    which: 13,
                                                    bubbles: true,
                                                    cancelable: true,
                                                    composed: true
                                                });
                                                
                                                input.dispatchEvent(keydownEvent);
                                                setTimeout(() => {
                                                    input.dispatchEvent(keyupEvent);
                                                }, 10);
                                            }
                                            
                                        } catch (e) {
                                            console.log('AUTO-SUBMIT ERROR:', e);
                                        }
                                    }, 300);
                                    
                                } catch (e) {
                                    console.log('DIRECT SET ERROR:', e);
                                }
                            }, 200);
                            
                            console.log('SUCCESS: Found input', inputType, input.placeholder || input.getAttribute('aria-label') || 'no-label');
                            return 'SUCCESS: Found ' + inputType;
                        } catch (e) {
                            console.log('ERROR setting up paste:', e);
                            return 'ERROR: ' + e.message;
                        }
                    } else {
                        console.log('ERROR: No suitable input found');
                        // Enhanced debugging
                        const allInputs = document.querySelectorAll('input, textarea, div[contenteditable]');
                        console.log('DEBUG: Found', allInputs.length, 'total input elements');
                        
                        // Log details about each input element for debugging
                        allInputs.forEach((el, i) => {
                            const rect = el.getBoundingClientRect();
                            const style = window.getComputedStyle(el);
                            console.log('INPUT', i, ':', {
                                tagName: el.tagName,
                                type: el.type || 'N/A',
                                placeholder: el.placeholder || 'N/A',
                                'aria-label': el.getAttribute('aria-label') || 'N/A',
                                'data-id': el.getAttribute('data-id') || 'N/A',
                                visible: rect.width > 0 && rect.height > 0,
                                display: style.display,
                                visibility: style.visibility,
                                disabled: el.disabled,
                                readonly: el.readOnly
                            });
                        });
                        
                        return 'ERROR: No input found (' + allInputs.length + ' total inputs)';
                    }
                })();
            """) { result, error in
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
        browserView.webView.evaluateJavaScript("""
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
    let browserView: BrowserView
    let service: AIService
    
    init(browserView: BrowserView, service: AIService) {
        self.browserView = browserView
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
            browserView.webView.load(URLRequest(url: url))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.browserView.webView.evaluateJavaScript("""
                // Try multiple common selectors for chat input fields
                const selectors = [
                    'textarea[placeholder*="message"]',
                    'textarea[placeholder*="Message"]', 
                    'textarea[data-id="root"]',
                    'textarea#prompt-textarea',
                    'div[contenteditable="true"]',
                    'textarea',
                    'input[type="text"]'
                ];
                
                let input = null;
                for (const selector of selectors) {
                    input = document.querySelector(selector);
                    if (input) {
                        console.log('Found input with selector:', selector);
                        break;
                    }
                }
                
                if (input) {
                    input.focus();
                    
                    // Small delay to ensure focus
                    setTimeout(() => {
                        document.execCommand('paste');
                        
                        // Another delay before submitting - PRIMARY METHOD: Click submit button
                        setTimeout(() => {
                            try {
                                // Claude-specific submit button selectors
                                const submitSelectors = [
                                    'button[aria-label="Send Message"]',
                                    'button[aria-label="Send"]',
                                    'button[data-testid="send-button"]',
                                    'button[type="submit"]',
                                    'button:has(svg[viewBox="0 0 32 32"])', // Claude's send icon
                                    'button.text-text-200:has(svg)',
                                    'div[role="button"][aria-label="Send Message"]'
                                ];
                                
                                let buttonClicked = false;
                                for (const selector of submitSelectors) {
                                    const submitBtn = document.querySelector(selector);
                                    if (submitBtn && !submitBtn.disabled) {
                                        // Ensure button is visible
                                        const rect = submitBtn.getBoundingClientRect();
                                        if (rect.width > 0 && rect.height > 0) {
                                            submitBtn.click();
                                            console.log('CLAUDE AUTO-SUBMIT: Clicked submit button with selector:', selector);
                                            buttonClicked = true;
                                            break;
                                        }
                                    }
                                }
                                
                                // FALLBACK: If button click didn't work, try Enter key
                                if (!buttonClicked) {
                                    console.log('CLAUDE AUTO-SUBMIT: No submit button found, trying Enter key fallback');
                                    
                                    const keydownEvent = new KeyboardEvent('keydown', {
                                        key: 'Enter',
                                        code: 'Enter',
                                        keyCode: 13,
                                        which: 13,
                                        bubbles: true,
                                        cancelable: true,
                                        composed: true
                                    });
                                    
                                    const keyupEvent = new KeyboardEvent('keyup', {
                                        key: 'Enter',
                                        code: 'Enter',
                                        keyCode: 13,
                                        which: 13,
                                        bubbles: true,
                                        cancelable: true,
                                        composed: true
                                    });
                                    
                                    input.dispatchEvent(keydownEvent);
                                    setTimeout(() => {
                                        input.dispatchEvent(keyupEvent);
                                    }, 10);
                                }
                            } catch (e) {
                                console.log('CLAUDE AUTO-SUBMIT ERROR:', e);
                            }
                        }, 200);
                    }, 100);
                } else {
                    console.log('No suitable input field found');
                }
            """)
        }
    }
}

// MARK: - ServiceManager

class ServiceManager: NSObject, ObservableObject {
    @Published var activeServices: [AIService] = []
    @Published var sharedPrompt: String = ""
    @Published var replyToAll: Bool = true
    @Published var loadingStates: [String: Bool] = [:]  // Track loading state per service (for UI only)
    var webServices: [String: WebService] = [:]
    private let processPool = WKProcessPool.shared  // Critical optimization
    private var isFirstSubmit: Bool = true  // Track if this is the first submit after load/reload
    
    override init() {
        super.init()
        setupServices()
    }
    
    private func setupServices() {
        for (index, service) in defaultServices.enumerated() where service.enabled {
            let webView = createWebView(for: service)
            let isFirstService = index == 0
            let browserView = BrowserView(webView: webView, service: service, isFirstService: isFirstService)
            
            let webService: WebService
            switch service.activationMethod {
            case .urlParameter:
                webService = URLParameterService(browserView: browserView, service: service)
            case .clipboardPaste:
                webService = ClaudeService(browserView: browserView, service: service)
            }
            
            webServices[service.id] = webService
            activeServices.append(service)
            loadingStates[service.id] = false
            
            // Load default homepage for each service
            loadDefaultPage(for: service, webView: webView)
        }
    }
    
    private func loadDefaultPage(for service: AIService, webView: WKWebView) {
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
            var request = URLRequest(url: url)
            // Add headers to prevent loading conflicts
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            // User-Agent is already set on the webView itself, no need to set it here
            
            // Add minimal delay to prevent race conditions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                webView.load(request)
            }
        }
    }
    
    func executePrompt(_ prompt: String, replyToAll: Bool = false) {
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
            NotificationCenter.default.post(name: .focusUnifiedInput, object: nil)
        }
    }
    
    func executeSharedPrompt() {
        guard !sharedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let promptToExecute = sharedPrompt // Store the prompt before clearing
        
        // Use "new chat" mode for first submit, then switch to "reply to all"
        let useReplyToAll = !isFirstSubmit && replyToAll
        
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
        }
    }
    
    func reloadAllServices() {
        for service in activeServices {
            if let webService = webServices[service.id] {
                loadingStates[service.id] = true
                loadDefaultPage(for: service, webView: webService.browserView.webView)
            }
        }
        
        // Reset to first submit mode after reload
        isFirstSubmit = true
        replyToAll = true  // Reset UI to default state
        
        // Clear loading states after a reasonable delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            for service in self.activeServices {
                self.loadingStates[service.id] = false
            }
        }
    }
    
    private func createWebView(for service: AIService) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        if #available(macOS 11.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        configuration.processPool = processPool
        
        // Prevent loading cancellations
        configuration.suppressesIncrementalRendering = false
        
        // Setup logging scripts and message handlers
        setupLoggingScripts(for: configuration, service: service)
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
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
        
        // Add navigation delegate to handle errors
        webView.navigationDelegate = self
        
        // Add UI delegate for context menus
        webView.uiDelegate = self
        
        // Re-enable navigation gestures after initial load
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            webView.allowsBackForwardNavigationGestures = true
        }
        
        return webView
    }
    
    func resetForNewPrompt() {
        // Don't stop loading during normal operation as it causes -999 errors
        // Only stop if absolutely necessary
    }
    
    private func setupLoggingScripts(for configuration: WKWebViewConfiguration, service: AIService) {
        let userContentController = configuration.userContentController
        
        // Create message handler for this service
        let messageHandler = ConsoleMessageHandler(service: service.name)
        
        // Add message handlers
        userContentController.add(messageHandler, name: "consoleLog")
        userContentController.add(messageHandler, name: "networkRequest")
        userContentController.add(messageHandler, name: "networkResponse")
        // userContentController.add(messageHandler, name: "domChange") // Disabled
        userContentController.add(messageHandler, name: "userInteraction")
        
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
    }
}

extension WKProcessPool {
    static let shared = WKProcessPool()
}

// MARK: - WKNavigationDelegate for ServiceManager

extension ServiceManager: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        print("ERROR WebView navigation failed: \(nsError.code) - \(nsError.localizedDescription)")
        // Don't retry automatically to prevent unresponsive processes
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        print("ERROR WebView provisional navigation failed: \(nsError.code) - \(nsError.localizedDescription)")
        // Don't retry automatically to prevent unresponsive processes
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let urlString = webView.url?.absoluteString ?? "unknown"
        print("SUCCESS WebView loaded successfully: \(urlString)")
    }
}

// MARK: - WKUIDelegate for ServiceManager

extension ServiceManager: WKUIDelegate {
    // Handle JavaScript alerts
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
} 
