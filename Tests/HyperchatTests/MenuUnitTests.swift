import XCTest
@testable import Hyperchat

class MenuUnitTests: XCTestCase {
    
    var mainMenu: NSMenu!
    
    override func setUp() {
        super.setUp()
        // Create a fresh menu for each test
        mainMenu = MenuBuilder.createMainMenu()
    }
    
    override func tearDown() {
        mainMenu = nil
        super.tearDown()
    }
    
    // MARK: - Basic Structure Tests
    
    func testMainMenuIsNotNil() {
        XCTAssertNotNil(mainMenu, "Main menu should not be nil")
    }
    
    func testMainMenuHasCorrectNumberOfTopLevelItems() {
        // Should have: Application, Edit, View, Window, Help
        XCTAssertEqual(mainMenu.items.count, 5, "Main menu should have 5 top-level items")
    }
    
    func testTopLevelMenuTitles() {
        let expectedTitles = ["", "Edit", "View", "Window", "Help"] // First item is app menu with no title
        
        for (index, expectedTitle) in expectedTitles.enumerated() {
            XCTAssertEqual(mainMenu.items[index].title, expectedTitle, 
                          "Menu item at index \(index) should have title '\(expectedTitle)'")
        }
    }
    
    // MARK: - Application Menu Tests
    
    func testApplicationMenuStructure() {
        let appMenuItem = mainMenu.items[0]
        XCTAssertNotNil(appMenuItem.submenu, "Application menu item should have a submenu")
        
        let appMenu = appMenuItem.submenu!
        
        // Expected items in order (including separators)
        let expectedItems = [
            ("About Hyperchat", false),
            ("", true), // separator
            ("Check for Updates...", false),
            ("", true), // separator
            ("Settings...", false),
            ("", true), // separator
            ("Services", false),
            ("", true), // separator
            ("Hide Hyperchat", false),
            ("Hide Others", false),
            ("Show All", false),
            ("", true), // separator
            ("Quit Hyperchat", false)
        ]
        
        XCTAssertEqual(appMenu.items.count, expectedItems.count, 
                      "Application menu should have \(expectedItems.count) items")
        
        for (index, (title, isSeparator)) in expectedItems.enumerated() {
            let item = appMenu.items[index]
            if isSeparator {
                XCTAssertTrue(item.isSeparatorItem, "Item at index \(index) should be a separator")
            } else {
                XCTAssertEqual(item.title, title, "Item at index \(index) should have title '\(title)'")
            }
        }
    }
    
    func testCheckForUpdatesMenuItem() {
        let appMenu = mainMenu.items[0].submenu!
        let updateItem = appMenu.items.first { $0.title == "Check for Updates..." }
        
        XCTAssertNotNil(updateItem, "Check for Updates menu item should exist")
        XCTAssertEqual(updateItem?.action, #selector(AppDelegate.checkForUpdates(_:)), 
                      "Check for Updates should have correct action")
        XCTAssertNil(updateItem?.target, "Check for Updates should have nil target (uses responder chain)")
    }
    
    func testSettingsMenuItem() {
        let appMenu = mainMenu.items[0].submenu!
        let settingsItem = appMenu.items.first { $0.title == "Settings..." }
        
        XCTAssertNotNil(settingsItem, "Settings menu item should exist")
        XCTAssertEqual(settingsItem?.action, #selector(AppDelegate.showSettings(_:)), 
                      "Settings should have correct action")
        XCTAssertEqual(settingsItem?.keyEquivalent, ",", "Settings should have comma key equivalent")
        XCTAssertNil(settingsItem?.target, "Settings should have nil target (uses responder chain)")
    }
    
    func testServicesSubmenu() {
        let appMenu = mainMenu.items[0].submenu!
        let servicesItem = appMenu.items.first { $0.title == "Services" }
        
        XCTAssertNotNil(servicesItem, "Services menu item should exist")
        XCTAssertNotNil(servicesItem?.submenu, "Services should have a submenu")
        XCTAssertEqual(NSApp.servicesMenu, servicesItem?.submenu, 
                      "Services submenu should be set as NSApp.servicesMenu")
    }
    
    func testQuitMenuItem() {
        let appMenu = mainMenu.items[0].submenu!
        let quitItem = appMenu.items.first { $0.title == "Quit Hyperchat" }
        
        XCTAssertNotNil(quitItem, "Quit menu item should exist")
        XCTAssertEqual(quitItem?.action, #selector(NSApplication.terminate(_:)), 
                      "Quit should have terminate action")
        XCTAssertEqual(quitItem?.keyEquivalent, "q", "Quit should have 'q' key equivalent")
    }
    
