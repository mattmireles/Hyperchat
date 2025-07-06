**A Developer's Field Guide to macOS Browser Automation with WKWebView**

---

# WKWebView macOS Technical Reference

## 1. Critical Architecture Facts

- **Out-of-process**: Web content runs in separate `com.apple.WebKit.WebContent` process
- **Resource intensive**: Each WKWebView launches processes for rendering and networking
- **Configuration immutable**: WKWebViewConfiguration cannot be changed after WKWebView initialization
- **Process crashes**: Sandbox violations instantly terminate WebContent process → blank white screen

## 2. Configuration

### Framework Integration
```swift
// AppKit
let webView = WKWebView(frame: .zero, configuration: config)
viewController.view.addSubview(webView)

// SwiftUI - MUST use NSViewRepresentable (not UIViewRepresentable)
struct WebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
```

### Network Interception
- **WKURLSchemeHandler**: Only works for custom schemes, NOT http/https
- **Modern solution**: `WKWebsiteDataStore.proxyConfigurations` (iOS 17+) for full request interception

### Essential Configuration Properties
```swift
let config = WKWebViewConfiguration()

// Process sharing across multiple WKWebViews
config.processPool = WKProcessPool.shared  // Share cookies/cache

// Data persistence
config.websiteDataStore = .default()        // Persistent
config.websiteDataStore = .nonPersistent()  // Ephemeral (no disk traces)
// Note: HTML5 localStorage may be cleared when app exits even with persistent store

// JavaScript bridge
config.userContentController = WKUserContentController()

// Preferences
config.preferences.javaScriptCanOpenWindowsAutomatically = true  // Required for window.open()
config.defaultWebpagePreferences.allowsContentJavaScript = true
config.preferences.isElementFullscreenEnabled = true
config.preferences.isFraudulentWebsiteWarningEnabled = false

// Enable find bar (Cmd+F)
webView.findInteractionEnabled = true

// Modern user agent
webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
```

## 3. Navigation & State Management

### WKNavigationDelegate Critical Methods
```swift
// KVO for progress tracking
webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
webView.addObserver(self, forKeyPath: "isLoading", options: .new, context: nil)

// Decision point - block/allow navigation
func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, 
             decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    // Check navigationAction.request.url
    decisionHandler(.allow)  // or .cancel
    // WARNING: Must call decisionHandler or app crashes after timeout
}

// Loading states
func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!)
func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)
// Error before content loads (DNS failure, no connection)
func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error)
// Error during/after content loads
func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error)

// Authentication
func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
             completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    // MUST call completionHandler or app crashes
    completionHandler(.performDefaultHandling, nil)
}

// Process termination
func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    webView.reload()  // Common recovery strategy
}
```

### Common Issues
- **Memory leaks**: Reuse WKWebView instances, don't create new ones repeatedly
- **Cookie persistence**: Use `WKHTTPCookieStore` to manually sync cookies
- **CORS errors**: `file://` XHRs blocked by default, no override available (security feature, not bug)

## 4. JavaScript Bridge

### Native → JavaScript
```swift
// Basic execution
webView.evaluateJavaScript("document.getElementById('button').click()")

// With result handling
webView.evaluateJavaScript("document.title") { result, error in
    if let title = result as? String { }
}

// Modern async/await wrapper
func evaluateJS(_ script: String) async throws -> Any? {
    try await withCheckedThrowingContinuation { continuation in
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: result)
            }
        }
    }
}
```

### Alternative: Read All Content (Including iFrames)
```swift
// Captures complete DOM including cross-origin iframes
webView.createWebArchiveData { data, error in
    guard let data = data else { return }
    // Parse the web archive plist to extract all HTML content
    let archive = try? PropertyListSerialization.propertyList(from: data, format: nil)
    // Contains all iframe content without CORS restrictions
}
```

### JavaScript → Native
```swift
// Register handler
config.userContentController.add(self, name: "nativeAPI")

// JavaScript usage
// window.webkit.messageHandlers.nativeAPI.postMessage({cmd: "data", value: 123})

// Handle messages
func userContentController(_ userContentController: WKUserContentController, 
                          didReceive message: WKScriptMessage) {
    guard message.name == "nativeAPI",
          let body = message.body as? [String: Any] else { return }
    // Process message.body - NEVER trust this data
}

// With reply (iOS 14+)
config.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "apiWithReply")

func userContentController(_ userContentController: WKUserContentController,
                          didReceive message: WKScriptMessage,
                          replyHandler: @escaping (Any?, String?) -> Void) {
    replyHandler(["status": "ok"], nil)
}
```

