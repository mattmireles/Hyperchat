import Foundation
import WebKit
import SwiftUI

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
        id: "chatgpt",
        name: "ChatGPT",
        iconName: "chatgpt-icon",
        activationMethod: .urlParameter(
            baseURL: "https://chat.openai.com",
            parameter: "q"
        ),
        enabled: true,
        order: 1
    ),
    AIService(
        id: "claude",
        name: "Claude",
        iconName: "claude-icon",
        activationMethod: .clipboardPaste(
            baseURL: "https://claude.ai"
        ),
        enabled: true,
        order: 2
    ),
    AIService(
        id: "perplexity",
        name: "Perplexity",
        iconName: "perplexity-icon",
        activationMethod: .urlParameter(
            baseURL: "https://www.perplexity.ai",
            parameter: "q"
        ),
        enabled: true,
        order: 3
    ),
    AIService(
        id: "google",
        name: "Google",
        iconName: "google-icon",
        activationMethod: .urlParameter(
            baseURL: "https://www.google.com/search",
            parameter: "q"
        ),
        enabled: true,
        order: 4
    )
]

// MARK: - WebService Protocol and Implementations

protocol WebService {
    func executePrompt(_ prompt: String)
    var webView: WKWebView { get }
    var service: AIService { get }
}

class URLParameterService: WebService {
    let webView: WKWebView
    let service: AIService
    
    init(webView: WKWebView, service: AIService) {
        self.webView = webView
        self.service = service
    }

    func executePrompt(_ prompt: String) {
        guard case .urlParameter(let baseURL, let parameter) = service.activationMethod else { return }
        
        let encodedPrompt = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)?\(parameter)=\(encodedPrompt)"
        
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
    }
}

class ClaudeService: WebService {
    let webView: WKWebView
    let service: AIService
    
    init(webView: WKWebView, service: AIService) {
        self.webView = webView
        self.service = service
    }

    func executePrompt(_ prompt: String) {
        guard case .clipboardPaste(let baseURL) = service.activationMethod else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(prompt, forType: .string)
        
        if let url = URL(string: baseURL) {
            webView.load(URLRequest(url: url))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.webView.evaluateJavaScript("""
                document.body.click();
                document.execCommand('paste');
                setTimeout(() => {
                    const enterEvent = new KeyboardEvent('keydown', { key: 'Enter', keyCode: 13, bubbles: true });
                    document.dispatchEvent(enterEvent);
                }, 200);
            """)
        }
    }
}

// MARK: - ServiceManager

class ServiceManager: ObservableObject {
    @Published var activeServices: [AIService] = []
    private var webServices: [String: WebService] = [:]
    
    init() {
        setupServices()
    }
    
    private func setupServices() {
        for service in defaultServices where service.enabled {
            let webView = createWebView()
            
            let webService: WebService
            switch service.activationMethod {
            case .urlParameter:
                webService = URLParameterService(webView: webView, service: service)
            case .clipboardPaste:
                webService = ClaudeService(webView: webView, service: service)
            }
            
            webServices[service.id] = webService
            activeServices.append(service)
        }
    }
    
    func executePrompt(_ prompt: String) {
        for service in activeServices {
            webServices[service.id]?.executePrompt(prompt)
        }
    }
    
    private func createWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = .shared
        return WKWebView(frame: .zero, configuration: configuration)
    }
}

extension WKProcessPool {
    static let shared = WKProcessPool()
} 