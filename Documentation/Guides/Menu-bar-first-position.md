# macOS Menu Bar Positioning Guide

This guide explains how to make your macOS app's menu bar item appear as the first (rightmost) item in the system menu bar.

## The Core Concept

macOS uses `UserDefaults` to remember the position of menu bar items. We can set an initial position for our app's item by writing to a specific, undocumented key before the item is created. A position of `0` corresponds to the rightmost position, next to the system icons.

---

## AppKit Implementation

This is the traditional approach for apps built with AppKit using `NSStatusItem`.

### 1. Status Item Manager

Create a manager class to handle the creation and positioning of the `NSStatusItem`.

```swift
import Cocoa

class StatusItemManager {
    private let statusItem: NSStatusItem
    
    init(autosaveName: String) {
        let key = "NSStatusItem Preferred Position \(autosaveName)"
        
        // Force position to 0 (rightmost) if no user preference exists.
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(0, forKey: key)
        }
        
        // Create the status item.
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = autosaveName // This MUST match the name used above.
        
        self.statusItem = statusItem
    }
    
    func setMenu(_ menu: NSMenu) {
        statusItem.menu = menu
    }
    
    func setIcon(image: NSImage?) {
        statusItem.button?.image = image
    }
}
```

### 2. AppDelegate Setup

In your `AppDelegate`, initialize your `StatusItemManager` and set the app's activation policy if it's a menu-bar-only app.

```swift
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItemManager: StatusItemManager?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // For menu-bar-only apps, hide the Dock icon.
        // NSApp.setActivationPolicy(.accessory)
        
        // Initialize the status item manager with a unique name.
        statusItemManager = StatusItemManager(autosaveName: "YourAppMenuBarItem")
        
        // Create and set your menu.
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Hello World", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItemManager?.setMenu(menu)
        statusItemManager?.setIcon(image: NSImage(systemSymbolName: "star.fill", accessibilityDescription: "My App"))
    }
}
```

---

## SwiftUI Implementation

For modern apps built with SwiftUI, the same `UserDefaults` trick applies, but you use a `MenuBarExtra` scene.

You configure this in your `App` struct's `init()`.

```swift
import SwiftUI

@main
struct YourSwiftUIApp: App {
    private let menuBarExtraId = "YourAppMenuBarExtra"

    init() {
        let key = "NSStatusItem Preferred Position \(menuBarExtraId)"
        
        // Force position to 0 (rightmost) if no user preference exists.
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(0, forKey: key)
        }
    }
    
    var body: some Scene {
        // The `id` here MUST match the one used to construct the UserDefaults key above.
        MenuBarExtra("Your App", systemImage: "star.fill") {
            Button("Do Something") {
                // ...
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtra(id: menuBarExtraId)
    }
}
```

## Key Takeaways

- **The Hack**: The technique relies on setting the `NSStatusItem Preferred Position` key in `UserDefaults` to `0`.
- **Consistency is Key**: The `autosaveName` (for AppKit) or `id` (for SwiftUI) *must* be consistent throughout your code.
- **First Launch Only**: This only forces the position on the first launch. After that, macOS respects the user's placement of the icon.
- **Accessory Policy**: Use `NSApp.setActivationPolicy(.accessory)` for applications that should not have a Dock icon or appear in the app switcher.