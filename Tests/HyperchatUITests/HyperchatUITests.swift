import XCTest

class HyperchatUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        
        // Launch the application
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    // MARK: - Basic Launch Tests
    
    func testAppLaunches() {
        // Verify the app launches successfully
        XCTAssertTrue(app.exists)
        
        // The app should show a window on startup
        XCTAssertGreaterThan(app.windows.count, 0, "App should show at least one window on startup")
        
        // Verify menu bar is accessible
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.exists, "Menu bar should be accessible")
        
        // Verify Hyperchat menu exists
        let appMenu = menuBar.menuBarItems["Hyperchat"]
        XCTAssertTrue(appMenu.exists, "Hyperchat menu should exist in menu bar")
    }
    
    func testFloatingButtonExists() {
        // Look for the floating button
        let floatingButton = app.buttons["FloatingButton"]
        
        // Wait for the floating button to appear
        let exists = floatingButton.waitForExistence(timeout: 5)
        XCTAssertTrue(exists, "Floating button should be visible")
    }
    
    // MARK: - Floating Button Interaction Tests
    
    func testFloatingButtonOpensMainWindow() {
        // Find and click the floating button
        let floatingButton = app.buttons["FloatingButton"]
        
        if floatingButton.waitForExistence(timeout: 5) {
            floatingButton.click()
            
            // Verify main window appears
            let mainWindow = app.windows["MainWindow"]
            XCTAssertTrue(mainWindow.waitForExistence(timeout: 3), "Main window should appear after clicking floating button")
        } else {
            XCTFail("Floating button not found")
        }
    }
    
    // MARK: - Service Tab Tests
    
    func testServiceTabsExist() {
        // Ensure main window is visible
        ensureMainWindowIsVisible()
        
        // Check for service tabs
        let expectedServices = ["ChatGPT", "Claude", "Perplexity"]
        
        for serviceName in expectedServices {
            let serviceTab = app.buttons[serviceName]
            XCTAssertTrue(serviceTab.exists, "\(serviceName) tab should exist")
        }
    }
    
    func testServiceTabSelection() {
        ensureMainWindowIsVisible()
        
        // Try clicking different service tabs
        let chatGPTTab = app.buttons["ChatGPT"]
        let claudeTab = app.buttons["Claude"]
        
        if chatGPTTab.exists {
            chatGPTTab.click()
            // Could verify that ChatGPT WebView is shown
        }
        
        if claudeTab.exists {
            claudeTab.click()
            // Could verify that Claude WebView is shown
        }
    }
    
    // MARK: - Prompt Input Tests
    
    func testPromptInputField() {
        ensureMainWindowIsVisible()
        
        // Look for the prompt input field
        let promptField = app.textFields.firstMatch
        
        if promptField.exists {
            // Test typing in the prompt field
            promptField.click()
            promptField.typeText("Test prompt from UI test")
            
            // Verify the text was entered
            XCTAssertEqual(promptField.value as? String, "Test prompt from UI test")
        }
    }
    
    func testPromptSubmission() {
        ensureMainWindowIsVisible()
        
        let promptField = app.textFields.firstMatch
        
        if promptField.exists {
            promptField.click()
            promptField.typeText("Hello from UI test")
            
            // Press Enter to submit
            promptField.typeText("\r")
            
            // Could verify that the prompt was submitted to services
            // This would require checking WebView content or network activity
        }
    }
    
    // MARK: - Keyboard Shortcuts Tests
    
    func testEscapeKeyToggle() {
        ensureMainWindowIsVisible()
        
        // Press ESC to toggle overlay mode
        app.typeKey(.escape, modifierFlags: [])
        
        // The window behavior should change, but exact verification depends on implementation
        // Could check window frame or style changes
    }
    
    func testServiceKeyboardShortcuts() {
        ensureMainWindowIsVisible()
        
        // Test Cmd+1 for ChatGPT
        app.typeKey("1", modifierFlags: .command)
        // Could verify ChatGPT is selected
        
        // Test Cmd+2 for Claude
        app.typeKey("2", modifierFlags: .command)
        // Could verify Claude is selected
        
        // Test Cmd+3 for Perplexity
        app.typeKey("3", modifierFlags: .command)
        // Could verify Perplexity is selected
    }
    
    // MARK: - Menu Tests
    
    func testQuickMenuCheck() {
        // Quick verification that menus are properly connected
        let menuBar = app.menuBars.firstMatch
        
        // Test Settings menu item via keyboard shortcut
        app.typeKey(",", modifierFlags: .command)
        
        // Verify settings window appears
        let settingsWindow = app.windows["Hyperchat Settings"]
        if settingsWindow.waitForExistence(timeout: 3) {
            // Settings opened successfully - close it
            settingsWindow.buttons[XCUIIdentifierCloseWindow].click()
        }
        
        // Test application menu exists
        let appMenu = menuBar.menuBarItems["Hyperchat"]
        XCTAssertTrue(appMenu.exists, "Application menu should exist")
    }
    
    // MARK: - Window Management Tests
    
    func testCloseServiceTab() {
        ensureMainWindowIsVisible()
        
        // Look for close buttons on service tabs
        let closeButtons = app.buttons.matching(identifier: "CloseButton")
        
        if closeButtons.count > 0 {
            let initialServiceCount = getVisibleServiceCount()
            
            // Click the first close button
            closeButtons.firstMatch.click()
            
            // Verify service count decreased
            let newServiceCount = getVisibleServiceCount()
            XCTAssertEqual(newServiceCount, initialServiceCount - 1, "Service count should decrease after closing")
        }
    }
    
    func testMultipleWindows() {
        ensureMainWindowIsVisible()
        
        let initialWindowCount = app.windows.count
        
        // Try to open another window (implementation specific)
        // This might involve clicking floating button again or menu item
        let floatingButton = app.buttons["FloatingButton"]
        if floatingButton.exists {
            floatingButton.click()
            
            // Check if new window was created
            let newWindowCount = app.windows.count
            XCTAssertGreaterThan(newWindowCount, initialWindowCount, "Should be able to create multiple windows")
        }
    }
    
    // MARK: - Helper Methods
    
    private func ensureMainWindowIsVisible() {
        let mainWindow = app.windows["MainWindow"]
        
        if !mainWindow.exists {
            // Try to open it via floating button
            let floatingButton = app.buttons["FloatingButton"]
            if floatingButton.waitForExistence(timeout: 5) {
                floatingButton.click()
                _ = mainWindow.waitForExistence(timeout: 3)
            }
        }
    }
    
    private func getVisibleServiceCount() -> Int {
        // Count visible service tabs
        let services = ["ChatGPT", "Claude", "Perplexity", "Google"]
        var count = 0
        
        for service in services {
            if app.buttons[service].exists {
                count += 1
            }
        }
        
        return count
    }
}

// MARK: - UI Test Launch Arguments

extension HyperchatUITests {
    
    func testLaunchWithDisabledServices() {
        app.launchArguments = ["--disable-service", "google"]
        app.launch()
        
        ensureMainWindowIsVisible()
        
        // Verify Google service is not shown
        let googleTab = app.buttons["Google"]
        XCTAssertFalse(googleTab.exists, "Google service should not be visible when disabled")
    }
    
    func testLaunchInDebugMode() {
        app.launchArguments = ["--debug"]
        app.launch()
        
        // Could verify debug features are enabled
        // Such as additional logging or debug UI elements
    }
}