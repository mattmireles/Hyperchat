import Cocoa
import SwiftUI
import os.log

// SwiftUI view for animated gradient glow
struct FloatingButtonGlow: View {
    @State private var phase: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?
    let isVisible: Bool
    
    var body: some View {
        ZStack {
            // Outer glow layer
            RoundedRectangle(cornerRadius: 20)
                .inset(by: 10)  // Account for 8px padding + icon internal padding
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.0, blue: 0.8),
                            Color(red: 0.0, green: 0.6, blue: 1.0),
                            Color(red: 1.0, green: 0.0, blue: 0.8),
                            Color(red: 0.0, green: 0.6, blue: 1.0),
                            Color(red: 1.0, green: 0.0, blue: 0.8)
                        ]),
                        center: .center,
                        startAngle: .degrees(phase),
                        endAngle: .degrees(phase + 360)
                    ),
                    lineWidth: 4.8
                )
                .blur(radius: 6)
                .opacity(0.4)
            
            // Middle glow layer
            RoundedRectangle(cornerRadius: 20)
                .inset(by: 11)  // Account for 8px padding + icon internal padding
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.0, blue: 0.8),
                            Color(red: 0.0, green: 0.6, blue: 1.0),
                            Color(red: 1.0, green: 0.0, blue: 0.8),
                            Color(red: 0.0, green: 0.6, blue: 1.0),
                            Color(red: 1.0, green: 0.0, blue: 0.8)
                        ]),
                        center: .center,
                        startAngle: .degrees(phase),
                        endAngle: .degrees(phase + 360)
                    ),
                    lineWidth: 3.2
                )
                .blur(radius: 3)
                .opacity(0.6)
            
            // Inner sharp layer
            RoundedRectangle(cornerRadius: 20)
                .inset(by: 12)  // Account for 8px padding + icon internal padding
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.0, blue: 0.8),
                            Color(red: 0.0, green: 0.6, blue: 1.0),
                            Color(red: 1.0, green: 0.0, blue: 0.8),
                            Color(red: 0.0, green: 0.6, blue: 1.0),
                            Color(red: 1.0, green: 0.0, blue: 0.8)
                        ]),
                        center: .center,
                        startAngle: .degrees(phase),
                        endAngle: .degrees(phase + 360)
                    ),
                    lineWidth: 1.2
                )
                .blur(radius: 0.5)
        }
        .opacity(isVisible ? 1 : 0)
        .background(Color.clear)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
        .allowsHitTesting(false)  // Allow mouse events to pass through to button
        .onChange(of: isVisible) { oldValue, newValue in
            if newValue {
                // Start animation when becoming visible
                animationTask = Task {
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                        phase = 360
                    }
                }
            } else {
                // Stop animation when becoming invisible
                animationTask?.cancel()
                animationTask = nil
                // Reset phase without animation
                withAnimation(nil) {
                    phase = 0
                }
            }
        }
    }
}

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

// Custom view that can be dragged and clicked
class DraggableView: NSView {
    private var initialLocation: NSPoint?
    private let dragCallback: () -> Void
    private let clickCallback: () -> Void
    private var trackingArea: NSTrackingArea?
    private var glowHostingView: NSHostingView<FloatingButtonGlow>?
    private var iconView: NSImageView?
    private var isHovering = false
    
    init(frame: NSRect, dragCallback: @escaping () -> Void, clickCallback: @escaping () -> Void) {
        self.dragCallback = dragCallback
        self.clickCallback = clickCallback
        super.init(frame: frame)
        setupView()
        setupTrackingArea()
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true  // Always accept first mouse click
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Add icon as a child view
        let iconSize: CGFloat = 48
        let padding: CGFloat = 8
        iconView = NSImageView(frame: NSRect(x: padding, y: padding, width: iconSize, height: iconSize))
        if let appIcon = NSImage(named: "AppIcon") {
            appIcon.size = NSSize(width: iconSize, height: iconSize)
            iconView?.image = appIcon
        }
        iconView?.imageScaling = .scaleProportionallyUpOrDown
        iconView?.wantsLayer = true
        iconView?.layer?.cornerRadius = 10
        iconView?.layer?.masksToBounds = true
        
        addSubview(iconView!)
        
        // Setup glow view on top
        setupGlowView()
    }
    
    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        setupTrackingArea()
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
        
        // Save position after moving the window
        dragCallback()
    }
    
    override func mouseUp(with event: NSEvent) {
        if let initialLocation = initialLocation {
            let currentLocation = event.locationInWindow
            let dx = currentLocation.x - initialLocation.x
            let dy = currentLocation.y - initialLocation.y
            let distance = sqrt(dx * dx + dy * dy)
            
            // Consider it a click if the mouse moved less than 5 pixels
            let clickThreshold: CGFloat = 5.0
            
            if distance < clickThreshold {
                // This was a click, not a drag.
                clickCallback()
            }
            // Note: dragCallback is now called in mouseDragged to save position during drag
        }
        self.initialLocation = nil
    }
    
    override func mouseEntered(with event: NSEvent) {
        guard !isHovering else { return }
        isHovering = true
        updateGlowVisibility()
    }
    
    override func mouseExited(with event: NSEvent) {
        guard isHovering else { return }
        isHovering = false
        updateGlowVisibility()
    }
    
    private func updateGlowVisibility() {
        // Update the SwiftUI view's visibility state
        if let hostingView = glowHostingView {
            hostingView.rootView = FloatingButtonGlow(isVisible: isHovering)
        }
    }
    
    private func setupGlowView() {
        // Create the SwiftUI glow view
        let glowView = FloatingButtonGlow(isVisible: false)
        let hostingView = NSHostingView(rootView: glowView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Add glow on top of everything
        addSubview(hostingView)
        
        // Make glow fill the entire view
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: self.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        
        glowHostingView = hostingView
    }
}

