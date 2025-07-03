# EXC_BAD_ACCESS Crash Fix - January 2025

## Problem
The app was experiencing EXC_BAD_ACCESS crashes when closing windows containing WKWebViews. The crash was caused by:
1. Missing `isReleasedWhenClosed = false` on NSWindow (primary cause)
2. WebKit's async processes trying to access deallocated memory
3. Script message handlers not being properly cleaned up

## Solution Implemented

### 1. Fixed Window Lifecycle (Primary Fix)
Added `window.isReleasedWhenClosed = false` in `OverlayController.swift`:
```swift
// CRITICAL: Prevent the window from deallocating itself on close
// This aligns window behavior with ARC and prevents EXC_BAD_ACCESS crashes
window.isReleasedWhenClosed = false
```

This prevents AppKit from force-deallocating the window on close, letting ARC manage its lifetime properly.

### 2. Enhanced WebView Cleanup Protocol
Improved `windowWillClose` to implement Apple's recommended teardown sequence:
- Stop all activity with `webView.stopLoading()`
- Terminate JavaScript by loading blank page
- Remove script message handlers before deallocation
- Clear delegates to prevent callbacks
- Remove from view hierarchy
- Clear website data for hygiene
- Wrap in autoreleasepool for immediate cleanup

### 3. Added Defensive Checks
Added `isCleaningUp` guards in all WKNavigationDelegate and WKUIDelegate methods to prevent async callbacks during teardown.

## Key Changes

### OverlayController.swift
- Added `import WebKit`
- Set `window.isReleasedWhenClosed = false` in `createNormalWindow()`
- Enhanced `windowWillClose` with comprehensive cleanup protocol
- Added timer and reference cleanup

### ServiceManager.swift
- Added defensive `!isCleaningUp` checks in all delegate methods
- Ensures completion handlers are always called with `defer`

## Testing
To verify the fix:
1. Run the app
2. Open multiple windows with WebViews
3. Close windows by clicking the X button
4. Verify no EXC_BAD_ACCESS crashes occur
5. Check console for proper cleanup logs

## References
Based on Apple's documentation "Diagnosing and Resolving EXC_BAD_ACCESS Crashes with Multiple WKWebViews on macOS" which identifies `isReleasedWhenClosed = true` as the primary cause of these crashes in modern ARC-based apps.