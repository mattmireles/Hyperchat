/// ClaudeLoginAlertController.swift - Claude Setup Info Window
///
/// This file contains a simple informational window that appears when users
/// enable Claude from the AI Services menu.
///
/// Key responsibilities:
/// - Display simple informational message about Claude
/// - Styled like settings window for consistency
/// - Allow user to close at any time
///
/// Related files:
/// - `AppDelegate.swift`: Shows this window when Claude is enabled
/// - `SettingsWindowController.swift`: Uses similar window styling
///
/// Usage:
/// - Shown when user clicks to enable Claude in AI Services menu
/// - Simple informational popup - Claude works like other services
/// - User can close immediately and use Claude in main window

import Cocoa
import SwiftUI

/// Window controller for the Claude setup info window.
///
/// Created by:
/// - `AppDelegate.toggleAIService()` when user enables Claude
///
/// Creates:
/// - Simple window styled like settings
/// - SwiftUI-based informational content
/// - Standard window behavior
///
/// Window behavior:
/// - Floating level to appear above other windows
/// - Centered on screen
/// - User can close when ready
class ClaudeLoginAlertController: NSWindowController {
    
    /// Initialize the Claude setup info window
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
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
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        
        // Make it modal-like (appears above other windows)
        window.level = .modalPanel
        
        // Ensure it appears on the current space
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    
    /// Set up the SwiftUI content view
    private func setupContent() {
        guard let window = window else { return }
        
        // Create simple informational SwiftUI view
        let claudeInfoView = ClaudeInfoView()
        
        // Create container view to hold both background and content
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        containerView.autoresizingMask = [.width, .height]
        
        // Add visual effect background to match settings window
        let backgroundEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        backgroundEffectView.material = .hudWindow
        backgroundEffectView.blendingMode = .behindWindow
        backgroundEffectView.state = .active
        backgroundEffectView.autoresizingMask = [.width, .height]
        
        // Create hosting view for SwiftUI content
        let hostingView = NSHostingView(rootView: claudeInfoView)
        
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

// MARK: - Claude Info View

/// Simple informational SwiftUI view for Claude setup.
///
/// Displays basic information that Claude works like other services
/// and the user can log in normally in the main window.
struct ClaudeInfoView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Special Instructions: Claude Login")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Info message
            Text("When you login to Claude using your email, it will send you a confirmation email. DO NOT CLICK THE LINK IN THE EMAIL. Instead, right-click on the button the email, select \"Copy URL\" and paste the URL into the URL bar above the Claude window. \n It's a little wonky. Sorry about that.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
    }
}