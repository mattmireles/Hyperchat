import Cocoa
import SwiftUI
import os.log

class FloatingButtonManager {
    private var buttonWindow: NSWindow?
    var promptWindowController: PromptWindowController?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.transcendence.hyperchat", category: "FloatingButtonManager")
    private var screenUpdateTimer: Timer?
    private var lastKnownScreen: NSScreen?

    deinit {
        screenUpdateTimer?.invalidate()
    }

    func showFloatingButton() {
        logger.log("👇 showFloatingButton called.")
        
        let buttonSize: CGFloat = 48
        let buttonFrame = NSRect(x: 0, y: 0, width: buttonSize, height: buttonSize)

        let window = NSPanel(
            contentRect: buttonFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.collectionBehavior = .canJoinAllSpaces
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        self.buttonWindow = window

        let button = NSButton(frame: NSRect(origin: .zero, size: CGSize(width: buttonSize, height: buttonSize)))
        button.image = NSImage(named: "HyperChatIcon")
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.cornerRadius = buttonSize / 2
        
        button.target = self
        button.action = #selector(buttonClicked)

        window.contentView = button
        
        updateButtonPosition()
        
        window.makeKeyAndOrderFront(nil)
        
        // Start timer to follow mouse across screens
        screenUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkAndUpdateScreenIfNeeded()
        }

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
    
    private func checkAndUpdateScreenIfNeeded() {
        guard let currentScreen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) else { return }
        
        if currentScreen != lastKnownScreen {
            logger.log("🖱️ Mouse moved to different screen")
            lastKnownScreen = currentScreen
            updateButtonPosition()
        }
    }
    
    private func updateButtonPosition() {
        guard let window = buttonWindow else { return }
        
        let screen: NSScreen
        if let activeScreen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) {
            screen = activeScreen
            lastKnownScreen = activeScreen
        } else {
            screen = NSScreen.main ?? NSScreen.screens.first!
        }

        let buttonSize: CGFloat = 48
        let padding: CGFloat = 20
        let xPos = screen.visibleFrame.minX + padding
        let yPos = screen.visibleFrame.minY + padding
        
        logger.log("Moving button to position: x=\(xPos), y=\(yPos)")
        
        window.setFrameOrigin(NSPoint(x: xPos, y: yPos))
    }
} 