### Script Injection
```swift
// Isolated execution (iOS 14+/macOS 11+)
let script = WKUserScript(source: jsCode, 
                         injectionTime: .atDocumentStart,  // or .atDocumentEnd
                         forMainFrameOnly: false,           // false = inject in iframes too
                         in: .world(name: "myAgent"))       // isolated namespace

config.userContentController.addUserScript(script)

// Content worlds
.page            // Webpage's own scripts
.defaultClient   // App's default world
.world(name: "x") // Custom isolated world
```

## 5. User Interaction Simulation

### The isTrusted Problem
- **Fact**: `event.isTrusted` is read-only, always `false` for script-created events
- **Implication**: Sites can detect and ignore simulated events with `if (!event.isTrusted) return`
- **Workaround**: Find and call underlying functions directly instead of simulating events

### Text Input (Most Reliable Method)
```javascript
function simulateTyping(selector, text) {
    const element = document.querySelector(selector);
    element.focus();
    element.value = text;
    
    // Critical: dispatch 'input' event for React/Vue/Angular
    element.dispatchEvent(new Event('input', { bubbles: true }));
    
    // Optional: dispatch keyboard events if site needs them
    element.dispatchEvent(new KeyboardEvent('keydown', { key: text.slice(-1), bubbles: true }));
    element.dispatchEvent(new KeyboardEvent('keyup', { key: text.slice(-1), bubbles: true }));
}
```

### Mouse Click Simulation
```javascript
// Level 1: Simple (usually sufficient)
element.click();

// Level 2: Full event sequence (for picky sites)
function simulateClick(element) {
    ['mousedown', 'mouseup', 'click'].forEach(eventType => {
        element.dispatchEvent(new MouseEvent(eventType, {
            bubbles: true,
            cancelable: true,
            view: window
        }));
    });
}
```

### Waiting for Dynamic Content
```javascript
// Note: didFinish only fires on full page loads, not SPA navigation

// Best method: MutationObserver
function waitForElement(selector) {
    return new Promise(resolve => {
        if (document.querySelector(selector)) {
            return resolve(document.querySelector(selector));
        }
        
        const observer = new MutationObserver(() => {
            const element = document.querySelector(selector);
            if (element) {
                observer.disconnect();
                resolve(element);
            }
        });
        
        observer.observe(document.body, { childList: true, subtree: true });
    });
}

// Usage from Swift
await webView.evaluateJavaScript("""
    await waitForElement('#dynamic-content');
    window.webkit.messageHandlers.ready.postMessage('found');
""")
```

## 6. Popup Handling

### Enable window.open()
```swift
// Required configuration
config.preferences.javaScriptCanOpenWindowsAutomatically = true

// Implement WKUIDelegate
func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
             for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    let popup = WKWebView(frame: view.bounds, configuration: configuration)
    popup.uiDelegate = self
    view.addSubview(popup)
    return popup
}

func webViewDidClose(_ webView: WKWebView) {
    webView.removeFromSuperview()
}

// For OAuth flows, prefer ASWebAuthenticationSession
import AuthenticationServices

let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "myapp") { url, error in
    // Handle OAuth callback
}
session.presentationContextProvider = self
session.start()
```

## 7. Debugging

### Enable Web Inspector
```swift
#if DEBUG
if #available(macOS 13.3, *) {
    webView.isInspectable = true
} else {
    // Older versions - private API
    webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
}
#endif
```

**Requirements**:
1. Safari > Settings > Advanced > "Show Develop menu"
2. Device: Settings > Safari > Advanced > Web Inspector (physical devices only)
3. Debug builds only (not TestFlight/App Store/archived apps)

**Sandbox Debugging**: Check Console.app for sandboxd messages when debugging permission issues

## 8. App Sandbox

### Required Entitlements
```xml
<!-- Network access - MANDATORY for any internet access -->
<key>com.apple.security.network.client</key>
<true/>

<!-- Server (only if running local server) -->
<key>com.apple.security.network.server</key>
<true/>

<!-- File access -->
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

### Loading Local Files
```swift
// Correct method - grants temporary sandbox extension
let fileURL = Bundle.main.url(forResource: "index", withExtension: "html")!
let directoryURL = fileURL.deletingLastPathComponent()
webView.loadFileURL(fileURL, allowingReadAccessTo: directoryURL)

