/// ClaudeLoginAlertView.swift - Claude Login Alert Content
///
/// This file contains the SwiftUI view for the Claude login alert window.
/// It displays special instructions and a WebView for Claude login.
///
/// Key responsibilities:
/// - Display special instructions about Claude login process
/// - Provide WebView for Claude authentication
/// - Detect successful login and call completion handler
/// - Provide close/cancel button
///
/// Related files:
/// - `ClaudeLoginAlertController.swift`: Creates this view and handles window
/// - `ClaudeLoginView.swift`: Original onboarding version for reference
/// - `WebViewRepresentable`: Shared WebView wrapper component
///
/// Instructions shown:
/// - Special note about not clicking email confirmation button
/// - Instructions to right-click and copy link instead
/// - Explanation of why this is necessary

import SwiftUI
import WebKit

/// Claude login alert content view
struct ClaudeLoginAlertView: View {
    /// Callback when login is completed
    let onComplete: () -> Void
    
    /// Callback for cancellation
    let onCancel: () -> Void
    
    /// Whether the view has appeared (for animations)
    @State private var hasAppeared = false
    
    /// Current URL being displayed
    @State private var currentURL = "https://claude.ai/login"
    
    /// Whether the page is loading
    @State private var isLoading = true
    
    /// Reference to the WebView for reload functionality
    @State private var webView: WKWebView?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Special instructions
            instructionsView
            
            // WebView
            webViewSection
            
            // Bottom buttons
            bottomButtonsView
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                hasAppeared = true
            }
        }
    }
    
    /// Header with title
    private var headerView: some View {
        HStack {
            Text("Claude Setup")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -20)
    }
    
    /// Special instructions text
    private var instructionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SPECIAL INSTRUCTIONS: Claude Setup")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("If you don't choose Google Login, Claude will send you a login confirmation email – DO NOT CLICK ON THE BUTTON IN THE EMAIL like you normally would. Instead, right-click on the button in the confirmation email and choose \"Copy Link.\" Paste that link into the URL bar above, into the Claude URL bar.")
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            Text("If you click the button, it will open and confirm in your regular browser, and you won't be logged in within Hyperchat. Sorry for the complication.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -10)
    }
    
    /// WebView section
    private var webViewSection: some View {
        ZStack {
            // WebView
            ClaudeWebViewRepresentable(
                url: currentURL,
                onLoadingChange: { loading in
                    isLoading = loading
                },
                onURLChange: { url in
                    currentURL = url
                },
                onLoginDetected: {
                    // Login was successful
                    onComplete()
                },
                onWebViewCreated: { createdWebView in
                    DispatchQueue.main.async {
                        webView = createdWebView
                    }
                }
            )
            
            // Loading indicator
            if isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                    
                    Text("Loading Claude...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
            }
        }
        .background(Color.black.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
    }
    
    /// Bottom navigation buttons
    private var bottomButtonsView: some View {
        HStack(spacing: 15) {
            // Cancel button
            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(AlertButtonStyle(isPrimary: false))
            
            Spacer()
            
            // Continue button (in case they want to proceed without logging in)
            Button("Continue Without Claude") {
                onCancel()
            }
            .buttonStyle(AlertButtonStyle(isPrimary: true))
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 20)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
    }
}

/// Custom button style for alert buttons
struct AlertButtonStyle: ButtonStyle {
    let isPrimary: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(isPrimary ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isPrimary ? Color.blue : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isPrimary ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// SwiftUI wrapper for WKWebView specifically for Claude login
struct ClaudeWebViewRepresentable: NSViewRepresentable {
    let url: String
    let onLoadingChange: (Bool) -> Void
    let onURLChange: (String) -> Void
    let onLoginDetected: () -> Void
    let onWebViewCreated: (WKWebView) -> Void
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        
        // Notify parent that WebView has been created
        onWebViewCreated(webView)
        
        // Load initial URL
        if let url = URL(string: url) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Handle URL changes if needed
    }
    
    func makeCoordinator() -> ClaudeWebViewCoordinator {
        ClaudeWebViewCoordinator(
            onLoadingChange: onLoadingChange,
            onURLChange: onURLChange,
            onLoginDetected: onLoginDetected
        )
    }
}

/// Navigation coordinator for the Claude login WebView
class ClaudeWebViewCoordinator: NSObject, WKNavigationDelegate {
    let onLoadingChange: (Bool) -> Void
    let onURLChange: (String) -> Void
    let onLoginDetected: () -> Void
    
    init(onLoadingChange: @escaping (Bool) -> Void, onURLChange: @escaping (String) -> Void, onLoginDetected: @escaping () -> Void) {
        self.onLoadingChange = onLoadingChange
        self.onURLChange = onURLChange
        self.onLoginDetected = onLoginDetected
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        onLoadingChange(true)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onLoadingChange(false)
        
        if let url = webView.url {
            onURLChange(url.absoluteString)
            
            // Simple login detection - if we're on claude.ai and not on login page
            if url.host?.contains("claude.ai") == true &&
               !url.path.contains("login") &&
               !url.path.contains("auth") {
                // User appears to be logged in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // Add a small delay to ensure page is fully loaded
                    self.onLoginDetected()
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onLoadingChange(false)
        print("Claude WebView navigation failed: \(error.localizedDescription)")
    }
}