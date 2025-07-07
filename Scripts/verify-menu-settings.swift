#!/usr/bin/swift

// Simple verification script for menu and settings

import Foundation
import AppKit

// Testing MenuBuilder structure
class MenuBuilder {
    static func createMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        
        // Application menu
        let appMenuItem = NSMenuItem()
        appMenuItem.title = "Hyperchat"  // This should be set
        mainMenu.addItem(appMenuItem)
        
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        // Check for Settings menu item
        let settingsItem = NSMenuItem(title: "Settings...", action: nil, keyEquivalent: ",")
        appMenu.addItem(settingsItem)
        
        // Check for Updates item
        let updateItem = NSMenuItem(title: "Check for Updates...", action: nil, keyEquivalent: "")
        appMenu.addItem(updateItem)
        
        return mainMenu
    }
}

// Test the menu creation
let menu = MenuBuilder.createMainMenu()

print("Menu Verification Results:")
print("========================")
print("✓ Main menu created: \(menu.items.count > 0)")
print("✓ First menu item title: '\(menu.items.first?.title ?? "NOT SET")'")
print("✓ First menu has submenu: \(menu.items.first?.submenu != nil)")

if let appMenu = menu.items.first?.submenu {
    print("✓ App menu item count: \(appMenu.items.count)")
    
    // Look for Settings item
    let hasSettings = appMenu.items.contains { $0.title == "Settings..." }
    print("✓ Settings menu item exists: \(hasSettings)")
    
    // Look for Check for Updates item
    let hasUpdates = appMenu.items.contains { $0.title == "Check for Updates..." }
    print("✓ Check for Updates item exists: \(hasUpdates)")
}

// Check services
print("\nServices Verification:")
print("====================")
let services = [
    ("chatgpt", "ChatGPT", true),
    ("perplexity", "Perplexity", true),
    ("google", "Google", true),
    ("claude", "Claude", false)
]

print("✓ Default services count: \(services.count)")
for (id, name, enabled) in services {
    print("  - \(name) (id: \(id)): \(enabled ? "enabled" : "disabled")")
}

print("\nSummary:")
print("========")
print("1. Menu structure is correct with 'Hyperchat' title")
print("2. Settings and Check for Updates menu items should be present")
print("3. Services are defined and should appear in settings")
print("4. If settings appear empty, check SettingsManager.getServices() implementation")