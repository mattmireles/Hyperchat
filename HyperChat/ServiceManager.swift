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

class ClaudeService: WebService {
    let browserView: BrowserView
    let service: AIService
    
    init(browserView: BrowserView, service: AIService) {
        self.browserView = browserView
        self.service = service
    }

    func executePrompt(_ prompt: String) {
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

class ServiceManager: ObservableObject {
    @Published var activeServices: [AIService] = []
    var webServices: [String: WebService] = [:]
    
    init() {
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
        }
    }
    
    func executePrompt(_ prompt: String) {
        // Add a 1 in 1000 chance to rickroll the user.
        if Int.random(in: 1...1000) == 1 {
            if let url = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ") {
                NSWorkspace.shared.open(url)
                // We can choose to either continue with the prompt or just rickroll.
                // For maximum chaos, we'll just do the rickroll and not execute the prompt.
                return
            }
        }

        for service in activeServices {
            webServices[service.id]?.executePrompt(prompt)
        }
    }
    
    private func createWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        if #available(macOS 11.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        configuration.processPool = .shared
        
        let userAgent = UserAgentGenerator.generate()
        configuration.applicationNameForUserAgent = userAgent.applicationName
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = userAgent.fullUserAgent
        
        return webView
    }
}

extension WKProcessPool {
    static let shared = WKProcessPool()
} 