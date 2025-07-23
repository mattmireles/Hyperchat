# Debugging EXC_BAD_ACCESS WKWebView Crashes: A Complete History

## The Problem
The application experienced persistent and difficult-to-diagnose `EXC_BAD_ACCESS` crashes when closing windows containing `WKWebView` instances. This issue arose because `WKWebView` runs its JavaScript and rendering in a separate `WebContent` process. When a window was closed, asynchronous inter-process communication (IPC) from WebKit could attempt to deliver messages to message handlers or delegates that were already deallocated or in a partially-deallocated state, leading to a crash in `objc_msgSend`.

This document provides a complete chronological history of the debugging process, from initial instrumentation to the final, stable fix.

---

## Part 1: Initial Debugging & Instrumentation

To understand the crash, the first step was to add comprehensive debugging code to trace the lifecycle of all relevant objects.

### Changes Made

#### 1. ConsoleMessageHandler (`WebViewLogger.swift`)
- **`instanceId`**: Added for tracking individual handler instances.
- **`messageType`**: Parameterized to create separate, distinct handlers for each message type (e.g., `log`, `error`).
- **Lifecycle Logging**: Added logs for `init` and `deinit` with timestamps and memory addresses.
- **Retain Count Tracking**: Used `CFGetRetainCount` to monitor for potential retain cycles.
- **`isCleanedUp` flag**: A boolean to detect if any callbacks were received after the handler was supposed to have been cleaned up.
- **`markCleanedUp()`**: A method to formally mark the handler as cleaned up as part of the window-closing sequence.

#### 2. ServiceManager (`ServiceManager.swift`)
- **`instanceId` & `isCleaningUp` flag**: Added for instance tracking and to guard against delegate calls during cleanup.
- **Lifecycle Logging**: Added for `init`/`deinit`.
- **`messageHandlers` dictionary**: Created to track all `ConsoleMessageHandler` instances for systematic cleanup.
- **Cleanup State Checking**: Added guards to all `WKNavigationDelegate` methods to prevent execution if `isCleaningUp` was true.
- **Cleanup Logging**: Added comprehensive logging in `deinit`.

#### 3. OverlayController (`OverlayController.swift`)
- **`instanceId`**: Added to `OverlayWindow` and `OverlayController` for tracking.
- **Detailed Logging**: Added throughout the window closing sequence, including timestamps.
- **Memory Address & Retain Count Logging**: Added for `WKWebView` instances to track their lifecycle.

#### 4. BrowserView (`ServiceManager.swift`)
- **`instanceId`**: Added for tracking individual `BrowserView` instances.
- **Lifecycle Logging**: Added for `init`/`deinit`, including WebView memory addresses and retain counts.

#### 5. CrashDebugger (`CrashDebugger.swift`)
- A new helper class was created to log "breadcrumbs" to a file for post-crash analysis.
- It tracked critical events: window close, WebView cleanup, handler cleanup, and delegate callbacks.
- **Breadcrumb Log Location**: `~/Library/Logs/Hyperchat/crash-breadcrumbs.log`

### How to Use the Debug Info
1.  **Reproduce the crash**: Open and close multiple windows.
2.  **Look for patterns in console output**:
    *   Check timestamps for the exact sequence of events.
    *   Look for delegate callbacks happening after `isCleaningUp` was set to `true` (marked with ⚠️).
    *   Check retain counts for unexpected increases or objects not being released.
    *   Watch for message handlers being called after they were marked as cleaned up.
3.  **Check the crash breadcrumbs file** for the last few operations before the crash.

### Potential Issues Investigated
- **Retain Cycles**: Was `ConsoleMessageHandler` being retained by WebKit?
- **Timing Issues**: Were delegates being called asynchronously after cleanup had started?
- **Multiple References**: Was the same handler being used for multiple message types?
- **Process Boundary Issues**: Callbacks might come from the `WebContent` process after the main app process had started its cleanup.

---

