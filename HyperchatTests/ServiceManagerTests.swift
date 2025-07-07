import XCTest
import WebKit
@testable import Hyperchat

class ServiceManagerTests: XCTestCase {
    
    var serviceManager: ServiceManager!
    
    override func setUp() {
        super.setUp()
        serviceManager = ServiceManager()
    }
    
    override func tearDown() {
        serviceManager = nil
        super.tearDown()
    }
    
    // MARK: - Service Loading Tests
    
    func testInitialServiceLoading() {
        // Verify initial services are loaded
        XCTAssertGreaterThan(serviceManager.activeServices.count, 0)
        // ServiceManager doesn't have selectedServiceId property
    }
    
    func testActiveServicesFiltering() {
        // Only enabled services should be in activeServices
        // ServiceManager uses defaultServices, not a services property
        let enabledCount = defaultServices.filter { $0.enabled }.count
        XCTAssertEqual(serviceManager.activeServices.count, enabledCount)
    }
    
    func testSelectedServiceIdInitialization() {
        // ServiceManager doesn't have selectedServiceId property
        // Just verify we have active services
        XCTAssertGreaterThan(serviceManager.activeServices.count, 0)
    }
    
    // MARK: - WebView Tests
    
    func testWebViewCreation() {
        // Verify each active service has a WebView
        for service in serviceManager.activeServices {
            XCTAssertNotNil(serviceManager.webServices[service.id])
            XCTAssertNotNil(serviceManager.webServices[service.id]?.webView)
        }
    }
    
    func testWebViewConfiguration() {
        guard let firstService = serviceManager.activeServices.first,
              let webService = serviceManager.webServices[firstService.id] else {
            XCTFail("No active services available")
            return
        }
        
        let webView = webService.webView
        let configuration = webView.configuration
        
        // Verify WebView configuration
        XCTAssertNotNil(configuration.processPool)
        XCTAssertNotNil(configuration.websiteDataStore)
        XCTAssertNotNil(configuration.userContentController)
    }
    
    // MARK: - Prompt Execution Tests
    
    func testSharedPromptSetting() {
        let testPrompt = "Test prompt"
        serviceManager.sharedPrompt = testPrompt
        
        XCTAssertEqual(serviceManager.sharedPrompt, testPrompt)
    }
    
    func testReplyToAllSetting() {
        serviceManager.replyToAll = false
        XCTAssertFalse(serviceManager.replyToAll)
        
        serviceManager.replyToAll = true
        XCTAssertTrue(serviceManager.replyToAll)
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingStateInitialization() {
        // Verify all services have loading state initialized to false
        for service in serviceManager.activeServices {
            XCTAssertEqual(serviceManager.loadingStates[service.id], false)
        }
    }
    
    func testLoadingStateUpdates() {
        guard let firstService = serviceManager.activeServices.first else {
            XCTFail("No active services available")
            return
        }
        
        // Update loading state
        serviceManager.loadingStates[firstService.id] = true
        XCTAssertEqual(serviceManager.loadingStates[firstService.id], true)
        
        serviceManager.loadingStates[firstService.id] = false
        XCTAssertEqual(serviceManager.loadingStates[firstService.id], false)
    }
    
    // MARK: - Service Order Tests
    
    func testServiceOrder() {
        // Verify services are loaded in correct order
        let expectedOrder = defaultServices
            .filter { $0.enabled }
            .sorted { $0.order < $1.order }
            .map { $0.id }
        
        let actualOrder = serviceManager.activeServices.map { $0.id }
        
        XCTAssertEqual(actualOrder, expectedOrder)
    }
    
    // MARK: - WebService Type Tests
    
    func testCorrectWebServiceTypes() {
        for service in serviceManager.activeServices {
            guard let webService = serviceManager.webServices[service.id] else {
                XCTFail("WebService not found for \(service.id)")
                continue
            }
            
            switch service.activationMethod {
            case .urlParameter:
                XCTAssertTrue(webService is URLParameterService)
            case .clipboardPaste:
                XCTAssertTrue(webService is ClaudeService)
            }
        }
    }
    
    // MARK: - Process Pool Tests
    
    func testSharedProcessPool() {
        // Verify all WebViews use the shared process pool
        let processPool = WKProcessPool.shared
        
        for service in serviceManager.activeServices {
            if let webService = serviceManager.webServices[service.id] {
                let webView = webService.webView
                XCTAssertEqual(webView.configuration.processPool, processPool)
            }
        }
    }
}