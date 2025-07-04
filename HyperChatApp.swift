import SwiftUI
import AppKit

@main
struct HyperchatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var loggingSettings = LoggingSettings.shared

    var body: some Scene {
        // Use Settings scene instead of WindowGroup to prevent default window
        // This allows us to keep SwiftUI menu commands without creating a visible window
        Settings {
            EmptyView()
        }
    }
} 