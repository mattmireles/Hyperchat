import Cocoa

/// Creates the application's menu bar structure.
///
/// Builds a complete menu bar with:
/// - Application menu (About, Updates, Settings, Quit)
/// - Edit menu (Cut, Copy, Paste, etc.)
/// - View menu (Reload, Developer tools)
/// - Window menu (Minimize, Zoom, etc.)
/// - Help menu
///
/// Menu items are connected to:
/// - Standard Cocoa selectors (cut:, copy:, paste:)
/// - AppDelegate methods (showSettings:, checkForUpdates:)
/// - First responder chain actions
class MenuBuilder {
    static func createMainMenu(appDelegate: AppDelegate?) -> NSMenu {
        print("🔧 [MENUBUILDER] >>> createMainMenu() called")
        let mainMenu = NSMenu()
        print("🔧 [MENUBUILDER] Created empty main menu")
        
        // Application menu
        let appMenuItem = NSMenuItem()
        appMenuItem.title = "Hyperchat"
        mainMenu.addItem(appMenuItem)
        
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        // About
        let aboutItem = NSMenuItem(title: "About Hyperchat", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(aboutItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Check for Updates
        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(AppDelegate.checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = nil
        appMenu.addItem(updateItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(AppDelegate.showSettings(_:)), keyEquivalent: ",")
        settingsItem.target = nil
        appMenu.addItem(settingsItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Services
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        appMenu.addItem(servicesItem)
        let servicesMenu = NSMenu()
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Hide
        let hideItem = NSMenuItem(title: "Hide Hyperchat", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(hideItem)
        
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        
        let showAllItem = NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(showAllItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Hyperchat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitItem)
        
        // AI Services menu (moved to be first after app menu)
        let aiServicesMenuItem = NSMenuItem()
        aiServicesMenuItem.title = "AI Services"
        mainMenu.addItem(aiServicesMenuItem)
        
        let aiServicesMenu = NSMenu(title: "AI Services")
        aiServicesMenuItem.submenu = aiServicesMenu
        appDelegate?.aiServicesMenu = aiServicesMenu
        
        // Add service menu items dynamically
        MenuBuilder.createAIServicesMenu(aiServicesMenu)
        
        // Edit menu
        let editMenuItem = NSMenuItem()
        editMenuItem.title = "Edit"
        mainMenu.addItem(editMenuItem)
        
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        
        // Edit menu items
        let undoItem = NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(undoItem)
        
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        
        editMenu.addItem(NSMenuItem.separator())
        
        let cutItem = NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(cutItem)
        
        let copyItem = NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(copyItem)
        
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(pasteItem)
        
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(deleteItem)
        
        let selectAllItem = NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(selectAllItem)
        
        // View menu
        let viewMenuItem = NSMenuItem()
        viewMenuItem.title = "View"
        mainMenu.addItem(viewMenuItem)
        
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        
        // Show Floating Button toggle
        let showFloatingButtonItem = NSMenuItem(title: "Show Floating Button", action: #selector(AppDelegate.toggleFloatingButton(_:)), keyEquivalent: "")
        showFloatingButtonItem.target = nil
        showFloatingButtonItem.state = SettingsManager.shared.isFloatingButtonEnabled ? .on : .off
        appDelegate?.showFloatingButtonMenuItem = showFloatingButtonItem
        viewMenu.addItem(showFloatingButtonItem)
        
        viewMenu.addItem(NSMenuItem.separator())
        
        let enterFullScreenItem = NSMenuItem(title: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        enterFullScreenItem.keyEquivalentModifierMask = [.command, .control]
        viewMenu.addItem(enterFullScreenItem)
        
        // Window menu
        let windowMenuItem = NSMenuItem()
        windowMenuItem.title = "Window"
        mainMenu.addItem(windowMenuItem)
        
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu
        
        let minimizeItem = NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(minimizeItem)
        
        let zoomItem = NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(zoomItem)
        
        windowMenu.addItem(NSMenuItem.separator())
        
        let bringAllToFrontItem = NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenu.addItem(bringAllToFrontItem)
        
        // Help menu
        let helpMenuItem = NSMenuItem()
        helpMenuItem.title = "Help"
        mainMenu.addItem(helpMenuItem)
        
        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu
        NSApp.helpMenu = helpMenu
        
        let helpItem = NSMenuItem(title: "Get Help", action: #selector(AppDelegate.getHelp(_:)), keyEquivalent: "?")
        helpItem.target = nil
        helpMenu.addItem(helpItem)
        
        print("🔧 [MENUBUILDER] Main menu creation complete")
        print("🔧 [MENUBUILDER] Final menu items: \(mainMenu.items.map { $0.title })")
        print("🔧 [MENUBUILDER] <<< createMainMenu() returning menu")
        
        return mainMenu
    }
    
    /// Creates the AI Services submenu with all available services.
    static func createAIServicesMenu(_ menu: NSMenu) {
        // Clear existing items
        menu.removeAllItems()
        
        // Get services from SettingsManager
        let services = SettingsManager.shared.getServices()
        let sortedServices = services.sorted { $0.order < $1.order }
        
        print("🔧 [MENUBUILDER] >>> createAIServicesMenu() called")
        print("🔧 [MENUBUILDER] Clearing existing items from AI Services menu")
        print("🔧 [MENUBUILDER] Creating menu with \(sortedServices.count) services:")
        for service in sortedServices {
            print("   \(service.name): \(service.enabled ? "✅ enabled" : "❌ disabled") → menu state: \(service.enabled ? ".on" : ".off")")
        }
        
        // Add menu item for each service
        for service in sortedServices {
            let menuItem = NSMenuItem(title: service.name, action: #selector(AppDelegate.toggleAIService(_:)), keyEquivalent: "")
            menuItem.target = nil
            menuItem.representedObject = service.id
            menuItem.state = service.enabled ? .on : .off
            menu.addItem(menuItem)
        }
        
        // Add separator and reorder option
        menu.addItem(NSMenuItem.separator())
        
        let reorderItem = NSMenuItem(title: "Reorder...", action: #selector(AppDelegate.openReorderSettings(_:)), keyEquivalent: "")
        reorderItem.target = nil
        reorderItem.indentationLevel = 0
        menu.addItem(reorderItem)
        
        print("🔧 [MENUBUILDER] AI Services menu creation completed")
        print("🔧 [MENUBUILDER] Final AI Services menu items: \(menu.items.map { $0.title })")
        print("🔧 [MENUBUILDER] <<< createAIServicesMenu() complete")
    }
}


