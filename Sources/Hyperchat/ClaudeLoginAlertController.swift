/// ClaudeLoginAlertController.swift - Claude Login Alert Window
///
/// This file contains a simple alert-style window for Claude login that appears
/// when users try to enable Claude from the AI Services menu.
///
/// Key responsibilities:
/// - Display chromeless window styled like settings window
/// - Show special instructions for Claude login
/// - Provide WebView for Claude login
/// - Enable Claude service after successful login
/// - Allow user to close/cancel at any time
///
/// Related files:
/// - `AppDelegate.swift`: Shows this window when Claude is enabled
/// - `SettingsWindowController.swift`: Uses similar window styling
/// - `ClaudeLoginView.swift`: The old onboarding version (kept for reference)
///
/// Usage:
/// - Shown when user clicks to enable Claude in AI Services menu
/// - Always shown (no login status checking)
/// - Closes after successful login or user cancellation

import Cocoa
import SwiftUI
import WebKit

/// Window controller for the Claude login alert.
///
/// Created by:
/// - `AppDelegate.toggleAIService()` when user enables Claude
///
/// Creates:
/// - Chromeless modal window styled like settings
/// - SwiftUI-based ClaudeLoginAlertView as content
/// - Proper window styling and behavior
///
/// Window behavior:
/// - Floating level to appear above other windows
/// - Centered on screen
/// - Closes automatically when user completes or cancels
class ClaudeLoginAlertController: NSWindowController {
    
    /// Initialize the Claude login alert window
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        setupWindow()
        setupContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Configure the window appearance and behavior to match settings window
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "Claude Setup"
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor.clear
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        
        // Make it modal-like (appears above other windows)
        window.level = .modalPanel
        
        // Ensure it appears on the current space
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    
    /// Set up the SwiftUI content view
    private func setupContent() {
        guard let window = window else { return }
        
        // Create the SwiftUI view with callback to handle completion
        let claudeLoginView = ClaudeLoginAlertView(
            onComplete: { [weak self] in
                self?.handleLoginComplete()
            },
            onCancel: { [weak self] in
                self?.handleLoginCancel()
            }
        )
        
        // Create container view to hold both background and content
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        containerView.autoresizingMask = [.width, .height]
        
        // Add visual effect background to match settings window
        let backgroundEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        backgroundEffectView.material = .hudWindow
        backgroundEffectView.blendingMode = .behindWindow
        backgroundEffectView.state = .active
        backgroundEffectView.autoresizingMask = [.width, .height]
        
        // Create hosting view for SwiftUI content
        let hostingView = NSHostingView(rootView: claudeLoginView)
        
        containerView.addSubview(backgroundEffectView)
        containerView.addSubview(hostingView)
        
        // Set content view constraints
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        window.contentView = containerView
    }
    
    /// Handle successful login completion
    private func handleLoginComplete() {
        print("✅ Claude login completed successfully")
        
        // Enable Claude service
        enableClaudeService()
        
        // Close the window
        close()
    }
    
    /// Enable Claude service after successful login
    private func enableClaudeService() {
        var services = SettingsManager.shared.getServices()
        if let index = services.firstIndex(where: { $0.id == "claude" }) {
            services[index].enabled = true
            SettingsManager.shared.saveServices(services)
            print("✅ Claude service enabled after successful login")
            
            // Post notification to update ServiceManager
            NotificationCenter.default.post(name: .servicesUpdated, object: nil)
        }
    }
    
    /// Handle cancellation of login
    private func handleLoginCancel() {
        print("❌ Claude login cancelled by user")
        
        // Just close the window - don't enable Claude
        close()
    }
    
    /// Override showWindow to ensure proper display
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// Override close to clean up properly
    override func close() {
        super.close()
        
        // Notify AppDelegate that this window is closing
        NotificationCenter.default.post(name: .claudeLoginAlertClosed, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let claudeLoginAlertClosed = Notification.Name("claudeLoginAlertClosed")
}