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
    
    static func createMainMenu() -> NSMenu {
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
        
        let helpItem = NSMenuItem(title: "Hyperchat Help", action: #selector(NSApplication.showHelp(_:)), keyEquivalent: "?")
        helpMenu.addItem(helpItem)
        
        return mainMenu
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

    override init() {
        self.floatingButtonManager = FloatingButtonManager()
        self.overlayController = OverlayController()
        self.promptWindowController = PromptWindowController()
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
        // Set up the main menu with async dispatch to ensure it runs after SwiftUI initialization
        DispatchQueue.main.async {
            NSApp.mainMenu = MenuBuilder.createMainMenu()
        }
        
        // Register custom fonts
        registerCustomFonts()
        
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
            return
        }
        // Ensure updater is started before checking for updates
        if !updaterController.updater.sessionInProgress {
            do {
                try updaterController.updater.start()
            } catch {
                print("Sparkle: Failed to start updater - \(error.localizedDescription)")
                return
            }
        }
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
    }
    
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        print("Sparkle: Update aborted - \(error.localizedDescription)")
    }
    
    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        print("Sparkle: Failed to download update - \(error.localizedDescription)")
    }
}