## Part 2: The First Fix Attempt (NSWindowDelegate)

The initial investigation led to a solution based on Apple's recommended pattern: clean up WebKit resources *before* AppKit begins its own deallocation process.

### The Solution
The `OverlayController` was made to conform to `NSWindowDelegate` and implement the `windowWillClose(_:)` method. This method is called before AppKit starts tearing down the window, providing a safe point to perform cleanup.

#### Key Changes
1.  **`NSWindowDelegate` Pattern**: `OverlayController` implemented `windowWillClose(_:)` and was set as the window's delegate.
2.  **Script Message Handler Removal**: All script message handlers were explicitly removed from the `WKUserContentController` inside `windowWillClose`.
3.  **Centralized Handler Names**: A `ServiceManager.scriptMessageHandlerNames` array was created as a single source of truth to ensure all handlers were removed.
4.  **Proper Cleanup Sequence**:
    ```swift
    func windowWillClose(_ notification: Notification) {
        // 1. Remove script message handlers FIRST
        for handlerName in ServiceManager.scriptMessageHandlerNames {
            controller.removeScriptMessageHandler(forName: handlerName)
        }
        
        // 2. Stop loading and clear delegates
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        
        // 3. Remove from view hierarchy
        webView.removeFromSuperview()
    }
    ```

### Why This (Partially) Worked
- `windowWillClose` fires before AppKit starts deallocating objects, preventing a race condition.
- All WebKit references were cleaned up while the objects were still in a valid state.

However, this solution was not completely robust and crashes still occurred intermittently.

---

## Part 3: The Definitive Fix (January 2025)

Further investigation revealed a more fundamental issue with the window's lifecycle management.

### The True Root Cause
The primary cause of the crashes was a property on `NSWindow` itself: `isReleasedWhenClosed`. By default, this is `true`, meaning AppKit would deallocate the window object immediately upon being closed, which doesn't align well with modern Automatic Reference Counting (ARC). This was the race condition that the previous fix couldn't fully solve.

### The Solution Implemented

#### 1. Fixed Window Lifecycle (Primary Fix)
In `OverlayController.swift`, the window creation was changed to prevent it from being deallocated on close, allowing ARC to manage its lifetime correctly.

```swift
// In OverlayController.createNormalWindow()
// CRITICAL: Prevent the window from deallocating itself on close.
// This aligns window behavior with ARC and prevents EXC_BAD_ACCESS crashes.
window.isReleasedWhenClosed = false
```

#### 2. Enhanced WebView Cleanup Protocol
The `windowWillClose` logic was enhanced to be even more robust, implementing Apple's full recommended teardown sequence:
- Stop all activity with `webView.stopLoading()`.
- Terminate any running JavaScript by loading a blank page: `webView.loadHTMLString("", baseURL: nil)`.
- Remove all script message handlers.
- Nil out all delegates (`navigationDelegate`, `uiDelegate`).
- Remove the `WKWebView` from its superview.
- Clear all website data for hygiene using `WKWebsiteDataStore.default().removeData(...)`.
- Wrap the cleanup in an `autoreleasepool` to encourage immediate resource release.

#### 3. Added Defensive Checks
`isCleaningUp` guards were added to all `WKNavigationDelegate` and `WKUIDelegate` methods in `ServiceManager` to prevent any stray asynchronous callbacks from executing during the teardown process. `defer` was used to ensure completion handlers were always called.

### Testing and Verification
1.  Run the app.
2.  Open multiple windows with WebViews.
3.  Close windows by clicking the 'X' button.
4.  Verified that no `EXC_BAD_ACCESS` crashes occurred.
5.  Console logs showed a clean and orderly cleanup sequence.

### References
This final solution was based on a guide titled "Diagnosing and Resolving EXC_BAD_ACCESS Crashes with Multiple WKWebViews on macOS," which identifies `isReleasedWhenClosed = true` as the primary cause of these crashes in modern ARC-based applications. 