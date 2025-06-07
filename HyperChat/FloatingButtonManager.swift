import Cocoa
import SwiftUI
import os.log

// Custom button that can be dragged
class DraggableButton: NSButton {
    private var initialLocation: NSPoint?
    private let dragCallback: () -> Void
    
    init(frame: NSRect, dragCallback: @escaping () -> Void) {
        self.dragCallback = dragCallback
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        initialLocation = event.locationInWindow
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
        if initialLocation != nil {
            dragCallback()
            initialLocation = nil
        }
    }
}

class FloatingButtonManager {
    private var buttonWindow: NSWindow?
    var promptWindowController: PromptWindowController?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.transcendence.hyperchat", category: "FloatingButtonManager")
    private var screenUpdateTimer: Timer?
    private var lastKnownScreen: NSScreen?
    private let positionsKey = "HyperChatButtonPositions"

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
        window.isMovableByWindowBackground = false // Disable this since we're handling dragging ourselves
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

        // Try to load saved position for this screen
        if let savedPosition = loadPosition(for: screen) {
            logger.log("Loading saved position for screen: x=\(savedPosition.x), y=\(savedPosition.y)")
            window.setFrameOrigin(savedPosition)
        } else {
            // Default position if no saved position exists
            let buttonSize: CGFloat = 48
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