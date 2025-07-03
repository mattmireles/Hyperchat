import XCTest
import Hyperchat

class ServiceConfigurationTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - ServiceURLConfig Tests
    
    func testChatGPTConfiguration() {
        let config = ServiceConfigurations.chatGPT
        
        XCTAssertEqual(config.homeURL, "https://chatgpt.com")
        XCTAssertEqual(config.baseURL, "https://chatgpt.com")
        XCTAssertEqual(config.queryParam, "q")
        XCTAssertNotNil(config.userAgent)
        XCTAssertTrue(config.userAgent!.contains("Safari"))
    }
    
    func testClaudeConfiguration() {
        let config = ServiceConfigurations.claude
        
        XCTAssertEqual(config.homeURL, "https://claude.ai")
        XCTAssertEqual(config.baseURL, "https://claude.ai")
        XCTAssertEqual(config.queryParam, "q")
        XCTAssertNotNil(config.userAgent)
    }
    
    func testPerplexityConfiguration() {
        let config = ServiceConfigurations.perplexity
        
        XCTAssertEqual(config.homeURL, "https://www.perplexity.ai")
        XCTAssertEqual(config.baseURL, "https://www.perplexity.ai/search/new")
        XCTAssertEqual(config.queryParam, "q")
        XCTAssertNotNil(config.userAgent)
    }
    
    func testGoogleConfiguration() {
        let config = ServiceConfigurations.google
        
        XCTAssertEqual(config.homeURL, "https://www.google.com")
        XCTAssertEqual(config.baseURL, "https://www.google.com/search")
        XCTAssertEqual(config.queryParam, "q")
        XCTAssertEqual(config.additionalParams["hl"], "en")
        XCTAssertEqual(config.additionalParams["safe"], "off")
        XCTAssertEqual(config.userAgent, ServiceConfigurations.iPadUserAgent)
    }
    
    // MARK: - URL Generation Tests
    
    func testChatGPTURLGeneration() {
        let config = ServiceConfigurations.chatGPT
        let prompt = "Hello world"
        
        let expectedURL = "https://chatgpt.com?q=Hello%20world"
        let actualURL = config.buildURL(with: prompt)
        
        XCTAssertEqual(actualURL, expectedURL)
    }
    
    func testPerplexityURLGeneration() {
        let config = ServiceConfigurations.perplexity
        let prompt = "What is Swift?"
        
        let expectedURL = "https://www.perplexity.ai/search/new?q=What%20is%20Swift?"
        let actualURL = config.buildURL(with: prompt)
        
        XCTAssertEqual(actualURL, expectedURL)
    }
    
    func testGoogleURLGeneration() {
        let config = ServiceConfigurations.google
        let prompt = "macOS development"
        
        let actualURL = config.buildURL(with: prompt)
        
        // Check base URL and query parameter
        XCTAssertTrue(actualURL.starts(with: "https://www.google.com/search?q=macOS%20development"))
        // Check additional parameters
        XCTAssertTrue(actualURL.contains("&hl=en"))
        XCTAssertTrue(actualURL.contains("&safe=off"))
    }
    
    func testClaudeURLGeneration() {
        let config = ServiceConfigurations.claude
        let prompt = "Test prompt"
        
        // Claude supports URL parameters according to the config
        let actualURL = config.buildURL(with: prompt)
        
        XCTAssertEqual(actualURL, "https://claude.ai?q=Test%20prompt")
    }
    
    // MARK: - Special Character Encoding Tests
    
    func testURLEncodingWithSpecialCharacters() {
        let config = ServiceConfigurations.chatGPT
        let prompt = "Hello & goodbye + test@email.com"
        
        let url = config.buildURL(with: prompt)
        
        // Check that special characters are properly encoded
        // Note: urlQueryAllowed doesn't encode + and @ by default
        XCTAssertTrue(url.contains("Hello%20&%20goodbye%20+%20test@email.com"))
    }
    
    func testURLEncodingWithEmoji() {
        let config = ServiceConfigurations.chatGPT
        let prompt = "Hello 👋 World 🌍"
        
        let url = config.buildURL(with: prompt)
        
        // Verify emoji are properly encoded
        XCTAssertTrue(url.contains("Hello%20%F0%9F%91%8B%20World%20%F0%9F%8C%8D"))
    }
    
    func testEmptyPromptHandling() {
        let config = ServiceConfigurations.chatGPT
        let prompt = ""
        
        let url = config.buildURL(with: prompt)
        
        // Should still return valid URL even with empty prompt
        XCTAssertEqual(url, "https://chatgpt.com?q=")
    }
    
    // MARK: - Config Lookup Tests
    
    func testConfigLookupByServiceId() {
        XCTAssertNotNil(ServiceConfigurations.config(for: "chatgpt"))
        XCTAssertNotNil(ServiceConfigurations.config(for: "claude"))
        XCTAssertNotNil(ServiceConfigurations.config(for: "perplexity"))
        XCTAssertNotNil(ServiceConfigurations.config(for: "google"))
        XCTAssertNil(ServiceConfigurations.config(for: "invalid"))
    }
    
    func testHomeURLDefaultsToBaseURL() {
        // Test that homeURL defaults to baseURL when not specified
        let config = ServiceURLConfig(baseURL: "https://example.com", queryParam: "q")
        XCTAssertEqual(config.homeURL, "https://example.com")
        XCTAssertEqual(config.baseURL, "https://example.com")
    }
    
    // MARK: - User Agent Tests
    
    func testDesktopSafariUserAgent() {
        let userAgent = ServiceConfigurations.desktopSafariUserAgent
        XCTAssertTrue(userAgent.contains("Safari"))
        XCTAssertTrue(userAgent.contains("Mozilla"))
        XCTAssertTrue(userAgent.contains("AppleWebKit"))
    }
    
    func testIPadUserAgent() {
        let userAgent = ServiceConfigurations.iPadUserAgent
        XCTAssertTrue(userAgent.contains("iPad"))
        XCTAssertTrue(userAgent.contains("Safari"))
        XCTAssertTrue(userAgent.contains("Mobile"))
    }
}