import Cocoa
import SwiftUI
import os.log

// Custom panel that can receive clicks but won't become key
class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override var acceptsFirstResponder: Bool { true }  // Changed to true to accept mouse events properly
    
    override func makeKey() {
        // Ignore all attempts to make this key window
    }
    
    override func makeKeyAndOrderFront(_ sender: Any?) {
        // Just order front, don't make key
        self.orderFront(sender)
    }
}

// Custom button that can be dragged
class DraggableButton: NSButton {
    private var initialLocation: NSPoint?
    private let dragCallback: () -> Void
    
    init(frame: NSRect, dragCallback: @escaping () -> Void) {
        self.dragCallback = dragCallback
        super.init(frame: frame)
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true  // Always accept first mouse click
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        initialLocation = event.locationInWindow
        // Make the window accept mouse events
        self.window?.makeFirstResponder(self)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window,
              let initialLocation = initialLocation else { return }
        
        let currentLocation = event.locationInWindow
        let windowFrame = window.frame
        
        let newOrigin = NSPoint(
            x: windowFrame.origin.x + (currentLocation.x - initialLocation.x),
            y: windowFrame.origin.y + (currentLocation.y - initialLocation.y)
        )
        
        window.setFrameOrigin(newOrigin)
    }
    
    override func mouseUp(with event: NSEvent) {
        if let initialLocation = initialLocation, initialLocation == event.locationInWindow {
            // This was a click, not a drag.
            if let action = self.action {
                _ = self.target?.perform(action, with: self)
            }
        } else {
            // This was a drag.
            dragCallback()
        }
        self.initialLocation = nil
    }
}

class FloatingButtonManager {
    private var buttonWindow: NSWindow?
    var promptWindowController: PromptWindowController?
    var overlayController: OverlayController?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.transcendence.hyperchat", category: "FloatingButtonManager")
    private var screenUpdateTimer: Timer?
    private var lastKnownScreen: NSScreen?
    private let positionsKey = "HyperChatButtonPositions"
    private var visibilityTimer: Timer?

    deinit {
        screenUpdateTimer?.invalidate()
        visibilityTimer?.invalidate()
    }

    func showFloatingButton() {
        logger.log("👇 showFloatingButton called.")
        
        let buttonSize: CGFloat = 48
        let buttonFrame = NSRect(x: 0, y: 0, width: buttonSize, height: buttonSize)

        let window = FloatingPanel(
            contentRect: buttonFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.collectionBehavior = .canJoinAllSpaces
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = false // Disable this since we're handling dragging ourselves
        window.hidesOnDeactivate = false // Important: don't hide when app loses focus
        self.buttonWindow = window

        let button = DraggableButton(frame: NSRect(origin: .zero, size: CGSize(width: buttonSize, height: buttonSize))) { [weak self] in
            self?.saveCurrentPosition()
        }
        button.image = NSImage(named: "HyperChatIcon")
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.cornerRadius = buttonSize / 2
        
        button.target = self
        button.action = #selector(floatingButtonClicked)

        window.contentView = button
        
        updateButtonPosition()
        
        window.makeKeyAndOrderFront(nil)
        
        // Start timer to follow mouse across screens
        screenUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkAndUpdateScreenIfNeeded()
        }

        // Start timer to ensure button stays visible
        visibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            if let window = self?.buttonWindow, !window.isVisible {
                window.orderFront(nil)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let w = self.buttonWindow, w.isVisible {
                self.logger.log("✅ SUCCESS: Floating button window is visible on screen.")
            } else {
                self.logger.error("❌ FAILURE: Floating button window is NOT visible after 1 second.")
            }
        }
    }

    func ensureFloatingButtonVisible() {
        buttonWindow?.orderFront(nil)
    }

    @objc private func floatingButtonClicked() {
        // Don't hide overlay if it's visible - just show prompt window
        // This prevents the hanging issue
        
        // The controller is now persistent and passed in from the AppDelegate.
        // DO NOT re-create it here.
        
        // Use the screen the button is on, or the one with the mouse, or fallback to main.
        let screen = buttonWindow?.screen ?? NSScreen.screenWithMouse() ?? NSScreen.main!
        promptWindowController?.showWindow(on: screen)
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

        // Try to load saved position for this screen
        if let savedPosition = loadPosition(for: screen) {
            logger.log("Loading saved position for screen: x=\(savedPosition.x), y=\(savedPosition.y)")
            window.setFrameOrigin(savedPosition)
        } else {
            // Default position if no saved position exists
            let padding: CGFloat = 20
            let xPos = screen.visibleFrame.minX + padding
            let yPos = screen.visibleFrame.minY + padding
            
            logger.log("Using default position: x=\(xPos), y=\(yPos)")
            
            window.setFrameOrigin(NSPoint(x: xPos, y: yPos))
        }
    }
    
    private func saveCurrentPosition() {
        guard let window = buttonWindow,
              let screen = lastKnownScreen else { return }
        
        let position = window.frame.origin
        savePosition(position, for: screen)
        logger.log("Saved position for screen: x=\(position.x), y=\(position.y)")
    }
    
    private func screenIdentifier(for screen: NSScreen) -> String {
        // Create a unique identifier for the screen based on its frame
        // This handles the case where screen IDs might change between launches
        let frame = screen.frame
        return "\(Int(frame.origin.x)),\(Int(frame.origin.y)),\(Int(frame.size.width)),\(Int(frame.size.height))"
    }
    
    private func savePosition(_ position: NSPoint, for screen: NSScreen) {
        var positions = UserDefaults.standard.dictionary(forKey: positionsKey) ?? [:]
        let screenId = screenIdentifier(for: screen)
        positions[screenId] = ["x": position.x, "y": position.y]
        UserDefaults.standard.set(positions, forKey: positionsKey)
    }
    
    private func loadPosition(for screen: NSScreen) -> NSPoint? {
        guard let positions = UserDefaults.standard.dictionary(forKey: positionsKey),
              let screenData = positions[screenIdentifier(for: screen)] as? [String: Double],
              let x = screenData["x"],
              let y = screenData["y"] else {
            return nil
        }
        return NSPoint(x: x, y: y)
    }
} 