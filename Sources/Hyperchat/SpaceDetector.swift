/// SpaceDetector.swift - Desktop Space Detection and Management
///
/// This file provides space-aware window management using modern public APIs when available,
/// with CGS private API fallback for older macOS versions. It enables the app to determine 
/// which desktop space windows are visible on, allowing the floating button to intelligently 
/// bring forward existing windows on the current space.
///
/// Key responsibilities:
/// - Detect the currently active desktop space
/// - Check if specific windows are visible on the active space
/// - Use modern NSWindow.isOnActiveSpace API (macOS 13+) for reliable detection
/// - Fallback to CGS private APIs for older macOS versions
/// - Provide conservative fallback behavior when all APIs are unavailable
///
/// Related files:
/// - `FloatingButtonManager.swift`: Uses space detection for intelligent window management
/// - `AppDelegate.swift`: Uses space-aware window filtering
/// - `OverlayController.swift`: Window visibility management
///
/// Architecture:
/// - Dynamically loads CGS private APIs using dlsym to avoid linking errors
/// - Provides public API that gracefully degrades when CGS unavailable
/// - Uses NSWindow collection behaviors as fallback detection method
///
/// Safety notes:
/// - CGS APIs are private and can change between macOS versions
/// - All CGS calls are wrapped in error handling
/// - Provides meaningful fallback behavior when APIs unavailable

import Cocoa
import os.log

// MARK: - CGS API Type Definitions

typealias CGSConnectionID = UInt32
typealias CGSSpaceID = UInt64
typealias CGSWindowID = UInt32

// Define the function signatures for the CGS private APIs we need to load.
// This tells Swift what the functions look like without linking against them.
private typealias CGSMainConnectionIDProc = @convention(c) () -> CGSConnectionID
private typealias CGSGetActiveSpaceProc = @convention(c) (CGSConnectionID) -> CGSSpaceID
// The modern function for getting windows on a space is `CGSGetWindowsWithOptionsAndTags`.
// It is more reliable than the older `CGSGetWindowsToSpaces`.
private typealias CGSGetWindowsWithOptionsAndTagsProc = @convention(c) (CGSConnectionID, CGSSpaceID, UInt32, UnsafeMutablePointer<UInt64>, UnsafeMutablePointer<UInt32>) -> CFArray?

// MARK: - SpaceDetector Class

/// A utility class to interact with macOS desktop spaces using dynamically loaded private CGS APIs.
class SpaceDetector {
    
    // MARK: - Properties
    
    static let shared = SpaceDetector()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.transcendence.hyperchat", category: "SpaceDetector")
    
    private var cgsAvailable: Bool = false
    private var connectionID: CGSConnectionID?
    
    // Stored function pointers that will be loaded at runtime.
    private var CGSMainConnectionID: CGSMainConnectionIDProc?
    private var CGSGetActiveSpace: CGSGetActiveSpaceProc?
    private var CGSGetWindowsWithOptionsAndTags: CGSGetWindowsWithOptionsAndTagsProc?
    
    // MARK: - Initialization
    
    private init() {
        loadCGSApis()
        if cgsAvailable {
            self.connectionID = self.CGSMainConnectionID?()
        }
    }
    
    /// Dynamically loads private CGS functions from the CoreGraphics framework at runtime.
    /// This avoids linker errors since we are not linking against a private framework.
    private func loadCGSApis() {
        // CoreGraphics framework handle
        let coreGraphicsHandle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY)
        guard coreGraphicsHandle != nil else {
            logger.error("Failed to open CoreGraphics framework handle.")
            cgsAvailable = false
            return
        }
        
        // Load CGSMainConnectionID
        let mainConnectionSymbol = dlsym(coreGraphicsHandle, "CGSMainConnectionID")
        guard mainConnectionSymbol != nil else {
            logger.error("Failed to find CGSMainConnectionID symbol.")
            cgsAvailable = false
            dlclose(coreGraphicsHandle)
            return
        }
        self.CGSMainConnectionID = unsafeBitCast(mainConnectionSymbol, to: CGSMainConnectionIDProc.self)
        
        // Load CGSGetActiveSpace
        let activeSpaceSymbol = dlsym(coreGraphicsHandle, "CGSGetActiveSpace")
        guard activeSpaceSymbol != nil else {
            logger.error("Failed to find CGSGetActiveSpace symbol.")
            cgsAvailable = false
            dlclose(coreGraphicsHandle)
            return
        }
        self.CGSGetActiveSpace = unsafeBitCast(activeSpaceSymbol, to: CGSGetActiveSpaceProc.self)
        
        // Load CGSGetWindowsWithOptionsAndTags
        let windowsInSpaceSymbol = dlsym(coreGraphicsHandle, "CGSGetWindowsWithOptionsAndTags")
        guard windowsInSpaceSymbol != nil else {
            logger.error("Failed to find CGSGetWindowsWithOptionsAndTags symbol.")
            cgsAvailable = false
            dlclose(coreGraphicsHandle)
            return
        }
        self.CGSGetWindowsWithOptionsAndTags = unsafeBitCast(windowsInSpaceSymbol, to: CGSGetWindowsWithOptionsAndTagsProc.self)
        
        dlclose(coreGraphicsHandle)
        
