import XCTest
@testable import Hyperchat

class AIServiceTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Default Services Tests
    
    func testDefaultServicesCount() {
        let services = defaultServices
        XCTAssertEqual(services.count, 4, "Should have 4 default services")
    }
    
    func testChatGPTService() {
        let chatgpt = defaultServices.first { $0.id == "chatgpt" }
        XCTAssertNotNil(chatgpt)
        
        XCTAssertEqual(chatgpt?.id, "chatgpt")
        XCTAssertEqual(chatgpt?.name, "ChatGPT")
        XCTAssertEqual(chatgpt?.iconName, "chatgpt-icon")
        XCTAssertTrue(chatgpt?.enabled ?? false)
        XCTAssertEqual(chatgpt?.order, 1)
    }
    
    func testClaudeService() {
        let claude = defaultServices.first { $0.id == "claude" }
        XCTAssertNotNil(claude)
        
        XCTAssertEqual(claude?.id, "claude")
        XCTAssertEqual(claude?.name, "Claude")
        XCTAssertEqual(claude?.iconName, "claude-icon")
        XCTAssertFalse(claude?.enabled ?? true) // Claude is disabled by default
        XCTAssertEqual(claude?.order, 4)
    }
    
    func testPerplexityService() {
        let perplexity = defaultServices.first { $0.id == "perplexity" }
        XCTAssertNotNil(perplexity)
        
        XCTAssertEqual(perplexity?.id, "perplexity")
        XCTAssertEqual(perplexity?.name, "Perplexity")
        XCTAssertEqual(perplexity?.iconName, "perplexity-icon")
        XCTAssertTrue(perplexity?.enabled ?? false)
        XCTAssertEqual(perplexity?.order, 2)
    }
    
    func testGoogleService() {
        let google = defaultServices.first { $0.id == "google" }
        XCTAssertNotNil(google)
        
        XCTAssertEqual(google?.id, "google")
        XCTAssertEqual(google?.name, "Google")
        XCTAssertEqual(google?.iconName, "google-icon")
        XCTAssertTrue(google?.enabled ?? false)
        XCTAssertEqual(google?.order, 3)
    }
    
    // MARK: - Service Activation Method Tests
    
    func testServiceActivationMethods() {
        for service in defaultServices {
            switch service.id {
            case "chatgpt", "perplexity", "google":
                if case .urlParameter = service.activationMethod {
                    // Correct activation method
                } else {
                    XCTFail("\(service.name) should use URL parameter activation")
                }
            case "claude":
                if case .clipboardPaste = service.activationMethod {
                    // Correct activation method
                } else {
                    XCTFail("Claude should use clipboard paste activation")
                }
            default:
                XCTFail("Unknown service: \(service.id)")
            }
        }
    }
    
    // MARK: - Service Order Tests
    
    func testServiceOrder() {
        let sortedServices = defaultServices.sorted { $0.order < $1.order }
        
        XCTAssertEqual(sortedServices[0].id, "chatgpt") // order: 1
        XCTAssertEqual(sortedServices[1].id, "perplexity") // order: 2
        XCTAssertEqual(sortedServices[2].id, "google") // order: 3
        XCTAssertEqual(sortedServices[3].id, "claude") // order: 4
    }
    
    // MARK: - Service Enabled State Tests
    
    func testServicesEnabledState() {
        // Claude is disabled, others are enabled
        for service in defaultServices {
            if service.id == "claude" {
                XCTAssertFalse(service.enabled, "Claude should be disabled by default")
            } else {
                XCTAssertTrue(service.enabled, "\(service.name) should be enabled by default")
            }
        }
    }
    
    // MARK: - Icon Name Tests
    
    func testServiceIconNames() {
        let expectedIcons = [
            "chatgpt": "chatgpt-icon",
            "claude": "claude-icon",
            "perplexity": "perplexity-icon",
            "google": "google-icon"
        ]
        
        for service in defaultServices {
            XCTAssertEqual(service.iconName, expectedIcons[service.id])
        }
    }
}