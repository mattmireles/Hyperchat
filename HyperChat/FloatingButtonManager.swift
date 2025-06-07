import Cocoa
import SwiftUI
import os.log

class FloatingButtonManager {
    private var buttonWindow: NSWindow?
    var promptWindowController: PromptWindowController?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.transcendence.hyperchat", category: "FloatingButtonManager")

    func showFloatingButton() {
        logger.log("👇 showFloatingButton called.")
        guard let mainScreen = NSScreen.main else {
            logger.error("❌ Could not find main screen.")
            return
        }

        let buttonSize: CGFloat = 48
        let padding: CGFloat = 20
        let xPos = mainScreen.visibleFrame.minX + padding
        let yPos = mainScreen.visibleFrame.minY + padding
        let buttonFrame = NSRect(x: xPos, y: yPos, width: buttonSize, height: buttonSize)

        let window = NSWindow(
            contentRect: buttonFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true

        let button = NSButton(frame: NSRect(origin: .zero, size: CGSize(width: buttonSize, height: buttonSize)))
        button.image = NSImage(named: "HyperChatIcon")
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.cornerRadius = buttonSize / 2
        
        button.target = self
        button.action = #selector(buttonClicked)

        window.contentView = button
        window.makeKeyAndOrderFront(nil)
        self.buttonWindow = window

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let w = self.buttonWindow, w.isVisible {
                self.logger.log("✅ SUCCESS: Floating button window is visible on screen.")
            } else {
                self.logger.error("❌ FAILURE: Floating button window is NOT visible after 1 second.")
            }
        }
    }

    @objc func buttonClicked() {
        logger.log("🎉 Button clicked! Showing prompt window...")
        promptWindowController?.showWindow(nil)
    }
} 