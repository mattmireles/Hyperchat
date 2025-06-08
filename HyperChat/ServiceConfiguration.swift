import Foundation

// MARK: - Service URL Configuration

struct ServiceURLConfig {
    let baseURL: String
    let queryParam: String
    let additionalParams: [String: String]
    
    init(baseURL: String, queryParam: String, additionalParams: [String: String] = [:]) {
        self.baseURL = baseURL
        self.queryParam = queryParam
        self.additionalParams = additionalParams
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
    static let chatGPT = ServiceURLConfig(
        baseURL: "https://chatgpt.com",
        queryParam: "q",
        additionalParams: [
            "model": "gpt-4o"  // You can change this to gpt-3.5-turbo, gpt-4, etc.
        ]
    )
    
    static let perplexity = ServiceURLConfig(
        baseURL: "https://www.perplexity.ai",
        queryParam: "q"
    )
    
    static let google = ServiceURLConfig(
        baseURL: "https://www.google.com/search",
        queryParam: "q",
        additionalParams: [
            "hl": "en",        // Language
            "safe": "off"      // Safe search
        ]
    )
    
    static let claude = ServiceURLConfig(
        baseURL: "https://claude.ai",
        queryParam: "q"  // If Claude starts supporting URL params
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