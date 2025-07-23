/// HyperchatApp.swift - SwiftUI App Entry Point
///
/// This file defines the main SwiftUI app structure. It uses AppDelegate for
/// traditional AppKit integration while maintaining SwiftUI's modern app lifecycle.
///
/// Key responsibilities:
/// - Declares @main entry point for the application
/// - Bridges to AppDelegate for window management
/// - Creates WindowGroup for standard app behavior (dock icon, app switcher)
/// - AppDelegate closes initial window immediately to maintain control
/// - Enables manual settings window management
///
/// Related files:
/// - `AppDelegate.swift`: Handles actual app lifecycle and window creation
/// - `SettingsWindowController.swift`: Manual settings window management
/// - `LoggingSettings.swift`: Provides observable logging configuration
///
/// Architecture:
/// - SwiftUI App protocol for modern lifecycle
/// - NSApplicationDelegateAdaptor for AppKit bridge
/// - WindowGroup + close-on-launch pattern for hybrid control
/// - Manual settings window to avoid SwiftUI Settings scene corruption

import SwiftUI
import AppKit

/// Main SwiftUI app structure.
///
/// Design decisions:
/// - Uses WindowGroup with EmptyView for normal app behavior
/// - AppDelegate immediately closes the EmptyView window via async deferral
/// - Manual settings window management prevents SwiftUI Settings scene corruption
/// - Maintains full AppDelegate control over all windows
/// - Enables dock icon and app switcher integration
///
/// The @main attribute marks this as the app entry point.
@main
struct HyperchatApp: App {
    /// Bridge to traditional AppKit app delegate
    /// AppDelegate handles all window creation and management
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Use Settings scene as headless placeholder for LSUIElement app.
        // With LSUIElement=YES in Info.plist, this prevents the blank window issue
        // while giving AppDelegate full control over window creation.
        Settings {
            EmptyView()
        }
    }
}