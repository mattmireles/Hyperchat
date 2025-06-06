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

        // Add a blur effect to the background.
        let blurView = NSVisualEffectView()
        blurView.material = .underWindowBackground
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        overlayWindow.contentView = blurView

        // We'll add the web views and other content here later.
        // For now, a simple text view to confirm it works.
        let hostingView = NSHostingView(rootView: Text("Overlay Active").font(.largeTitle).foregroundColor(.white))
        hostingView.frame = mainScreen.frame
        blurView.addSubview(hostingView)

        overlayWindow.makeKeyAndOrderFront(nil)
    }

    func hideOverlay() {
        overlayWindow?.orderOut(nil)
    }
} 