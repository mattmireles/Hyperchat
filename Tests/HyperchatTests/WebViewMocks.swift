import Foundation
import WebKit
import XCTest
@testable import Hyperchat

// MARK: - WebView Protocol for Testing

protocol WebViewProtocol: AnyObject {
    var url: URL? { get }
    var isLoading: Bool { get }
    var title: String? { get }
    
    func load(_ request: URLRequest) -> WKNavigation?
    func evaluateJavaScript(_ javaScriptString: String) async throws -> Any?
    func stopLoading()
    func reload() -> WKNavigation?
    func goBack() -> WKNavigation?
    func goForward() -> WKNavigation?
}

// Make WKWebView conform to our protocol
extension WKWebView: WebViewProtocol { }

// MARK: - Mock WebView for Testing

class MockWebView: WebViewProtocol {
    var url: URL?
    var isLoading: Bool = false
    var title: String?
    
    var loadedRequests: [URLRequest] = []
    var evaluatedScripts: [String] = []
    var stopLoadingCallCount = 0
    var reloadCallCount = 0
    var goBackCallCount = 0
    var goForwardCallCount = 0
    
    // For simulating JavaScript results
    var javaScriptResults: [String: Any] = [:]
    var shouldThrowJavaScriptError = false
    
    func load(_ request: URLRequest) -> WKNavigation? {
        loadedRequests.append(request)
        url = request.url
        isLoading = true
        
        // Simulate loading completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isLoading = false
        }
        
        return nil // WKNavigation is not mockable
    }
    
    func evaluateJavaScript(_ javaScriptString: String) async throws -> Any? {
        evaluatedScripts.append(javaScriptString)
        
        if shouldThrowJavaScriptError {
            throw NSError(domain: "MockWebView", code: 1, userInfo: [NSLocalizedDescriptionKey: "JavaScript evaluation failed"])
        }
        
        // Return predefined result if available
        if let result = javaScriptResults[javaScriptString] {
            return result
        }
        
        return ""
    }
    
    func stopLoading() {
        stopLoadingCallCount += 1
        isLoading = false
    }
    
    func reload() -> WKNavigation? {
        reloadCallCount += 1
        if let currentURL = url {
            return load(URLRequest(url: currentURL))
        }
        return nil
    }
    
    func goBack() -> WKNavigation? {
        goBackCallCount += 1
        return nil
    }
    
    func goForward() -> WKNavigation? {
        goForwardCallCount += 1
        return nil
    }
}

// MARK: - Mock Navigation Delegate

class MockNavigationDelegate: NSObject, WKNavigationDelegate {
    var didStartNavigationCount = 0
    var didFinishNavigationCount = 0
    var didFailNavigationCount = 0
    var lastError: Error?
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        didStartNavigationCount += 1
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        didFinishNavigationCount += 1
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        didFailNavigationCount += 1
        lastError = error
    }
}

// MARK: - Mock Process Pool

class MockProcessPool {
    static let shared = WKProcessPool()
}

// MARK: - Test Helpers

extension XCTestCase {
    func createMockWebView(url: URL? = nil) -> MockWebView {
        let mockWebView = MockWebView()
        mockWebView.url = url
        return mockWebView
    }
    
    func createTestService(id: String = "test", 
                          name: String = "Test Service",
                          enabled: Bool = true) -> AIService {
        return AIService(
            id: id,
            name: name,
            iconName: "\(id)-icon",
            activationMethod: .urlParameter(baseURL: "https://\(id).com", parameter: "q"),
            enabled: enabled,
            order: 0
        )
    }
}