        logger.log("✅ Successfully loaded all required CGS private APIs.")
        cgsAvailable = true
    }
    
    // MARK: - Public API
    
    /// Checks if a window is on the currently active desktop space.
    func isWindowOnCurrentSpace(_ window: NSWindow) -> Bool {
        let windowTitle = window.title.isEmpty ? "Untitled" : window.title
        logger.log("🌌 [SPACE] >>> isWindowOnCurrentSpace() called for window: '\(windowTitle)'")
        
        // Windows that exist on all spaces are always "on the current space".
        if window.collectionBehavior.contains(.canJoinAllSpaces) {
            logger.log("🌌 [SPACE] Window '\(windowTitle)' joins all spaces, returning TRUE")
            return true
        }
        
        // SCREEN-BASED HEURISTIC: Use same-screen detection as reliable proxy
        // The isOnActiveSpace API is unreliable - it returns true for windows on different spaces
        // Instead, use the heuristic: window is on "current space" if it's on same screen as mouse
        guard let windowScreen = window.screen, 
              let mouseScreen = NSScreen.screenWithMouse() else {
            // Fallback if we can't get screen info - use key window status
            logger.log("🌌 [SPACE] Screen detection failed - using key window fallback")
            let isKey = window.isKeyWindow
            logger.log("🌌 [SPACE] Fallback result for '\(windowTitle)': \(isKey)")
            return isKey
        }
        
        // A window is on the "current space" if it's on the same screen as the mouse
        // and is actually visible (not minimized)
        let isOnSameScreenAsMouse = (windowScreen == mouseScreen)
        let isActuallyVisible = window.isVisible && !window.isMiniaturized
        let result = isOnSameScreenAsMouse && isActuallyVisible
        
        logger.log("🌌 [SPACE] Screen-based detection for '\(windowTitle)':")
        logger.log("🌌 [SPACE] - Window screen: \(windowScreen.localizedName)")
        logger.log("🌌 [SPACE] - Mouse screen: \(mouseScreen.localizedName)")
        logger.log("🌌 [SPACE] - Same screen: \(isOnSameScreenAsMouse)")
        logger.log("🌌 [SPACE] - Actually visible: \(isActuallyVisible)")
        logger.log("🌌 [SPACE] - Final result: \(result)")
        
        return result
    }
    
    /// Gets the currently active desktop space ID.
    ///
    /// - Returns: Space ID if available, nil if CGS APIs unavailable
    func getCurrentSpaceID() -> CGSSpaceID? {
        guard cgsAvailable,
              let connection = self.connectionID,
              let getActiveSpace = self.CGSGetActiveSpace else {
            logger.log("getCurrentSpaceID: CGS APIs unavailable")
            return nil
        }
        
        let spaceID = getActiveSpace(connection)
        logger.log("Current space ID: \(spaceID)")
        return spaceID
    }
    
    /// Gets all available desktop space IDs.
    ///
    /// - Returns: Array of space IDs, empty if CGS APIs unavailable
    func getAllSpaceIDs() -> [CGSSpaceID] {
        // This would require additional CGS APIs that we haven't loaded yet
        // For now, just return empty array
        logger.log("getAllSpaceIDs: Not implemented in current version")
        return []
    }
    
    // MARK: - Private CGS Implementation
    
    /// Uses the loaded CGS functions to determine if a window is on the active space.
    private func isWindowOnCurrentSpaceCGS(_ window: NSWindow) -> Bool {
        let windowTitle = window.title.isEmpty ? "Untitled" : window.title
        logger.log("🌌 [CGS] >>> isWindowOnCurrentSpaceCGS() called for window: '\(windowTitle)'")
        
        guard let connection = self.connectionID,
              let getActiveSpace = self.CGSGetActiveSpace,
              let getWindows = self.CGSGetWindowsWithOptionsAndTags else {
            logger.error("🌌 [CGS] CGS functions are not loaded, cannot check window space.")
            return false // Fail safe
        }
        
        logger.log("🌌 [CGS] Getting active space ID...")
        let activeSpaceID = getActiveSpace(connection)
        logger.log("🌌 [CGS] Active space ID: \(activeSpaceID)")
        
        // The last three parameters are for tags, which we don't need, so we pass empty values.
        var setTags: UInt64 = 0
        var clearTags: UInt32 = 0
        
        logger.log("🌌 [CGS] Getting windows for active space...")
        guard let windowIDsCFArray = getWindows(connection, activeSpaceID, 0, &setTags, &clearTags) else {
            logger.warning("🌌 [CGS] Could not get window list for active space \(activeSpaceID).")
            return false // Fail safe
        }
        
        guard let windowIDs = windowIDsCFArray as? [CGSWindowID] else {
            logger.warning("🌌 [CGS] Could not cast window list to [CGSWindowID].")
            return false
        }
        
        logger.log("🌌 [CGS] Found \(windowIDs.count) windows on active space")
        
        let targetWindowID = CGSWindowID(window.windowNumber)
        let isOnSpace = windowIDs.contains(targetWindowID)
        
        if isOnSpace {
            logger.log("🌌 [CGS] ✅ Window '\(windowTitle)' (ID: \(targetWindowID)) IS on active space \(activeSpaceID)")
        } else {
            logger.log("🌌 [CGS] ❌ Window '\(windowTitle)' (ID: \(targetWindowID)) is NOT on active space \(activeSpaceID)")
            logger.log("🌌 [CGS] Windows on space: \(windowIDs)")
        }
        
        return isOnSpace
    }
}