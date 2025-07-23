# Programmatic Window Management in SwiftUI for macOS

This guide provides a canonical architecture for taking full programmatic control over window creation in a SwiftUI macOS application.

## The Core Problem: A Lifecycle Timing Conflict

The central challenge is a timing conflict between SwiftUI's declarative lifecycle and AppKit's imperative one.

- **SwiftUI (`@main App`)**: You declare your UI in a `Scene`. If you use a `WindowGroup`, SwiftUI's contract is to create a window for it *immediately* at launch.
- **AppKit (`AppDelegate`)**: The traditional place to create windows programmatically is in the `applicationDidFinishLaunching(_:)` delegate method.

**The conflict**: SwiftUI creates its window *before* `applicationDidFinishLaunching(_:)` is ever called. This means any attempt to manage windows from the delegate is already too late, leading to an unwanted initial window, visual flicker, or other bugs.

---

## Section 1: Common But Flawed Approaches

Here are common workarounds and why they are unreliable or dangerous.

### 1.1 The `WindowGroup { EmptyView() }` Trap

This approach tries to satisfy the `App` protocol with a "nothing" view to prevent a window.

**Why it fails**: The contract of `WindowGroup` is to create a window, period. `EmptyView` is a valid, concrete view, not a null-operation. The result is a standard, but completely blank, window. **This does not work.**

### 1.2 The `Settings` Scene Trap

This approach replaces `WindowGroup` with a `Settings` scene, which successfully suppresses an initial window at launch.

**Why it fails**: This introduces a catastrophic side effect: it corrupts `NSApp.mainMenu`, permanently breaking the responder chain for standard actions like copy, paste, and undo. The `Settings` scene's internal machinery aggressively overwrites the main menu, destroying any custom setup. **Do not use this method.**

### 1.3 The "Close-on-Launch" Workaround

