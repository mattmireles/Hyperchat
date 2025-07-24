# macOS Accessory Mode Switching Guide

This comprehensive guide explains how to implement dynamic switching between accessory mode (menu bar only) and regular mode (with dock icon) in macOS applications, based on the implementation in this TalkTastic app.

## Table of Contents
- [Core Architecture](#core-architecture)
- [Implementation Pattern](#implementation-pattern)
- [Key Files Analysis](#key-files-analysis)
- [Step-by-Step Implementation](#step-by-step-implementation)
- [Window Management](#window-management)
- [State Transition Lifecycle](#state-transition-lifecycle)
- [Best Practices](#best-practices)
- [Common Pitfalls](#common-pitfalls)
- [Complete Example](#complete-example)

## Core Architecture

### The Central Pattern
The app uses **dynamic NSApplication activation policy switching** to seamlessly transition between:
- **`.accessory` mode**: App runs in background, no dock icon, menu bar presence only
- **`.regular` mode**: Normal app with dock icon, appears in app switcher, full window management

### Key Components
1. **AppDelegate**: Manages global app state and initial policy setting
2. **MainVC**: Handles window-driven policy changes and UI transitions  
3. **NSWindowDelegate**: Tracks window focus events for automatic policy switching
4. **Menu Bar Integration**: Maintains persistent menu bar presence in both modes

## Implementation Pattern

### 1. Initial Setup (AppDelegate.swift:141)
```swift
func applicationDidFinishLaunching(_ aNotification: Notification) {
    // Start in accessory mode - no dock icon
    _ = NSApp.setActivationPolicy(.accessory)
    
    // Initialize menu bar and core services
    goStatusBar()
}
```

### 2. Show Window Pattern (MainVC.swift:68-74)
```swift
func show() {
    guard BackendManager.tokenAvailable else { return }
    
    // 1. Make window visible first
    view.window?.makeKeyAndOrderFront(nil)
    
    // 2. Switch to regular mode (adds dock icon)
    NSApp.setActivationPolicy(.regular)
    
    // 3. Force app activation
    NSApp.activate(ignoringOtherApps: true)
    NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
}
```

### 3. Hide Window Pattern (MainVC.swift:76-81)
```swift
func close() {
    // Reset UI state
    Env.shared.sidebarViewIndex = 0
    Env.shared.settingsSectionIndex = 0
    
    // Hide window
    view.window?.orderOut(nil)
    
    // Return to accessory mode (removes dock icon)
    NSApp.setActivationPolicy(.accessory)
}
```

### 4. Window Delegate Monitoring (MainVC.swift:104-110)
```swift
func windowWillClose(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
}

func windowDidBecomeMain(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
}
```

## Key Files Analysis

### AppDelegate.swift
**Purpose**: Global app lifecycle management
- Sets initial `.accessory` policy
- Handles app reopen events
- Manages authentication state checks

**Key Methods**:
- `applicationDidFinishLaunching`: Initial accessory mode setup
- `applicationShouldHandleReopen`: Handle dock icon clicks when in regular mode
- `applicationDidBecomeActive`: Ensure proper window focus on activation

### MainVC.swift  
**Purpose**: Window-centric policy management
- Primary controller for show/hide operations
- Implements NSWindowDelegate for focus tracking
- Manages UI state transitions

**Critical Pattern**:
```swift
// Always switch policy BEFORE window operations for show
NSApp.setActivationPolicy(.regular)
view.window?.makeKeyAndOrderFront(nil)

// Always switch policy AFTER window operations for hide  
view.window?.orderOut(nil)
NSApp.setActivationPolicy(.accessory)
```

### AppDelegateDock.swift
**Purpose**: Alternative dock-centric implementation
- Shows different architectural approach
- Demonstrates app behavior with permanent dock presence
- Uses `canShowMainWindow` state management

## Step-by-Step Implementation

### Step 1: Setup Basic Structure
```swift
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Start in accessory mode
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize your menu bar item
        setupMenuBar()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't terminate when last window closes - stay in accessory mode
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Handle dock icon clicks (when app becomes regular)
        if isUserLoggedIn() {
            MainWindowController.shared.show()
        }
        return false
    }
}
```

### Step 2: Create Window Controller with Policy Management
```swift
class MainWindowController: NSWindowController, NSWindowDelegate {
    static let shared = MainWindowController()
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        window.delegate = self
        window.setFrameAutosaveName("MainWindow")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show() {
        // Critical: Set policy BEFORE making window key
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        window?.makeKeyAndOrderFront(nil)
        
        // Ensure full activation
        NSRunningApplication.current.activate(options: [
            .activateAllWindows,
            .activateIgnoringOtherApps
        ])
    }
    
    func hide() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        // Return to accessory mode when window closes
        NSApp.setActivationPolicy(.accessory)
    }
    
    func windowDidBecomeMain(_ notification: Notification) {
        // Ensure we're in regular mode when window becomes main
        NSApp.setActivationPolicy(.regular)
    }
    
    func windowDidResignMain(_ notification: Notification) {
        // Optional: Handle window losing main status
        // You might want to stay in regular mode or switch based on other windows
    }
}
```

### Step 3: Menu Bar Integration
```swift
class MenuBarManager {
    private let statusItem: NSStatusItem
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupMenuBarItem()
    }
    
    private func setupMenuBarItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "My App")
            button.action = #selector(menuBarButtonClicked)
            button.target = self
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Window", action: #selector(showWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc private func menuBarButtonClicked() {
        MainWindowController.shared.show()
    }
    
    @objc private func showWindow() {
        MainWindowController.shared.show()
    }
}
```

## Window Management

### Focus Tracking Strategy
The app uses multiple NSWindowDelegate methods to ensure proper policy management:

```swift
// Primary methods for policy switching
func windowWillClose(_ notification: Notification) {
    // ALWAYS return to accessory when closing
    NSApp.setActivationPolicy(.accessory)
}

func windowDidBecomeMain(_ notification: Notification) {
    // ALWAYS ensure regular mode when becoming main
    NSApp.setActivationPolicy(.regular)
}

// Optional methods for enhanced tracking
func windowDidBecomeKey(_ notification: Notification) {
    // Track analytics, update UI state
}

func windowDidResignKey(_ notification: Notification) {
    // Handle focus loss, dismiss modals
}
```

### Multi-Window Considerations
```swift
func windowWillClose(_ notification: Notification) {
    // Check if other windows remain visible
    let visibleWindows = NSApp.windows.filter { $0.isVisible && $0 != notification.object as? NSWindow }
    
    if visibleWindows.isEmpty {
        // No other windows - return to accessory mode
        NSApp.setActivationPolicy(.accessory)
    }
    // Otherwise stay in regular mode
}
```

## State Transition Lifecycle

### 1. App Launch
```
Launch → .accessory mode → Menu bar appears → Background state
```

### 2. User Activation (Menu click, hotkey, etc.)
```
Background → show() called → .regular mode → Window appears → Dock icon appears → Foreground state
```

### 3. User Deactivation (Window close, hide, etc.)  
```
Foreground → close() called → Window hides → .accessory mode → Dock icon disappears → Background state
```

### 4. System Events
```
App reopen (dock click) → applicationShouldHandleReopen → show() → Foreground state
App activation → applicationDidBecomeActive → Ensure proper window state
```

## Best Practices

### 1. Policy Switching Order
```swift
// ✅ CORRECT - Policy first for showing
NSApp.setActivationPolicy(.regular)
window?.makeKeyAndOrderFront(nil)

// ✅ CORRECT - Window first for hiding  
window?.orderOut(nil)
NSApp.setActivationPolicy(.accessory)

// ❌ WRONG - Can cause visual glitches
window?.makeKeyAndOrderFront(nil)
NSApp.setActivationPolicy(.regular)  // Too late
```

### 2. Activation Options
```swift
// For maximum reliability, use both activation methods
NSApp.activate(ignoringOtherApps: true)
NSRunningApplication.current.activate(options: [
    .activateAllWindows,
    .activateIgnoringOtherApps
])
```

### 3. State Checks
```swift
func show() {
    // Always validate state before showing
    guard isUserAuthenticated() else { return }
    guard !window?.isVisible else { return }
    
    NSApp.setActivationPolicy(.regular)
    // ... rest of show logic
}
```

### 4. Menu Bar Persistence
```swift
// Menu bar should be initialized BEFORE setting accessory mode
// This ensures it persists through policy changes
func applicationDidFinishLaunching(_ aNotification: Notification) {
    setupMenuBar()  // First
    NSApp.setActivationPolicy(.accessory)  // Then
}
```

## Common Pitfalls

### 1. **Window Flash on Policy Change**
**Problem**: Brief window flash when switching policies
**Solution**: Set policy before making window key

### 2. **Dock Icon Persistence**  
**Problem**: Dock icon doesn't disappear after closing window
**Solution**: Ensure `windowWillClose` calls `setActivationPolicy(.accessory)`

### 3. **Menu Bar Disappearance**
**Problem**: Menu bar item disappears on policy switch
**Solution**: Initialize menu bar before setting initial accessory policy

### 4. **Focus Issues**
**Problem**: Window doesn't gain focus properly
**Solution**: Use both `NSApp.activate()` and `NSRunningApplication.current.activate()`

### 5. **Multiple Windows**
**Problem**: Policy switches incorrectly with multiple windows
**Solution**: Check for other visible windows before switching to accessory mode

## Complete Example

Here's a minimal but complete implementation:

```swift
// AppDelegate.swift
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize menu bar FIRST
        menuBarManager = MenuBarManager()
        
        // Then set accessory policy
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // Stay alive in accessory mode
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {  // No visible windows
            MainWindowController.shared.show()
        }
        return false
    }
}

// MainWindowController.swift
class MainWindowController: NSWindowController, NSWindowDelegate {
    static let shared = MainWindowController()
    
    private override init(window: NSWindow?) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        window.delegate = self
        window.title = "My App"
        window.setFrameAutosaveName("MainWindow")
        window.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show() {
        // Switch to regular mode FIRST
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Then show window
        window?.makeKeyAndOrderFront(nil)
        
        // Ensure full activation
        NSRunningApplication.current.activate(options: [
            .activateAllWindows,
            .activateIgnoringOtherApps
        ])
    }
    
    func hide() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
    
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
    
    func windowDidBecomeMain(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
}

// MenuBarManager.swift  
class MenuBarManager {
    private let statusItem: NSStatusItem
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupMenuBarItem()
    }
    
    private func setupMenuBarItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "My App")
        }
        
        let menu = NSMenu()
        
        let showItem = NSMenuItem(title: "Show Window", action: #selector(showWindow), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc private func showWindow() {
        MainWindowController.shared.show()
    }
}
```

This implementation provides a solid foundation for any macOS app that needs to dynamically switch between accessory and regular modes, maintaining a smooth user experience with proper state management and window handling.