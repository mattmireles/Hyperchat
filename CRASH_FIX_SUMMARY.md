# EXC_BAD_ACCESS Crash Fix Summary

## The Problem
- WKWebView runs JavaScript in a separate WebContent process
- Script message handlers (ConsoleMessageHandler) were strongly retained by WKUserContentController
- When closing windows, WebKit's async IPC would try to deliver messages to partially-deallocated handlers
- This caused EXC_BAD_ACCESS crashes in objc_msgSend

## The Solution
Implemented Apple's recommended pattern: Clean up WebKit before deallocation begins.

### Key Changes:

1. **NSWindowDelegate Pattern**
   - OverlayController now conforms to NSWindowDelegate
   - Implements `windowWillClose(_:)` to clean up BEFORE window teardown
   - Set as delegate when creating windows

2. **Script Message Handler Removal**
   - Remove ALL message handlers in windowWillClose
   - This prevents async callbacks to freed memory
   - Used centralized handler names array for consistency

3. **Proper Cleanup Sequence**
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

4. **Centralized Handler Names**
   - Added `ServiceManager.scriptMessageHandlerNames` array
   - Single source of truth for handler names
   - Easy to add new handlers without missing removal

5. **Floating Button Fix**
   - Reuse existing window instead of creating duplicates
   - Update position if screen geometry changed

## Why This Works
- windowWillClose fires BEFORE AppKit starts deallocating
- All WebKit references are cleaned up while objects are valid
- No async callbacks can arrive after deallocation begins
- Matches Apple's recommended cleanup pattern

## Testing
1. Open multiple windows with WebViews
2. Close windows by clicking X button
3. No more EXC_BAD_ACCESS crashes
4. Console shows clean handler removal in windowWillClose