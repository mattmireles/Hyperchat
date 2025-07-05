import XCTest

class MenuUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    // MARK: - Application Menu Tests
    
    func testApplicationMenuExists() {
        // The app menu should be the first menu after the Apple menu
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.exists, "Menu bar should exist")
        
        // Check for Hyperchat menu
        let appMenu = menuBar.menuBarItems["Hyperchat"]
        XCTAssertTrue(appMenu.exists, "Hyperchat application menu should exist")
    }
    
    func testAboutMenuItemExists() {
        let menuBar = app.menuBars.firstMatch
        let appMenu = menuBar.menuBarItems["Hyperchat"]
        
        appMenu.click()
        
        let aboutItem = appMenu.menuItems["About Hyperchat"]
        XCTAssertTrue(aboutItem.exists, "About Hyperchat menu item should exist")
        
        // Click outside to close menu
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }
    
    func testCheckForUpdatesMenuItemExists() {
        let menuBar = app.menuBars.firstMatch
        let appMenu = menuBar.menuBarItems["Hyperchat"]
        
        appMenu.click()
        
        let updateItem = appMenu.menuItems["Check for Updates..."]
        XCTAssertTrue(updateItem.exists, "Check for Updates menu item should exist")
        
        // Test clicking it
        updateItem.click()
        
        // Wait a moment for any update dialog that might appear
        sleep(2)
        
        // If an update dialog appears, dismiss it
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.click()
        }
    }
    
    func testSettingsMenuItemExists() {
        let menuBar = app.menuBars.firstMatch
        let appMenu = menuBar.menuBarItems["Hyperchat"]
        
        appMenu.click()
        
        let settingsItem = appMenu.menuItems["Settings..."]
        XCTAssertTrue(settingsItem.exists, "Settings menu item should exist")
        
        // Test clicking it
        settingsItem.click()
        
        // Verify settings window appears
        let settingsWindow = app.windows["Hyperchat Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3), "Settings window should appear")
        
        // Close the settings window
        if settingsWindow.exists {
            settingsWindow.buttons[XCUIIdentifierCloseWindow].click()
        }
    }
    
    func testSettingsKeyboardShortcut() {
        // Test Cmd+, shortcut
        app.typeKey(",", modifierFlags: .command)
        
        // Verify settings window appears
        let settingsWindow = app.windows["Hyperchat Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3), "Settings window should appear with Cmd+, shortcut")
        
        // Close the settings window
        if settingsWindow.exists {
            settingsWindow.buttons[XCUIIdentifierCloseWindow].click()
        }
    }
    
    func testQuitMenuItem() {
        let menuBar = app.menuBars.firstMatch
        let appMenu = menuBar.menuBarItems["Hyperchat"]
        
        appMenu.click()
        
        let quitItem = appMenu.menuItems["Quit Hyperchat"]
        XCTAssertTrue(quitItem.exists, "Quit menu item should exist")
        XCTAssertEqual(quitItem.value as? String, "⌘Q", "Quit should have Cmd+Q shortcut")
        
        // Don't actually click quit or the test will terminate
        // Click outside to close menu
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }
    
    // MARK: - Edit Menu Tests
    
    func testEditMenuExists() {
        let menuBar = app.menuBars.firstMatch
        let editMenu = menuBar.menuBarItems["Edit"]
        XCTAssertTrue(editMenu.exists, "Edit menu should exist")
        
        editMenu.click()
        
        // Check for standard edit menu items
        let expectedItems = ["Undo", "Redo", "Cut", "Copy", "Paste", "Delete", "Select All"]
        
        for itemTitle in expectedItems {
            let menuItem = editMenu.menuItems[itemTitle]
            XCTAssertTrue(menuItem.exists, "\(itemTitle) menu item should exist in Edit menu")
        }
        
        // Click outside to close menu
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }
    
    // MARK: - View Menu Tests
    
    func testViewMenuExists() {
        let menuBar = app.menuBars.firstMatch
        let viewMenu = menuBar.menuBarItems["View"]
        XCTAssertTrue(viewMenu.exists, "View menu should exist")
        
        viewMenu.click()
        
        let fullScreenItem = viewMenu.menuItems["Enter Full Screen"]
        XCTAssertTrue(fullScreenItem.exists, "Enter Full Screen menu item should exist")
        
        // Click outside to close menu
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }
    
    // MARK: - Window Menu Tests
    
    func testWindowMenuExists() {
        let menuBar = app.menuBars.firstMatch
        let windowMenu = menuBar.menuBarItems["Window"]
        XCTAssertTrue(windowMenu.exists, "Window menu should exist")
        
        windowMenu.click()
        
        // Check for standard window menu items
        let expectedItems = ["Minimize", "Zoom", "Bring All to Front"]
        
        for itemTitle in expectedItems {
            let menuItem = windowMenu.menuItems[itemTitle]
            XCTAssertTrue(menuItem.exists, "\(itemTitle) menu item should exist in Window menu")
        }
        
        // Click outside to close menu
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }
    
    // MARK: - Help Menu Tests
    
    func testHelpMenuExists() {
        let menuBar = app.menuBars.firstMatch
        let helpMenu = menuBar.menuBarItems["Help"]
        XCTAssertTrue(helpMenu.exists, "Help menu should exist")
        
        helpMenu.click()
        
        let helpItem = helpMenu.menuItems["Hyperchat Help"]
        XCTAssertTrue(helpItem.exists, "Hyperchat Help menu item should exist")
        
        // Click outside to close menu
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }
    
    // MARK: - Integration Tests
    
    func testMenuInteractionWithMainWindow() {
        // Ensure main window is visible
        ensureMainWindowIsVisible()
        
        // Open settings via menu
        let menuBar = app.menuBars.firstMatch
        let appMenu = menuBar.menuBarItems["Hyperchat"]
        appMenu.click()
        
        let settingsItem = appMenu.menuItems["Settings..."]
        settingsItem.click()
        
        // Verify settings window appears
        let settingsWindow = app.windows["Hyperchat Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3), "Settings window should appear")
        
        // Verify main window is still accessible
        let mainWindow = app.windows["MainWindow"]
        XCTAssertTrue(mainWindow.exists, "Main window should still exist when settings is open")
        
        // Close settings
        if settingsWindow.exists {
            settingsWindow.buttons[XCUIIdentifierCloseWindow].click()
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
}