// Wrong - causes sandbox violation
webView.load(URLRequest(url: fileURL))  // Crash!
```

## 9. Anti-Bot Evasion

### Fingerprinting Vectors & Countermeasures

| Vector | Detection Method | Evasion |
|--------|-----------------|----------|
| User-Agent | HTTP header | `webView.customUserAgent = "common UA string"` |
| Canvas | Hash of rendered pixels | Override `toDataURL()` to add noise |
| WebGL | GPU parameters | Override `getParameter()` to return generic values |
| WebRTC | IP leak via STUN | Block STUN servers with WKContentRuleList |
| Fonts | Measure rendered dimensions | Use clean OS install with default fonts only |
| IP Address | Network request | Use proxy: `dataStore.proxyConfigurations` (iOS 17+) |
| Behavioral | Mouse patterns, typing cadence | Use curved paths (not straight lines), vary timing |

### Canvas Fingerprint Spoofing
```javascript
// Inject at document start
const originalToDataURL = HTMLCanvasElement.prototype.toDataURL;
HTMLCanvasElement.prototype.toDataURL = function() {
    const context = this.getContext('2d');
    const imageData = context.getImageData(0, 0, this.width, this.height);
    
    // Add random noise to defeat fingerprinting
    for (let i = 0; i < imageData.data.length; i += 4) {
        imageData.data[i] += Math.random() * 2 - 1;     // R
        imageData.data[i+1] += Math.random() * 2 - 1;   // G
        imageData.data[i+2] += Math.random() * 2 - 1;   // B
    }
    context.putImageData(imageData, 0, 0);
    
    return originalToDataURL.apply(this, arguments);
};
```

### WebGL Fingerprint Spoofing
```javascript
// Override getParameter to return generic values
const getParameter = WebGLRenderingContext.prototype.getParameter;
WebGLRenderingContext.prototype.getParameter = function(parameter) {
    if (parameter === 37445) return 'Intel Inc.'; // UNMASKED_VENDOR_WEBGL
    if (parameter === 37446) return 'Intel Iris OpenGL Engine'; // UNMASKED_RENDERER_WEBGL
    return getParameter.apply(this, arguments);
};
```

### AudioContext Fingerprint Spoofing
```javascript
// Add noise to audio fingerprinting
const createAnalyser = AudioContext.prototype.createAnalyser;
AudioContext.prototype.createAnalyser = function() {
    const analyser = createAnalyser.apply(this, arguments);
    const getFloatFrequencyData = analyser.getFloatFrequencyData;
    analyser.getFloatFrequencyData = function(array) {
        getFloatFrequencyData.apply(this, arguments);
        for (let i = 0; i < array.length; i++) {
            array[i] += Math.random() * 0.0001;
        }
    };
    return analyser;
};
```

### Content Blocking
```swift
// Block ads/trackers to reduce fingerprinting surface
let rules = """
[{
    "trigger": {"url-filter": ".*", "url-filter-is-case-sensitive": false, 
                "resource-type": ["script"], "load-type": ["third-party"]},
    "action": {"type": "block"}
}]
"""

WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "blocklist",
    encodedContentRuleList: rules) { list, error in
    config.userContentController.add(list!)
}
```

## 10. Cross-Origin iFrames

### Strategy: Inject Everywhere, Communicate via Native
```swift
// 1. Inject script in all frames
let script = WKUserScript(source: bridgeCode, 
                         injectionTime: .atDocumentStart,
                         forMainFrameOnly: false)  // Critical: false

// 2. Each frame can message native
// iframe: window.webkit.messageHandlers.bridge.postMessage({frame: "iframe1", data: value})
// main: window.webkit.messageHandlers.bridge.postMessage({frame: "main", data: value})

// 3. Native routes messages between frames
func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
    let body = message.body as! [String: Any]
    let frame = body["frame"] as! String
    
    if frame == "iframe1" {
        // Send to main frame
        webView.evaluateJavaScript("handleIframeData('\(body["data"])')")
    }
}
```

## 11. Performance & Memory

### WKWebView Pooling
```swift
class WebViewPool {
    private var available: [WKWebView] = []
    private let config: WKWebViewConfiguration
    
    func acquire() -> WKWebView {
        if let webView = available.popLast() {
            return webView
        }
        return WKWebView(frame: .zero, configuration: config)
    }
    
    func release(_ webView: WKWebView) {
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)  // Clear content
        available.append(webView)
    }
}
```

### Critical Performance Tips
- Share single `WKProcessPool` across all WKWebViews
- Reuse WKWebView instances (pool pattern)
- Clear cookies between sessions: `dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())`
- Monitor memory with Instruments, not Activity Monitor (WKWebView memory shows under your app, not WebContent process)

## 12. Private APIs (App Store Rejection Risk)

### CGS/SkyLight Framework
```swift
// Space/window management
@_silgen_name("CGSDefaultConnection") func CGSDefaultConnection() -> Int32
@_silgen_name("CGSGetActiveSpace") func CGSGetActiveSpace(_ cid: Int32) -> Int
@_silgen_name("CGSAddWindowsToSpaces") func CGSAddWindowsToSpaces(_ cid: Int32, _ windows: CFArray, _ spaces: CFArray)
```

### Legacy Methods Still in Use
```objc
// Pre-iOS 14 script injection
[webView stringByEvaluatingJavaScriptFromString:@"script"];

// Force refresh
[webView _reloadFromOrigin];
```