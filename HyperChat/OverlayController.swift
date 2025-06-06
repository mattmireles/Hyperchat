import Cocoa
import SwiftUI

class OverlayController {
    private var overlayWindow: NSWindow?

    func showOverlay() {
        // If the window already exists, just bring it to the front.
        if let overlayWindow = overlayWindow, overlayWindow.isVisible {
            overlayWindow.orderFront(nil)
            return
        }

        guard let mainScreen = NSScreen.main else { return }

        // Create a full-screen, borderless window.
        overlayWindow = NSWindow(
            contentRect: mainScreen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        guard let overlayWindow = overlayWindow else { return }

        overlayWindow.level = .floating
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlayWindow.backgroundColor = .clear
        overlayWindow.isOpaque = false

        // Create a container view that will hold our layers.
        let containerView = NSView(frame: mainScreen.frame)
        overlayWindow.contentView = containerView

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

        overlayWindow.makeKeyAndOrderFront(nil)
    }

    func hideOverlay() {
        overlayWindow?.orderOut(nil)
    }
} 