    // MARK: - Edit Menu Tests
    
    func testEditMenuStructure() {
        let editMenuItem = mainMenu.items[1]
        XCTAssertEqual(editMenuItem.title, "Edit", "Second menu should be Edit")
        XCTAssertNotNil(editMenuItem.submenu, "Edit menu should have submenu")
        
        let editMenu = editMenuItem.submenu!
        
        let expectedItems = [
            ("Undo", "z"),
            ("Redo", "z"), // with shift modifier
            ("", ""), // separator
            ("Cut", "x"),
            ("Copy", "c"),
            ("Paste", "v"),
            ("Delete", ""),
            ("Select All", "a")
        ]
        
        XCTAssertEqual(editMenu.items.count, expectedItems.count, 
                      "Edit menu should have \(expectedItems.count) items")
        
        // Test Undo
        let undoItem = editMenu.items[0]
        XCTAssertEqual(undoItem.title, "Undo")
        XCTAssertEqual(undoItem.keyEquivalent, "z")
        
        // Test Redo (with shift modifier)
        let redoItem = editMenu.items[1]
        XCTAssertEqual(redoItem.title, "Redo")
        XCTAssertEqual(redoItem.keyEquivalent, "z")
        XCTAssertTrue(redoItem.keyEquivalentModifierMask.contains(.shift), 
                     "Redo should have shift modifier")
    }
    
    // MARK: - View Menu Tests
    
    func testViewMenuStructure() {
        let viewMenuItem = mainMenu.items[2]
        XCTAssertEqual(viewMenuItem.title, "View", "Third menu should be View")
        XCTAssertNotNil(viewMenuItem.submenu, "View menu should have submenu")
        
        let viewMenu = viewMenuItem.submenu!
        
        // Should have at least Enter Full Screen
        let fullScreenItem = viewMenu.items.first { $0.title == "Enter Full Screen" }
        XCTAssertNotNil(fullScreenItem, "Enter Full Screen menu item should exist")
        XCTAssertEqual(fullScreenItem?.keyEquivalent, "f", 
                      "Enter Full Screen should have 'f' key equivalent")
        XCTAssertTrue(fullScreenItem?.keyEquivalentModifierMask.contains(.control) ?? false,
                     "Enter Full Screen should have control modifier")
    }
    
    // MARK: - Window Menu Tests
    
    func testWindowMenuStructure() {
        let windowMenuItem = mainMenu.items[3]
        XCTAssertEqual(windowMenuItem.title, "Window", "Fourth menu should be Window")
        XCTAssertNotNil(windowMenuItem.submenu, "Window menu should have submenu")
        
        let windowMenu = windowMenuItem.submenu!
        XCTAssertEqual(NSApp.windowsMenu, windowMenu, 
                      "Window menu should be set as NSApp.windowsMenu")
        
        // Check for standard window menu items
        let minimizeItem = windowMenu.items.first { $0.title == "Minimize" }
        XCTAssertNotNil(minimizeItem, "Minimize menu item should exist")
        XCTAssertEqual(minimizeItem?.keyEquivalent, "m", "Minimize should have 'm' key equivalent")
        
        let zoomItem = windowMenu.items.first { $0.title == "Zoom" }
        XCTAssertNotNil(zoomItem, "Zoom menu item should exist")
    }
    
    // MARK: - Help Menu Tests
    
    func testHelpMenuStructure() {
        let helpMenuItem = mainMenu.items[4]
        XCTAssertEqual(helpMenuItem.title, "Help", "Fifth menu should be Help")
        XCTAssertNotNil(helpMenuItem.submenu, "Help menu should have submenu")
        
        let helpMenu = helpMenuItem.submenu!
        XCTAssertEqual(NSApp.helpMenu, helpMenu, 
                      "Help menu should be set as NSApp.helpMenu")
        
        let helpItem = helpMenu.items.first { $0.title == "Hyperchat Help" }
        XCTAssertNotNil(helpItem, "Hyperchat Help menu item should exist")
        XCTAssertEqual(helpItem?.keyEquivalent, "?", "Help should have '?' key equivalent")
    }
    
    // MARK: - Integration Tests
    
    func testMenuCanBeSetOnApplication() {
        // This test would normally run in an app context
        // Here we just verify the menu is properly structured for NSApp
        XCTAssertNotNil(mainMenu, "Menu should be valid for setting on NSApp")
        
        // Verify critical app-level menus are set
        let windowMenu = mainMenu.items[3].submenu
        let helpMenu = mainMenu.items[4].submenu
        
        XCTAssertNotNil(windowMenu, "Window menu should exist")
        XCTAssertNotNil(helpMenu, "Help menu should exist")
    }
}