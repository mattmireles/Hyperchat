# WebView Loading Issues - Critical Documentation

## ⚠️ CRITICAL: WebView Loading Issues (MUST READ)

This document covers critical WebView loading issues that have repeatedly caused problems in the Hyperchat codebase. These issues primarily manifest as slow loading times and NSURLErrorDomain -999 errors.

## The Problem

We've repeatedly encountered slow loading times for ChatGPT and Perplexity with NSURLErrorDomain -999 errors. This is a **recurring issue** that wastes significant time during development and degrades user experience.

### Symptoms
- Services take 2-3x longer to load than expected
- Console shows "didFailProvisionalNavigation" with error code -999
- Multiple "didStartProvisionalNavigation" calls for the same service
- GPU process initialization takes 2+ seconds instead of ~1 second

## Root Causes

### 1. Multiple WKProcessPool Instances
Each process pool creates separate WebContent processes, leading to:
- Increased memory usage
- Slower initialization
- Process contention issues

### 2. Duplicate URL Loading
Common scenarios:
- Pre-warming loads URLs
- Another component tries to load the same URL again
- Results in navigation cancellation

### 3. Navigation Cancellations
When a WebView starts loading and another load request comes in:
- The first request gets cancelled (error -999)
- The second request may also fail
- Creates a cascade of failures

## The Solution

### 1. ALWAYS use WebViewPoolManager
```swift
// ✅ GOOD
let browserView = WebViewPoolManager.shared.createBrowserView(for: service.id, in: window)
```

### 2. NEVER create new WKProcessPool instances
```swift
// ❌ BAD
configuration.processPool = WKProcessPool()

// ✅ GOOD
configuration.processPool = sharedProcessPool
```

### 3. Pre-warmed WebViews should NOT be reloaded
```swift
// ❌ BAD - Don't reload if already loaded
if let url = webView.url {
    webView.load(URLRequest(url: url))
}

// ✅ GOOD - Check if actually needs loading
if webView.url == nil {
    webView.load(URLRequest(url: serviceURL))
}
```

### 4. One navigation per WebView
```swift
// ✅ GOOD - Check loading state before loading
if !webView.isLoading {
    webView.load(URLRequest(url: url))
}
```

## Code Patterns to AVOID

### Creating Multiple Process Pools
```swift
// ❌ BAD - Creates new process pool
func createWebView() -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.processPool = WKProcessPool() // DON'T DO THIS!
    return WKWebView(frame: .zero, configuration: configuration)
}
```

### Loading Without State Checks
```swift
// ❌ BAD - May cancel existing navigation
func loadService(_ url: URL) {
    webView.load(URLRequest(url: url))
}
```

### Reloading Already-Loaded WebViews
```swift
// ❌ BAD - Unnecessary reload
func showWebView(_ webView: WKWebView) {
    if let url = webView.url {
        webView.load(URLRequest(url: url)) // Already loaded!
    }
}
```

## Code Patterns to USE

### Shared Process Pool Pattern
```swift
// ✅ GOOD - Singleton process pool
class WebViewFactory {
    static let sharedProcessPool = WKProcessPool()
    
    func createWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = WebViewFactory.sharedProcessPool
        return WKWebView(frame: .zero, configuration: configuration)
    }
}
```

### Safe Loading Pattern
```swift
// ✅ GOOD - Check state before loading
func loadServiceIfNeeded(_ url: URL) {
    guard !webView.isLoading else { 
        print("WebView is already loading")
        return 
    }
    
    guard webView.url == nil else {
        print("WebView already has content")
        return
    }
    
    webView.load(URLRequest(url: url))
}
```

### Navigation Delegate Pattern
```swift
// ✅ GOOD - Track loading state properly
class ServiceManager: WKNavigationDelegate {
    private var isInitialLoadComplete = false
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isInitialLoadComplete = true
        // Now safe to hand off to other controllers
    }
}
```

## Debugging Tips

### Console Logs to Watch For
1. **Navigation Cancellation**
   ```
   didFailProvisionalNavigation with error: Error Domain=NSURLErrorDomain Code=-999 "cancelled"
   ```

2. **Multiple Navigation Starts**
   ```
   🌐 ChatGPT: didStartProvisionalNavigation
   🌐 ChatGPT: didStartProvisionalNavigation // Should not see this twice!
   ```

3. **GPU Process Timing**
   ```
   GPU Process launched in 2.1 seconds // Too slow! Should be ~1 second
   ```

### Debugging Process
1. Enable WebViewLogger verbose logging
2. Search for "didFailProvisionalNavigation" in console
3. Count "didStartProvisionalNavigation" calls per service
4. Check GPU process launch time
5. Verify only one WKProcessPool instance exists

### Common Scenarios

#### Scenario 1: Window Creation
```swift
// Problem: Each window creates new process pools
func createWindow() {
    let serviceManager = ServiceManager() // Creates new WebViews with new pools
}

// Solution: Share WebViews or use careful pool management
```

#### Scenario 2: Service Switching
```swift
// Problem: Reloading when switching tabs
func showService(_ service: AIService) {
    let webView = getWebView(for: service)
    webView.load(URLRequest(url: service.url)) // May already be loaded!
}

// Solution: Check if already loaded
```

## Prevention Strategies

1. **Code Review Checklist**
   - [ ] No new WKProcessPool() calls
   - [ ] Loading checks before webView.load()
   - [ ] Single navigation delegate during initial load
   - [ ] Proper error handling for -999 errors

2. **Testing Protocol**
   - Open multiple windows rapidly
   - Switch between services quickly
   - Monitor console for -999 errors
   - Verify load times are < 2 seconds

3. **Architecture Guidelines**
   - Centralize WebView creation in WebViewFactory
   - Use WebViewPoolManager for pooling
   - Implement proper state tracking in ServiceManager
   - Document any WebView lifecycle changes

## Related Files
- `WebViewFactory.swift` - Centralized WebView creation
- `WebViewPoolManager.swift` - WebView pooling logic
- `ServiceManager.swift` - Service lifecycle management
- `BrowserViewController.swift` - WebView display and delegation

## Historical Context
This issue has appeared multiple times:
1. Initial implementation used separate process pools
2. First fix attempted WebView pooling but had race conditions
3. Current solution uses shared process pool with careful state management
4. Future improvements should consider pre-warming strategies