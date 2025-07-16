/// AppDelegate.swift - Application Lifecycle and Coordination
///
/// This file manages the application lifecycle and coordinates between major components.
/// It's the central hub that creates and connects all top-level controllers.
///
/// Key responsibilities:
/// - Application lifecycle management
/// - Component initialization and coordination
/// - Global hotkey and notification handling
/// - Menu bar creation and management
/// - Auto-update integration (Sparkle)
/// - Font registration
///
/// Related files:
/// - `FloatingButtonManager.swift`: Manages the floating button UI
/// - `OverlayController.swift`: Manages all application windows
/// - `PromptWindowController.swift`: Handles prompt input window
/// - `SettingsWindowController.swift`: Manages settings window
/// - `AutoInstaller.swift`: Handles first-launch installation
///
/// Startup sequence:
/// 1. Register custom fonts
/// 2. Create floating button
/// 3. Show initial window
/// 4. Start update checker
/// 5. Set up notification observers

import Cocoa
import SwiftUI
import Sparkle

// MARK: - Menu Builder

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
        let mainMenu = NSMenu()
        
        // Application menu
        let appMenuItem = NSMenuItem()
        appMenuItem.title = "Hyperchat"  // Add the app name as title
        mainMenu.addItem(appMenuItem)
        
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        // About
        let aboutItem = NSMenuItem(title: "About Hyperchat", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(aboutItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Check for Updates
        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(AppDelegate.checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = nil // Will find AppDelegate through responder chain
        appMenu.addItem(updateItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(AppDelegate.showSettings(_:)), keyEquivalent: ",")
        settingsItem.target = nil // Will find AppDelegate through responder chain
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
        hideOthersItem.keyEquivalentModifierMask = [NSEvent.ModifierFlags.command, NSEvent.ModifierFlags.option]
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
        redoItem.keyEquivalentModifierMask = [NSEvent.ModifierFlags.command, NSEvent.ModifierFlags.shift]
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
        showFloatingButtonItem.target = nil // Will find AppDelegate through responder chain
        showFloatingButtonItem.state = SettingsManager.shared.isFloatingButtonEnabled ? .on : .off
        appDelegate?.showFloatingButtonMenuItem = showFloatingButtonItem
        viewMenu.addItem(showFloatingButtonItem)
        
        viewMenu.addItem(NSMenuItem.separator())
        
        let enterFullScreenItem = NSMenuItem(title: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        enterFullScreenItem.keyEquivalentModifierMask = [NSEvent.ModifierFlags.command, NSEvent.ModifierFlags.control]
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
        helpItem.target = nil // Will find AppDelegate through responder chain
        helpMenu.addItem(helpItem)
        
        return mainMenu
    }
    
    /// Creates the AI Services submenu with all available services.
    ///
    /// This method:
    /// - Gets current services from SettingsManager
    /// - Creates menu items for each service with checkmarks for enabled state
    /// - Adds separator and "Reorder..." option
    /// - Sets up actions to toggle service state
    static func createAIServicesMenu(_ menu: NSMenu) {
        // Clear existing items
        menu.removeAllItems()
        
        // Get services from SettingsManager
        let services = SettingsManager.shared.getServices()
        let sortedServices = services.sorted { $0.order < $1.order }
        
        // Log what services we're using to create menu items
        print("🍽️ MenuBuilder.createAIServicesMenu() - Creating menu with services:")
        for service in sortedServices {
            print("   \(service.name): \(service.enabled ? "✅ enabled" : "❌ disabled") → menu state: \(service.enabled ? ".on" : ".off")")
        }
        
        // Add menu item for each service
        for service in sortedServices {
            let menuItem = NSMenuItem(title: service.name, action: #selector(AppDelegate.toggleAIService(_:)), keyEquivalent: "")
            menuItem.target = nil // Will find AppDelegate through responder chain
            menuItem.representedObject = service.id
            menuItem.state = service.enabled ? .on : .off
            menu.addItem(menuItem)
        }
        
        // Add separator and reorder option
        menu.addItem(NSMenuItem.separator())
        
        let reorderItem = NSMenuItem(title: "Reorder...", action: #selector(AppDelegate.openReorderSettings(_:)), keyEquivalent: "")
        reorderItem.target = nil // Will find AppDelegate through responder chain
        reorderItem.indentationLevel = 0 // Ensure no indentation
        menu.addItem(reorderItem)
        
        print("🍽️ MenuBuilder.createAIServicesMenu() - Menu creation completed")
    }
}

// MARK: - App Delegate

/// Central application controller and lifecycle manager.
///
/// Created by:
/// - macOS system at application launch
///
/// Creates and manages:
/// - `FloatingButtonManager`: The persistent floating button
/// - `OverlayController`: All application windows
/// - `PromptWindowController`: Floating prompt input
/// - `SPUStandardUpdaterController`: Sparkle auto-updates
/// - `SettingsWindowController`: Settings window (lazy)
///
/// Lifecycle methods:
/// - `applicationWillFinishLaunching`: Sets up menu bar
/// - `applicationDidFinishLaunching`: Main initialization
/// - `applicationWillTerminate`: Cleanup (currently unused)
class AppDelegate: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {
    /// Manager for the floating button that triggers Hyperchat
    var floatingButtonManager: FloatingButtonManager
    
    /// Controller for all application windows
    var overlayController: OverlayController
    
    /// Controller for the floating prompt input window
    var promptWindowController: PromptWindowController
    
    /// Sparkle updater for auto-updates
    var updaterController: SPUStandardUpdaterController?
    
    /// Settings window controller (created on demand)
    var settingsWindowController: SettingsWindowController?
    
    /// Reference to AI Services menu for dynamic updates
    var aiServicesMenu: NSMenu?
    
    /// Reference to Show Floating Button menu item for dynamic updates
    var showFloatingButtonMenuItem: NSMenuItem?
    
    
    /// Claude login alert controller (created on demand)
    var claudeLoginAlertController: ClaudeLoginAlertController?

    override init() {
        self.floatingButtonManager = FloatingButtonManager()
        self.overlayController = OverlayController()
        // Pass app focus publisher to promptWindowController for app focus state access
        self.promptWindowController = PromptWindowController(appFocusPublisher: self.overlayController.$isAppFocused.eraseToAnyPublisher())
        super.init()
        self.updaterController = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Menu setup moved to applicationDidFinishLaunching with async dispatch
        // to avoid conflicts with SwiftUI
    }
    
    /// Main application initialization point.
    ///
    /// Startup sequence:
    /// 1. Register custom fonts (Orbitron for branding)
    /// 2. Connect floating button to controllers
    /// 3. Show floating button
    /// 4. Check for auto-installation prompt
    /// 5. Show initial window (CRITICAL requirement)
    /// 6. Start update checker with delay
    /// 7. Set up notification observers
    ///
    /// Important:
    /// - Window MUST show on startup (core requirement)
    /// - Update checker delayed to prevent conflicts
    /// - Notifications connect components loosely
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Debugging code
        #if DEBUG
        print("\n🔍 SPARKLE DEBUG INFO:")
        print("🆔 Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")

        if let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String {
            print("🔑 Public Key: \(publicKey)")
        // Show first and last 20 chars to verify it's the right key
            let prefix = String(publicKey.prefix(20))
            let suffix = String(publicKey.suffix(20))
            print("🔑 Key preview: \(prefix)...\(suffix)")
            } 

            print("🌐 Feed URL: \(Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") ?? "nil")")
            print(String(repeating: "=", count: 50))
            #endif
        
        // Set up the main menu synchronously, passing a reference to self
        NSApp.mainMenu = MenuBuilder.createMainMenu(appDelegate: self)
        print("🍽️ Main menu created synchronously, aiServicesMenu reference: \(aiServicesMenu != nil ? "✅ available" : "❌ nil")")
        
        // Register custom fonts
        registerCustomFonts()
        
        // Initialize analytics (respects user privacy preferences)
        AnalyticsManager.shared.initialize()
        
        floatingButtonManager.promptWindowController = promptWindowController
        floatingButtonManager.overlayController = self.overlayController
        floatingButtonManager.showFloatingButton()
        
        // Check for auto-installation on first launch
        AutoInstaller.shared.checkAndPromptInstallation()
        
        // Show the window in normal view on startup
        overlayController.showOverlay()
        
        // Delay constants
        let updaterStartDelay: TimeInterval = 2.0
        
        // Start Sparkle updater after a delay to avoid startup conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + updaterStartDelay) { [weak self] in
            self?.startUpdater()
        }
        
        // Listen for prompt submission to show overlay
        NotificationCenter.default.addObserver(forName: .showOverlay, object: nil, queue: .main) { [weak self] notification in
            if let prompt = notification.object as? String {
                self?.overlayController.showOverlay(with: prompt)
            }
        }
        
        // Listen for overlay hide to ensure floating button stays visible
        NotificationCenter.default.addObserver(forName: .overlayDidHide, object: nil, queue: .main) { [weak self] _ in
            self?.floatingButtonManager.ensureFloatingButtonVisible()
        }
        
        // Listen for floating button toggle to update menu state
        NotificationCenter.default.addObserver(forName: .floatingButtonToggled, object: nil, queue: .main) { [weak self] notification in
            self?.updateFloatingButtonMenuItem()
        }
        
        // Listen for services updates to refresh AI Services menu
        NotificationCenter.default.addObserver(forName: .servicesUpdated, object: nil, queue: .main) { [weak self] _ in
            self?.updateAIServicesMenu()
        }
        
        
        // Listen for Claude login alert closure to clean up reference
        NotificationCenter.default.addObserver(forName: .claudeLoginAlertClosed, object: nil, queue: .main) { [weak self] _ in
            self?.claudeLoginAlertController = nil
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    private func registerCustomFonts() {
        if let fontURL = Bundle.main.url(forResource: "Orbitron-Bold", withExtension: "ttf") {
            print("Found font file at: \(fontURL.path)")
            
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
                print("✅ Orbitron font registered successfully")
                
                // Try different font name variations
                let variations = ["Orbitron-Bold", "Orbitron Bold", "OrbitronBold", "Orbitron"]
                for name in variations {
                    if let _ = NSFont(name: name, size: 12) {
                        print("✅ Font available as: '\(name)'")
                    }
                }
            } else {
                if let error = error {
                    print("❌ Failed to register font: \(error.takeRetainedValue())")
                }
            }
        } else {
            print("❌ Failed to find Orbitron font file in bundle")
        }
    }
    
    /// Handles "Check for Updates..." menu action.
    ///
    /// Called by:
    /// - Menu bar "Check for Updates..." item
    ///
    /// Process:
    /// 1. Ensures updater is started
    /// 2. Triggers manual update check
    /// 3. Shows update dialog if available
    @objc func checkForUpdates(_ sender: Any?) {
        guard let updaterController = updaterController else {
            print("Sparkle: Updater controller not initialized")
            // Show error to user
            let alert = NSAlert()
            alert.messageText = "Update Check Failed"
            alert.informativeText = "The updater is not available. Please restart the app and try again."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Ensure updater is started before checking for updates
        if !updaterController.updater.sessionInProgress {
            do {
                try updaterController.updater.start()
            } catch {
                print("Sparkle: Failed to start updater - \(error.localizedDescription)")
                // Show error to user
                let alert = NSAlert()
                alert.messageText = "Update Check Failed"
                alert.informativeText = "Unable to start the updater. Error: \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return
            }
        }
        
        // Trigger the update check - delegate methods will handle user feedback
        updaterController.checkForUpdates(sender)
    }
    
    /// Shows the settings window.
    ///
    /// Called by:
    /// - Menu bar "Settings..." item (Cmd+,)
    ///
    /// Creates SettingsWindowController on first use (lazy initialization).
    @objc func showSettings(_ sender: Any?) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(sender)
    }
    
    /// Opens the default email client to send a help request.
    ///
    /// Called by:
    /// - Help menu "Get Help" item (Cmd+?)
    ///
    /// Creates a mailto URL with pre-filled recipient and subject line.
    /// The email address is matt@hyperchat.app with subject "Help Me".
    @objc func getHelp(_ sender: Any?) {
        let emailAddress = "matt@hyperchat.app"
        let subject = "Help Me"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        
        guard let mailtoURL = URL(string: "mailto:\(emailAddress)?subject=\(encodedSubject)") else {
            print("❌ Failed to create mailto URL")
            return
        }
        
        NSWorkspace.shared.open(mailtoURL)
    }
    
    /// Toggles the floating button visibility on/off.
    ///
    /// Called by:
    /// - View menu "Show Floating Button" item
    ///
    /// Process:
    /// 1. Toggle the setting in SettingsManager
    /// 2. SettingsManager posts notification to update UI
    /// 3. FloatingButtonManager responds to notification
    @objc func toggleFloatingButton(_ sender: Any?) {
        let newState = !SettingsManager.shared.isFloatingButtonEnabled
        SettingsManager.shared.isFloatingButtonEnabled = newState
        print("🔘 Floating button toggled to: \(newState ? "enabled" : "disabled")")
    }
    
    /// Toggles an AI service on or off.
    ///
    /// Called by:
    /// - AI Services menu items
    ///
    /// Process:
    /// 1. Extract service ID from menu item's representedObject
    /// 2. Toggle the service's enabled state
    /// 3. Update via SettingsManager to persist change
    /// 4. SettingsManager posts notification to update ServiceManager
    /// 5. For Claude, show simple info window when first enabled
    @objc func toggleAIService(_ sender: Any?) {
        print("🔘 AppDelegate.toggleAIService() - Menu item clicked")
        
        guard let menuItem = sender as? NSMenuItem,
              let serviceId = menuItem.representedObject as? String else {
            print("⚠️ Could not extract service ID from menu item")
            return
        }
        
        print("🔘 Toggling service: \(serviceId)")
        
        var services = SettingsManager.shared.getServices()
        if let index = services.firstIndex(where: { $0.id == serviceId }) {
            let wasEnabled = services[index].enabled
            services[index].enabled.toggle()
            let newState = services[index].enabled
            
            print("🔘 Service \(services[index].name): \(wasEnabled ? "enabled" : "disabled") → \(newState ? "enabled" : "disabled")")
            
            // Save the service state immediately
            SettingsManager.shared.saveServices(services)
            print("🔘 AI Service \(services[index].name) toggled to: \(newState ? "enabled" : "disabled")")
            
            // Special handling for Claude: show info window when enabling
            if serviceId == "claude" && !wasEnabled && newState {
                // User enabled Claude - show simple info window
                showClaudeInfoWindow()
            }
            
            // Post notification to update ServiceManager and this AppDelegate
            print("📣 Posting .servicesUpdated notification")
            NotificationCenter.default.post(name: .servicesUpdated, object: nil)
        } else {
            print("❌ Could not find service with ID: \(serviceId)")
        }
    }
    
    /// Opens the settings window to the reorder section.
    ///
    /// Called by:
    /// - AI Services menu "Reorder..." item
    ///
    /// Simply shows the settings window where users can reorder services.
    @objc func openReorderSettings(_ sender: Any?) {
        showSettings(sender)
    }
    
    
    /// Shows Claude info window when user enables Claude service.
    ///
    /// Called by:
    /// - `toggleAIService` when user enables Claude from menu
    ///
    /// Shows a simple informational window explaining that Claude works
    /// like other services and the user can log in normally.
    private func showClaudeInfoWindow() {
        print("ℹ️ Showing Claude info window...")
        
        // Show Claude info window
        if claudeLoginAlertController == nil {
            claudeLoginAlertController = ClaudeLoginAlertController()
        }
        claudeLoginAlertController?.showWindow(nil)
    }
    
    // MARK: - Menu Update Methods
    
    /// Updates the floating button menu item's checkmark state.
    ///
    /// Called by:
    /// - Notification observer when floating button setting changes
    ///
    /// This keeps the View menu in sync with the Settings window toggle.
    private func updateFloatingButtonMenuItem() {
        showFloatingButtonMenuItem?.state = SettingsManager.shared.isFloatingButtonEnabled ? .on : .off
    }
    
    /// Updates the AI Services menu items to reflect current service states.
    ///
    /// Called by:
    /// - Notification observer when services are updated
    ///
    /// This rebuilds the entire AI Services menu to reflect:
    /// - Service enabled/disabled states
    /// - Service reordering
    /// - New or removed services
    private func updateAIServicesMenu() {
        print("🔄 AppDelegate.updateAIServicesMenu() - Menu update triggered")
        guard let menu = aiServicesMenu else { 
            print("❌ AppDelegate.updateAIServicesMenu() - aiServicesMenu is nil! Deferring update...")
            // Defer the update to the next run loop cycle in case menu creation is still in progress
            DispatchQueue.main.async { [weak self] in
                self?.updateAIServicesMenu()
            }
            return 
        }
        
        MenuBuilder.createAIServicesMenu(menu)
        
        // Force the menu to update its display
        menu.update()
        print("🔄 AppDelegate.updateAIServicesMenu() - Menu update completed")
    }
    
    /// Starts the Sparkle updater for automatic update checks.
    ///
    /// Called by:
    /// - `applicationDidFinishLaunching` after startup delay
    ///
    /// The updater will:
    /// - Check for updates periodically
    /// - Respect user preferences for automatic updates
    /// - Download and install updates with user permission
    private func startUpdater() {
        guard let updaterController = updaterController else {
            print("Sparkle: Updater controller not initialized")
            return
        }
        do {
            try updaterController.updater.start()
            print("Sparkle: Updater started successfully")
        } catch {
            print("Sparkle: Failed to start updater - \(error.localizedDescription)")
        }
    }
    
    // MARK: - SPUUpdaterDelegate
    
    /// Sparkle updater delegate methods for customizing update behavior.
    /// Currently using default behavior for all delegate methods.
    
    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        print("Sparkle: Successfully loaded appcast")
    }
    
    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        print("Sparkle: No update found - \(error.localizedDescription)")
        
        // Let Sparkle handle the user-facing dialog
        // Custom alert removed to prevent duplicate notifications
    }
    
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        print("Sparkle: Update aborted - \(error.localizedDescription)")
        
        // Let Sparkle handle the user-facing dialog
        // Custom alert removed to prevent duplicate notifications
    }
    
    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        print("Sparkle: Failed to download update - \(error.localizedDescription)")
    }
}