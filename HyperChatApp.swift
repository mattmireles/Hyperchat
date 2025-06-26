import SwiftUI
import AppKit

@main
struct HyperchatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var loggingSettings = LoggingSettings.shared

    var body: some Scene {
        // No scenes needed - we're managing everything through AppDelegate
        // This prevents SwiftUI from interfering with our custom menu bar
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .commands {
            // Remove all default SwiftUI commands to prevent menu interference
            CommandGroup(replacing: .appInfo) { }
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .pasteboard) { }
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .systemServices) { }
            CommandGroup(replacing: .textEditing) { }
            CommandGroup(replacing: .windowSize) { }
            CommandGroup(replacing: .help) { }
            
            // Add our custom Logs menu
            CommandMenu("Logs") {
                // Preset options
                Button("Minimal Logging") {
                    loggingSettings.setMinimalLogging()
                    WebViewLogger.shared.log("Switched to minimal logging", for: "system", type: .info)
                }
                Button("Debug Reply-to-All") {
                    loggingSettings.setDebugReplyToAll()
                    WebViewLogger.shared.log("Switched to debug reply-to-all logging", for: "system", type: .info)
                }
                Button("Verbose Logging") {
                    loggingSettings.setVerboseLogging()
                    WebViewLogger.shared.log("Switched to verbose logging", for: "system", type: .info)
                }
                
                Divider()
                
                // Individual toggles
                Toggle("Network Requests", isOn: $loggingSettings.networkRequests)
                    .onChange(of: loggingSettings.networkRequests) { newValue in
                        WebViewLogger.shared.log("Network logging: \(newValue ? "enabled" : "disabled")", for: "system", type: .info)
                    }
                Toggle("User Interactions", isOn: $loggingSettings.userInteractions)
                    .onChange(of: loggingSettings.userInteractions) { newValue in
                        WebViewLogger.shared.log("User interaction logging: \(newValue ? "enabled" : "disabled")", for: "system", type: .info)
                    }
                Toggle("Console Messages", isOn: $loggingSettings.consoleMessages)
                    .onChange(of: loggingSettings.consoleMessages) { newValue in
                        WebViewLogger.shared.log("Console message logging: \(newValue ? "enabled" : "disabled")", for: "system", type: .info)
                    }
                Toggle("DOM Changes", isOn: $loggingSettings.domChanges)
                    .onChange(of: loggingSettings.domChanges) { newValue in
                        WebViewLogger.shared.log("DOM changes logging: \(newValue ? "enabled" : "disabled")", for: "system", type: .info)
                    }
                Toggle("Navigation Events", isOn: $loggingSettings.navigation)
                    .onChange(of: loggingSettings.navigation) { newValue in
                        WebViewLogger.shared.log("Navigation logging: \(newValue ? "enabled" : "disabled")", for: "system", type: .info)
                    }
                Toggle("Prompt Debugging", isOn: $loggingSettings.debugPrompts)
                    .onChange(of: loggingSettings.debugPrompts) { newValue in
                        WebViewLogger.shared.log("Prompt debugging: \(newValue ? "enabled" : "disabled")", for: "system", type: .info)
                    }
                Toggle("Filter Analytics", isOn: $loggingSettings.analyticsFilter)
                    .onChange(of: loggingSettings.analyticsFilter) { newValue in
                        WebViewLogger.shared.log("Analytics filtering: \(newValue ? "enabled" : "disabled")", for: "system", type: .info)
                    }
            }
        }
    }
} 