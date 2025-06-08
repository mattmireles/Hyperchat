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

    override func cancelOperation(_ sender: Any?) {
        overlayController?.hideOverlay()
    }
}

class OverlayController {
    private var overlayWindow: OverlayWindow?
    private var serviceManager: ServiceManager?
    private var escMonitor: Any?
    private var isHiding = false

    // Public entry point when no prompt yet
    func showOverlay() {
        showOverlay(with: nil)
    }

    // New unified API – always rebuild fresh overlay
    func showOverlay(with prompt: String?) {
        // Ensure any previous overlay is gone
        hideOverlay()

        // Fresh service manager each time to avoid lingering WK processes
        let manager = ServiceManager()
        self.serviceManager = manager

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

        // Layer 3: The browser views with controls.
        let sortedServices = manager.activeServices.sorted { $0.order < $1.order }
        let browserViews = sortedServices.compactMap { service in
            manager.webServices[service.id]?.browserView
        }
        
        let stackView = NSStackView(views: browserViews)
        stackView.distribution = .fillEqually
        stackView.orientation = .horizontal
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 40),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -40),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40)
        ])

        window.makeKeyAndOrderFront(nil)

        // Install ESC monitor to catch even when WKWebView has focus
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] ev in
            if ev.keyCode == 53 && self?.isHiding == false {
                self?.hideOverlay()
                return nil // swallow
            }
            return ev
        }

        // Execute prompt if provided
        if let p = prompt {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                manager.executePrompt(p)
            }
        }
    }

    func hideOverlay() {
        guard !isHiding else { return }
        isHiding = true
        
        // Just hide the window - don't clean up WebViews to avoid hanging
        overlayWindow?.orderOut(nil)
        overlayWindow = nil

        // Remove esc monitor if exists
        if let m = escMonitor {
            NSEvent.removeMonitor(m)
            escMonitor = nil
        }
        
        isHiding = false
        
        // Notify that overlay is hidden
        NotificationCenter.default.post(name: .overlayDidHide, object: nil)
    }
}

extension Notification.Name {
    static let overlayDidHide = Notification.Name("overlayDidHide")
} 