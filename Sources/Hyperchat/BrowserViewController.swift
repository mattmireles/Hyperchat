import AppKit
import WebKit
import SwiftUI

class BrowserViewController: NSViewController {
    private let webView: WKWebView
    private let service: AIService
    private let browserView: BrowserView
    private let isFirstService: Bool
    
    // Button states
    private let backButtonState = ButtonState(isEnabled: false)
    private let forwardButtonState = ButtonState(isEnabled: false)
    
    // Allow focus capture after initial load delay
    private var allowFocusCapture = false
    private let instanceId = UUID().uuidString.prefix(8)
    
    init(webView: WKWebView, service: AIService, isFirstService: Bool = false) {
        self.webView = webView
        self.service = service
        self.isFirstService = isFirstService
        self.browserView = BrowserView(webView: webView, isFirstService: isFirstService)
        
        super.init(nibName: nil, bundle: nil)
        
        // Claim ownership of navigation delegate immediately
        webView.navigationDelegate = self
        
        let wvAddress = Unmanaged.passUnretained(webView).toOpaque()
        let retainCount = CFGetRetainCount(webView)
        print("🟢 [\(Date().timeIntervalSince1970)] BrowserViewController INIT \(instanceId) for \(service.name), WebView at \(wvAddress), retain count: \(retainCount)")
        
        // Enable focus capture after initial load delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.allowFocusCapture = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("🔴 [\(Date().timeIntervalSince1970)] BrowserViewController DEINIT \(instanceId) for \(service.name)")
    }
    
    override func loadView() {
        self.view = browserView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupToolbarButtons()
    }
    
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
    
    @objc private func copyURL() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        // Copy the full URL, not the cleaned display version
        if let fullURL = webView.url?.absoluteString {
            pasteboard.setString(fullURL, forType: .string)
        }
    }
    
    private func updateBackButton() {
        // Update the SwiftUI button states
        backButtonState.isEnabled = webView.canGoBack
        forwardButtonState.isEnabled = webView.canGoForward
    }
    
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
}

// MARK: - Responder chain handling

extension BrowserViewController {
    override var acceptsFirstResponder: Bool {
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
}

// MARK: - WKNavigationDelegate

extension BrowserViewController: WKNavigationDelegate {
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
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        WebViewLogger.shared.logPageLoad(start: false, service: service.name, url: webView.url)
        
        // Final update when navigation finishes
        DispatchQueue.main.async { [weak self] in
            let fullURL = webView.url?.absoluteString ?? ""
            self?.browserView.urlField.stringValue = self?.cleanURLForDisplay(fullURL) ?? ""
            self?.browserView.urlField.toolTip = fullURL.isEmpty ? "Enter URL..." : fullURL
            self?.updateBackButton()
        }
    }
    
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
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        WebViewLogger.shared.logNavigationResponse(navigationResponse.response, service: service.name)
        decisionHandler(.allow)
    }
}