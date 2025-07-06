# EXC_BAD_ACCESS Debugging Changes Summary

## Overview
Added comprehensive debugging code to help identify the root cause of EXC_BAD_ACCESS crashes when closing windows.

## Changes Made

### 1. ConsoleMessageHandler (WebViewLogger.swift)
- Added `instanceId` for tracking individual handlers
- Added `messageType` parameter to create separate handlers for each message type
- Added lifecycle logging with timestamps and memory addresses
- Added retain count tracking using `CFGetRetainCount`
- Added `isCleanedUp` flag to detect callbacks after cleanup
- Added `markCleanedUp()` method for proper cleanup sequence

### 2. ServiceManager (ServiceManager.swift)
- Added `instanceId` and `isCleaningUp` flag
- Added lifecycle logging for init/deinit
- Created separate ConsoleMessageHandler instances for each message type
- Added `messageHandlers` dictionary to track handlers for cleanup
- Added cleanup state checking in all WKNavigationDelegate methods
- Added comprehensive cleanup logging in deinit

### 3. OverlayController (OverlayController.swift)
- Added `instanceId` to OverlayWindow and OverlayController
- Added detailed logging throughout window close sequence
- Added memory address and retain count logging for WebViews
- Added timing logs with timestamps for all operations
- Added cleanup state tracking

### 4. BrowserView (ServiceManager.swift)
- Added `instanceId` for tracking
- Added WebView memory address and retain count logging
- Added lifecycle logging for init/deinit

### 5. CrashDebugger (CrashDebugger.swift)
- Created new crash debugging helper
- Logs breadcrumbs to file for post-crash analysis
- Tracks window close, WebView cleanup, handler cleanup, and delegate callbacks

## How to Use the Debug Info

1. **Run the app and reproduce the crash**:
   - Open multiple windows
   - Close a window by clicking the X button
   - Watch the console output

2. **Look for patterns**:
   - Check timestamps to see the exact sequence of events
   - Look for delegate callbacks after cleanup (marked with ⚠️)
   - Check retain counts to identify over-retained objects
   - Look for handlers being called after cleanup

3. **Check the crash breadcrumbs**:
   - Located at: `~/Library/Logs/Hyperchat/crash-breadcrumbs.log`
   - Shows the last operations before crash

4. **Key things to watch for**:
   - ConsoleMessageHandler deinit not being called (retain cycle)
   - Delegate methods called after `isCleaningUp = true`
   - WebView retain counts not decreasing
   - Message handlers receiving messages after cleanup

## Potential Issues to Look For

1. **Retain Cycles**:
   - ConsoleMessageHandler might be retained by WebKit
   - Check if all handlers are being deallocated

2. **Timing Issues**:
   - WebKit might call delegates asynchronously after cleanup
   - Look for callbacks happening after cleanup started

3. **Multiple References**:
   - Same handler added for multiple message types (now fixed)
   - WebViews might be retained by multiple objects

4. **Process Boundary Issues**:
   - WebKit runs in separate processes
   - Callbacks might come from WebContent process after main process cleanup

## Next Steps

After gathering debug information:
1. Identify which objects are not being deallocated
2. Check the exact timing of the crash relative to cleanup operations
3. Look for patterns in retain counts
4. Consider adding more defensive checks based on findings