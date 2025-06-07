import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingButtonManager: FloatingButtonManager?
    var overlayController: OverlayController?
    var promptWindowController: PromptWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        overlayController = OverlayController()
        promptWindowController = PromptWindowController()
        floatingButtonManager = FloatingButtonManager()
        floatingButtonManager?.promptWindowController = promptWindowController
        floatingButtonManager?.showFloatingButton()
        
        // Setup minimal menu bar for Edit menu (copy/paste support)
        setupMenuBar()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    private func setupMenuBar() {
        let mainMenu = NSMenu()
        
        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit HyperChat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // Edit menu - this enables copy/paste
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        
        editMenu.addItem(withTitle: "Undo", action: #selector(UndoManager.undo), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: #selector(UndoManager.redo), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        NSApp.mainMenu = mainMenu
    }
} 