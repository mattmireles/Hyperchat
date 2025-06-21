import Foundation

// MARK: - Service URL Configuration

struct ServiceURLConfig {
    let baseURL: String
    let queryParam: String
    let additionalParams: [String: String]
    let userAgent: String?
    
    init(baseURL: String, queryParam: String, additionalParams: [String: String] = [:], userAgent: String? = nil) {
        self.baseURL = baseURL
        self.queryParam = queryParam
        self.additionalParams = additionalParams
        self.userAgent = userAgent
    }
    
    func buildURL(with query: String) -> String {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        var urlString = "\(baseURL)?\(queryParam)=\(encodedQuery)"
        
        // Add any additional parameters
        for (key, value) in additionalParams {
            urlString += "&\(key)=\(value)"
        }
        
        return urlString
    }
}

// MARK: - Service Configurations

struct ServiceConfigurations {
    // User agents
    static let iPadUserAgent = "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    static let desktopSafariUserAgent: String = {
        // Generate dynamic Safari user agent
        let userAgent = UserAgentGenerator.generate()
        return userAgent.fullUserAgent
    }()
    
    static let chatGPT = ServiceURLConfig(
        baseURL: "https://chatgpt.com",
        queryParam: "q",
        userAgent: desktopSafariUserAgent
    )
    
    static let perplexity = ServiceURLConfig(
        baseURL: "https://www.perplexity.ai",
        queryParam: "q",
        userAgent: desktopSafariUserAgent
    )
    
    static let google = ServiceURLConfig(
        baseURL: "https://www.google.com/search",
        queryParam: "q",
        additionalParams: [
            "hl": "en",        // Language
            "safe": "off"      // Safe search
        ],
        userAgent: iPadUserAgent
    )
    
    static let claude = ServiceURLConfig(
        baseURL: "https://claude.ai",
        queryParam: "q",  // If Claude starts supporting URL params
        userAgent: desktopSafariUserAgent
    )
    
    // Easy way to get config by service ID
    static func config(for serviceId: String) -> ServiceURLConfig? {
        switch serviceId {
        case "chatgpt":
            return chatGPT
        case "perplexity":
            return perplexity
        case "google":
            return google
        case "claude":
            return claude
        default:
            return nil
        }
    }
} 