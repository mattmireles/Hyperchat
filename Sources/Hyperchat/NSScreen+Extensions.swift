/// NSScreen+Extensions.swift - Screen Utility Extensions
///
/// This file extends NSScreen with utility methods for multi-monitor support,
/// specifically finding which screen contains the mouse cursor.
///
/// Key responsibilities:
/// - Determines active screen based on mouse position
/// - Supports multi-monitor configurations
/// - Handles screen coordinate system correctly
///
/// Related files:
/// - `FloatingButtonManager.swift`: Uses to position button on active screen
/// - `PromptWindowController.swift`: Uses to show prompt on correct screen
/// - `OverlayController.swift`: May use for window positioning
///
/// Architecture:
/// - Static extension method (no instances)
/// - Uses NSEvent for global mouse position
/// - Iterates screens to find containment

import Cocoa

extension NSScreen {
    /// Finds the screen containing the mouse cursor.
    ///
    /// Called by:
    /// - `FloatingButtonManager.checkAndUpdateScreenIfNeeded()` for button positioning
    /// - `FloatingButtonManager.floatingButtonClicked()` to show prompt on correct screen
    ///
    /// Process:
    /// 1. Gets current mouse location in screen coordinates
    /// 2. Checks each screen's frame for containment
    /// 3. Returns first matching screen or nil
    ///
    /// Note: NSMouseInRect uses flipped coordinates (false parameter)
    /// to match NSScreen's coordinate system where origin is bottom-left.
    ///
    /// - Returns: The screen containing the mouse, or nil if mouse is outside all screens
    static func screenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }
} 