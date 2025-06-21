import SwiftUI
import AppKit

@main
struct HyperchatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // By creating a Settings scene, we get a standard
        // "Settings" menu item and window, which is good practice
        // for macOS apps. We can build out the actual settings UI later.
        Settings {
            VStack {
                Text("Settings")
                    .font(.largeTitle)
                    .padding()
                Spacer()
            }
            .frame(width: 400, height: 200)
        }
    }
} 