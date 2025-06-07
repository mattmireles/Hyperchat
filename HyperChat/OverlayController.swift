import Cocoa
import SwiftUI

class OverlayWindow: NSWindow {
    weak var overlayController: OverlayController?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            overlayController?.hideOverlay()
        } else {
            super.keyDown(with: event)
        }
    }
}

class OverlayController {
    private var overlayWindow: OverlayWindow?
    private let serviceManager = ServiceManager()

    func showOverlay() {
        // If the window already exists, just bring it to the front.
        if let overlayWindow = overlayWindow, overlayWindow.isVisible {
            overlayWindow.orderFront(nil)
            return
        }

        guard let mainScreen = NSScreen.main else { return }

        // Create a full-screen, borderless window.
        let window = OverlayWindow(
            contentRect: mainScreen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.overlayController = self
        overlayWindow = window

        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.isOpaque = false

        // Create a container view that will hold our layers.
        let containerView = NSView(frame: mainScreen.frame)
        window.contentView = containerView

        // Layer 1: The blur effect using the .hudWindow material.
        let blurView = NSVisualEffectView(frame: containerView.bounds)
        blurView.material = .hudWindow
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.autoresizingMask = [.width, .height]
        containerView.addSubview(blurView)

        // Layer 2: A subtle black tint on top of the blur.
        let tintView = NSView(frame: containerView.bounds)
        tintView.wantsLayer = true
        tintView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        tintView.autoresizingMask = [.width, .height]
        containerView.addSubview(tintView)

        window.makeKeyAndOrderFront(nil)
    }

    // New method to support prompt
    func showOverlay(with prompt: String) {
        showOverlay()
        serviceManager.executePrompt(prompt)
    }

    func hideOverlay() {
        overlayWindow?.orderOut(nil)
    }
} 