This approach lets SwiftUI create its default window, then finds and closes it in `applicationDidFinishLaunching(_:)`.

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // Find and close the initial window created by SwiftUI.
    if let window = NSApplication.shared.windows.first {
        window.close()
    }
    // ... then create programmatic windows.
}
```

**Why it's bad**: It causes a visible **"flicker"** at launch as a window appears and immediately vanishes. This is an unprofessional user experience and should be avoided.

---

## Section 2: The Canonical Architecture (macOS 12-14)

For apps that must support older macOS versions, this is the robust, flicker-free solution. It redefines the application as a background agent, giving the `AppDelegate` full control.

### Step 1: Modify `Info.plist` to Become a UI Agent

This is the foundational step. It tells the operating system not to expect a main window at launch.

- **Action**: Add the key `Application is agent (UIElement)` to your `Info.plist` file and set its Boolean value to `YES`. (Raw key: `LSUIElement`).
- **Effect**:
    1.  The application's icon will not appear in the Dock.
    2.  The system no longer forces a window to be visible at launch, neutralizing SwiftUI's `WindowGroup` behavior.

### Step 2: Provide a "Headless" `Settings` Scene

With the app's launch policy changed, you must still satisfy the `App` protocol's requirement for a `Scene`.

- **Action**: In your `@main App` struct, provide *only* a `Settings` scene.
- **Code**:
    ```swift
    @main
    struct MyApp: App {
        @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
        
        var body: some Scene {
            Settings {
                // This view is a placeholder, only shown if the user
                // manually opens settings.
                EmptyView()
            }
        }
    }
    ```
- **Why it's safe now**: The `LSUIElement` flag prevents the menu corruption bug. Because there is no `WindowGroup` or other primary scene, the `Settings` scene's menu logic runs without conflict, creating a stable base for your `AppDelegate` to build upon.

### Step 3: The `AppDelegate` Takes Full Control

With the launch behavior suppressed, `applicationDidFinishLaunching` is now the correct and reliable place to create and manage all windows.

- **Implementation**:
    ```swift
    class AppDelegate: NSObject, NSApplicationDelegate {
        // 1. Hold a strong reference to prevent the window from deallocating.
        var window: NSWindow!

        func applicationDidFinishLaunching(_ aNotification: Notification) {
            // 2. Define the root SwiftUI view.
            let contentView = MyRootSwiftUIView()

            // 3. Create the NSWindow instance.
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false)
            window.center()
            window.title = "My Programmatic Window"

            // 4. Host the SwiftUI view within the AppKit window.
            window.contentView = NSHostingView(rootView: contentView)

            // 5. Activate the app to bring it to the foreground (CRITICAL for agents).
            NSApp.activate(ignoringOtherApps: true)

            // 6. Make the window visible and key.
            window.makeKeyAndOrderFront(nil)
        }

        // 7. Prevent the app from quitting when the last window is closed.
        func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
            return false
        }
    }
    ```

---

## Section 3: The Modern Solution (macOS 15+)

Apple introduced a clean, official API in macOS 15 that makes all workarounds obsolete.

- **Action**: Use the `.defaultLaunchBehavior(.suppressed)` scene modifier.
- **Mechanism**: This modifier explicitly instructs SwiftUI not to present the scene's window automatically at launch.
- **Code**:
    ```swift
    @main
    struct MyApp: App {
        // An AppDelegate is still used for programmatic window creation.
        @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

        var body: some Scene {
            // Declare the window scene, but suppress its automatic launch.
            Window("Main Window", id: "main") {
                MyRootSwiftUIView()
            }
           .defaultLaunchBehavior(.suppressed) // The canonical solution
        }
    }
    ```
**This is the definitive, recommended solution for any project targeting macOS 15 or later.**

---

## Section 4: Comparative Analysis

| Method | Mechanism | macOS Compatibility | Pros | Cons/Side-Effects | Recommendation |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`WindowGroup { EmptyView() }`** | Provides a contentless view to a window scene. | macOS 11+ | Simple declaration. | Fails. Creates a visible, blank window. | **Do not use.** Fundamentally flawed. |
| **"Close-on-Launch"** | Imperatively closes the initial SwiftUI window. | macOS 11+ | Simple; no `Info.plist` change. | High risk of visible "flicker". | **Avoid.** Unprofessional UX. |
| **`Settings {}` (alone)** | Uses `Settings` as the only scene. | macOS 12+ | Suppresses the initial window. | Corrupts `NSApp.mainMenu`. | **Do not use.** Breaks core app functionality. |
| **`LSUIElement` + `Settings {}`** | Declares app as agent; uses `Settings` as headless placeholder. | macOS 12-14 | Robust, reliable, no flicker, no menu bug. | Requires `Info.plist` change; app has no Dock icon. | **Recommended for macOS 12-14.** |
| **`.defaultLaunchBehavior(.suppressed)`** | SwiftUI modifier prevents automatic window presentation. | macOS 15+ | **Canonical.** Clean, declarative, reliable. | Requires targeting macOS 15+. | **The definitive solution for macOS 15+.** |

---

## Section 5: Advanced Considerations & Best Practices

### 5.1 Window State and Application Termination

- **Strong Reference**: Always maintain a strong reference to any programmatically created `NSWindow` in your `AppDelegate` to prevent it from being deallocated.
- **Termination**: For agent-style apps or menu bar utilities, `applicationShouldTerminateAfterLastWindowClosed(_:)` **must** return `false`. Termination should be handled by an explicit user action (e.g., a "Quit" menu item).

### 5.2 Activating the App to Show Windows

For an agent app without a Dock icon, a new window may appear behind other apps. To ensure it appears front-and-center, you must activate the app first.

**Correct Order**:
1.  Call `NSApp.activate(ignoringOtherApps: true)`.
2.  Call `window.makeKeyAndOrderFront(nil)`.

### 5.3 Safe Menu Management

The `LSUIElement` + `Settings` architecture provides a stable environment for menu creation. The `AppDelegate` can safely build a custom menu in `applicationDidFinishLaunching` without fear of it being overwritten.

```swift
func applicationDidFinishLaunching(_ aNotification: Notification) {
    // ... window creation code ...

    // --- Safe Menu Creation ---
    let mainMenu = NSMenu()
    NSApp.mainMenu = mainMenu

    // Create the App Menu (e.g., "MyApp")
    let appMenuItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenuItem.submenu = appMenu
    mainMenu.addItem(appMenuItem)

    appMenu.addItem(withTitle: "About MyApp", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Quit MyApp", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

    // Create a File Menu
    let fileMenuItem = NSMenuItem()
    let fileMenu = NSMenu(title: "File")
    fileMenuItem.submenu = fileMenu
    mainMenu.addItem(fileMenuItem)

    fileMenu.addItem(withTitle: "New Window", action: #selector(openNewWindow), keyEquivalent: "n")
}

@objc func openNewWindow() {
    // Logic to create and show a new programmatic window.
}
```
This confirms the `LSUIElement` architecture is a complete solution for building complex, delegate-driven macOS applications.