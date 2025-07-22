/// HyperchatApp.swift - SwiftUI App Entry Point
///
/// This file defines the main SwiftUI app structure. It uses AppDelegate for
/// traditional AppKit integration while maintaining SwiftUI's modern app lifecycle.
///
/// Key responsibilities:
/// - Declares @main entry point for the application
/// - Bridges to AppDelegate for window management
/// - Provides Settings scene for menu commands
/// - Avoids creating default SwiftUI window
/// - Holds reference to logging settings
///
/// Related files:
/// - `AppDelegate.swift`: Handles actual app lifecycle and window creation
/// - `LoggingSettings.swift`: Provides observable logging configuration
///
/// Architecture:
/// - SwiftUI App protocol for modern lifecycle
/// - NSApplicationDelegateAdaptor for AppKit bridge
/// - Settings scene prevents unwanted window creation

import SwiftUI
import AppKit

/// Main SwiftUI app structure.
///
/// Design decisions:
/// - Uses Settings scene instead of WindowGroup
/// - This prevents SwiftUI from creating a default window
/// - Allows AppDelegate to manage all windows
/// - Maintains SwiftUI menu commands functionality
///
/// The @main attribute marks this as the app entry point.
@main
struct HyperchatApp: App {
    /// Bridge to traditional AppKit app delegate
    /// AppDelegate handles all window creation and management
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    /// Observable logging settings for potential future UI
    /// Currently unused but available for SwiftUI views
    @StateObject private var loggingSettings = LoggingSettings.shared

    var body: some Scene {
        // Use Settings scene to prevent automatic window creation
        // This is the idiomatic way to handle macOS apps that manage their own windows
        Settings {
            SettingsView()
        }
    }
}