class FloatingButtonManager {
    private var buttonWindow: NSWindow?
    var promptWindowController: PromptWindowController?
    var overlayController: OverlayController?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.transcendence.hyperchat", category: "FloatingButtonManager")
    private var screenUpdateTimer: Timer?
    private var lastKnownScreen: NSScreen?
    private let positionsKey = "HyperchatButtonPositions"
    private var visibilityTimer: Timer?

    deinit {
        screenUpdateTimer?.invalidate()
        visibilityTimer?.invalidate()
    }

    func showFloatingButton() {
        logger.log("👇 showFloatingButton called.")
        
        // Prevent creating duplicate buttons
        if let existingWindow = buttonWindow {
            logger.log("⚠️ Floating button already exists, bringing to front")
            existingWindow.orderFront(nil)
            
            // Update position in case screen geometry changed
            updateButtonPosition()
            return
        }
        
        let windowSize: CGFloat = 64  // Fixed window size
        let buttonFrame = NSRect(x: 0, y: 0, width: windowSize, height: windowSize)

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

        let contentView = DraggableView(frame: NSRect(x: 0, y: 0, width: windowSize, height: windowSize), 
                                        dragCallback: { [weak self] in
                                            self?.saveCurrentPosition()
                                        },
                                        clickCallback: { [weak self] in
                                            self?.floatingButtonClicked()
                                        })

        window.contentView = contentView
        
        updateButtonPosition()
        
        window.makeKeyAndOrderFront(nil)
        
        // Invalidate any existing timers before creating new ones
        screenUpdateTimer?.invalidate()
        visibilityTimer?.invalidate()
        
        // Start timer to follow mouse across screens
        screenUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkAndUpdateScreenIfNeeded()
        }

        // Start timer to ensure button stays visible
        visibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let window = self.buttonWindow, !window.isVisible {
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
    
    func hideFloatingButton() {
        // Clean up timers
        screenUpdateTimer?.invalidate()
        screenUpdateTimer = nil
        visibilityTimer?.invalidate()
        visibilityTimer = nil
        
        // Close and remove button window
        buttonWindow?.close()
        buttonWindow = nil
    }

    private func floatingButtonClicked() {
        // Don't hide overlay if it's visible - just show prompt window
        // This prevents the hanging issue
        
        // The controller is now persistent and passed in from the AppDelegate.
        // DO NOT re-create it here.
        
        // Use the screen the button is on, or the one with the mouse, or fallback to main.
        guard let controller = promptWindowController else { return }

        if let window = controller.window, window.isVisible {
            // If the window is already visible, just bring it to the front.
            window.orderFront(nil)
        } else {
            // Otherwise, show it on the correct screen.
            let screen = buttonWindow?.screen ?? NSScreen.screenWithMouse() ?? NSScreen.main!
            controller.showWindow(on: screen)
        }
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
            guard let fallbackScreen = NSScreen.main ?? NSScreen.screens.first else {
                print("FloatingButtonManager: No screens available")
                return
            }
            screen = fallbackScreen
        }

        // Try to load saved position for this screen with validation
        if let savedPosition = loadPosition(for: screen),
           let validatedPosition = validatePosition(savedPosition, for: screen, windowSize: window.frame.size) {
            logger.log("Loading validated saved position for screen: x=\(validatedPosition.x), y=\(validatedPosition.y)")
            window.setFrameOrigin(validatedPosition)
        } else {
            // Default position if no saved position exists or saved position is invalid
            let defaultPosition = getDefaultPosition(for: screen)
            logger.log("Using default position: x=\(defaultPosition.x), y=\(defaultPosition.y)")
            window.setFrameOrigin(defaultPosition)
        }
    }
    
    private func saveCurrentPosition() {
        guard let window = buttonWindow,
              let screen = window.screen ?? lastKnownScreen else { return }
        
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
    
    private func validatePosition(_ position: NSPoint, for screen: NSScreen, windowSize: NSSize) -> NSPoint? {
        let visibleFrame = screen.visibleFrame
        let padding: CGFloat = 20
        
        // Check if position is within screen bounds with padding
        let minX = visibleFrame.minX + padding
        let maxX = visibleFrame.maxX - windowSize.width - padding
        let minY = visibleFrame.minY + padding  
        let maxY = visibleFrame.maxY - windowSize.height - padding
        
        // If position is completely out of bounds, return nil
        if position.x < visibleFrame.minX - windowSize.width || 
           position.x > visibleFrame.maxX ||
           position.y < visibleFrame.minY - windowSize.height ||
           position.y > visibleFrame.maxY {
            logger.log("⚠️ Saved position is completely outside screen bounds, using default")
            return nil
        }
        
        // Adjust position to be within safe bounds
        let adjustedX = max(minX, min(maxX, position.x))
        let adjustedY = max(minY, min(maxY, position.y))
        
        let adjustedPosition = NSPoint(x: adjustedX, y: adjustedY)
        
        // Log if position was adjusted
        if adjustedPosition != position {
            logger.log("📍 Adjusted position from (\(position.x), \(position.y)) to (\(adjustedX), \(adjustedY))")
        }
        
        return adjustedPosition
    }
    
    private func getDefaultPosition(for screen: NSScreen) -> NSPoint {
        let padding: CGFloat = 20
        let xPos = screen.visibleFrame.minX + padding
        let yPos = screen.visibleFrame.minY + padding
        return NSPoint(x: xPos, y: yPos)
    }
} 