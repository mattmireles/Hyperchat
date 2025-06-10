import Foundation
import WebKit
import SwiftUI

// MARK: - Browser View with Controls

class BrowserView: NSView {
    let webView: WKWebView
    private let urlField: NSTextField
    private let backButton: NSButton
    private let reloadButton: NSButton
    private let service: AIService
    
    init(webView: WKWebView, service: AIService) {
        self.webView = webView
        self.service = service
        
        // Create controls
        self.backButton = NSButton()
        self.reloadButton = NSButton()
        self.urlField = NSTextField()
        
        super.init(frame: .zero)
        
        setupControls()
        setupLayout()
        setupWebViewDelegate()
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupControls() {
        // Back button
        backButton.title = "←"
        backButton.bezelStyle = .rounded
        backButton.target = self
        backButton.action = #selector(goBack)
        
        // Reload button
        reloadButton.title = "↻"
        reloadButton.bezelStyle = .rounded
        reloadButton.target = self
        reloadButton.action = #selector(reload)
        
        // Copy button
        let copyButton = NSButton()
        copyButton.title = "📋"
        copyButton.bezelStyle = .rounded
        copyButton.target = self
        copyButton.action = #selector(copyURL)
        
        // URL field
        urlField.isEditable = true
        urlField.cell?.sendsActionOnEndEditing = true
        urlField.target = self
        urlField.action = #selector(loadURL)
        urlField.placeholderString = "Enter URL..."
        
        // Service label
        let serviceLabel = NSTextField(labelWithString: service.name)
        serviceLabel.font = NSFont.boldSystemFont(ofSize: 12)
        serviceLabel.textColor = .secondaryLabelColor
        
        // Create toolbar
        let toolbar = NSStackView(views: [serviceLabel, backButton, reloadButton, copyButton, urlField])
        toolbar.orientation = .horizontal
        toolbar.spacing = 8
        toolbar.distribution = .fill
        
        // Set priorities to make URL field expand
        urlField.setContentHuggingPriority(NSLayoutConstraint.Priority(249), for: .horizontal)
        
        addSubview(toolbar)
        addSubview(webView)
        
        // Layout constraints
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Toolbar at top
            toolbar.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            toolbar.heightAnchor.constraint(equalToConstant: 24),
            
            // WebView below toolbar
            webView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 8),
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
        backButton.isEnabled = webView.canGoBack
    }
}

extension BrowserView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Update URL as soon as navigation starts
        DispatchQueue.main.async { [weak self] in
            self?.urlField.stringValue = webView.url?.absoluteString ?? ""
            self?.updateBackButton()
        }
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // Update URL when navigation commits
        DispatchQueue.main.async { [weak self] in
            self?.urlField.stringValue = webView.url?.absoluteString ?? ""
            self?.updateBackButton()
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Final update when navigation finishes
        DispatchQueue.main.async { [weak self] in
            self?.urlField.stringValue = webView.url?.absoluteString ?? ""
            self?.updateBackButton()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Update even on failure
        DispatchQueue.main.async { [weak self] in
            self?.urlField.stringValue = webView.url?.absoluteString ?? ""
            self?.updateBackButton()
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // Handle provisional navigation failures
        DispatchQueue.main.async { [weak self] in
            self?.urlField.stringValue = webView.url?.absoluteString ?? ""
            self?.updateBackButton()
        }
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
            // Use clipboard paste for Reply to All mode
            pastePromptIntoCurrentPage(prompt)
        } else {
            // New Chat mode: Use URL parameters for all services
            guard case .urlParameter = service.activationMethod,
                  let config = ServiceConfigurations.config(for: service.id) else { return }
            
            let urlString = config.buildURL(with: prompt)
            print("🔗 \(service.name): Loading URL: \(urlString)")
            
            if let url = URL(string: urlString) {
                browserView.webView.load(URLRequest(url: url))
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
                    
                    // Enhanced service-specific selectors
                    const selectors = [
                        // ChatGPT - try multiple known selectors
                        'div[contenteditable="true"][data-id="root"]',
                        '#prompt-textarea',
                        'textarea[data-id="root"]',
                        'textarea[placeholder*="Message ChatGPT"]',
                        'textarea[placeholder*="Send a message"]',
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
                            // Focus the input
                            input.focus();
                            input.click();
                            
                            // Wait for focus to take effect
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
                                    const events = [
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
                }
            }
        }
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
                    input.click();
                    
                    // Small delay to ensure focus
                    setTimeout(() => {
                        document.execCommand('paste');
                        
                        // Another delay before submitting
                        setTimeout(() => {
                            // Try Enter key
                            const enterEvent = new KeyboardEvent('keydown', { 
                                key: 'Enter', 
                                keyCode: 13, 
                                bubbles: true 
                            });
                            input.dispatchEvent(enterEvent);
                            
                            // Also try looking for a submit button as backup
                            const submitBtn = document.querySelector('button[data-testid="send-button"], button[type="submit"], button:contains("Send")');
                            if (submitBtn) {
                                submitBtn.click();
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
    @Published var replyToAll: Bool = false
    @Published var loadingStates: [String: Bool] = [:]  // Track loading state per service (for UI only)
    var webServices: [String: WebService] = [:]
    private let processPool = WKProcessPool.shared  // Critical optimization
    
    override init() {
        super.init()
        setupServices()
    }
    
    private func setupServices() {
        for service in defaultServices where service.enabled {
            let webView = createWebView()
            let browserView = BrowserView(webView: webView, service: service)
            
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
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            
            // Give each service a small delay to prevent conflicts
            let delay = service.id == "google" ? 2.0 : 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
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
                    // New Chat mode: use URL navigation with slight delay
                    if service.id == "google" {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            webService.executePrompt(prompt, replyToAll: false)
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            webService.executePrompt(prompt, replyToAll: false)
                        }
                    }
                }
            }
        }
    }
    
    func executeSharedPrompt() {
        guard !sharedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let promptToExecute = sharedPrompt // Store the prompt before clearing
        
        if replyToAll {
            // Reply to All Mode: Paste into current pages immediately
            executePrompt(promptToExecute, replyToAll: true)
            // Clear the prompt after sending
            sharedPrompt = ""
        } else {
            // New Chat Mode: Reload each service first, then send prompt after short delay
            reloadAllServices()
            // Clear the prompt immediately for UI feedback
            sharedPrompt = ""
            
            // Use a much shorter delay - 2 seconds instead of 4
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.executePrompt(promptToExecute, replyToAll: false)
            }
        }
    }
    
    func reloadAllServices() {
        for service in activeServices {
            if let webService = webServices[service.id] {
                loadingStates[service.id] = true
                loadDefaultPage(for: service, webView: webService.browserView.webView)
            }
        }
        
        // Clear loading states after a reasonable delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            for service in self.activeServices {
                self.loadingStates[service.id] = false
            }
        }
    }
    
    private func createWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        if #available(macOS 11.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        configuration.processPool = processPool
        
        // Prevent loading cancellations
        configuration.suppressesIncrementalRendering = false
        
        let userAgent = UserAgentGenerator.generate()
        configuration.applicationNameForUserAgent = userAgent.applicationName
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = userAgent.fullUserAgent
        
        // Enable interactions
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        
        // Set valid preferences
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        // Add navigation delegate to handle errors
        webView.navigationDelegate = self
        
        return webView
    }
    
    func resetForNewPrompt() {
        // Don't stop loading during normal operation as it causes -999 errors
        // Only stop if absolutely necessary
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