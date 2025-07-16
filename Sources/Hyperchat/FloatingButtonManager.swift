/// FloatingButtonManager.swift - Floating Button UI and Interaction Management
///
/// This file manages the persistent floating button that follows users across macOS spaces.
/// The button provides quick access to Hyperchat from anywhere on the system.
///
/// Key responsibilities:
/// - Creates and positions a 64x64px floating button window
/// - Handles drag-and-drop repositioning with position persistence
/// - Manages hover effects with animated gradient glow
/// - Tracks mouse across multiple displays
/// - Maintains visibility across space switches
/// - Triggers prompt window on click
///
/// Related files:
/// - `AppDelegate.swift`: Creates FloatingButtonManager and connects it to other controllers
/// - `PromptWindowController.swift`: Shows when floating button is clicked
/// - `OverlayController.swift`: May be shown after prompt submission
/// - `NSScreen+Extensions.swift`: Provides screen utility methods
///
/// Architecture:
/// - Uses NSPanel with .floating level for always-on-top behavior
/// - Custom DraggableView handles both click and drag interactions
/// - SwiftUI view provides animated gradient glow on hover
/// - Timer-based screen tracking for multi-monitor support

import Cocoa
import SwiftUI
import os.log

// MARK: - Timing Constants

/// Timing constants for floating button behavior.
private enum FloatingButtonTimings {
    /// Interval for checking if mouse moved to different screen
    static let screenUpdateInterval: TimeInterval = 0.5
    
    /// Interval for ensuring button stays visible
    static let visibilityCheckInterval: TimeInterval = 1.0
    
    /// Delay before verifying button visibility after creation
    static let visibilityVerificationDelay: TimeInterval = 1.0
    
    /// Animation duration for glow fade in/out
    static let glowFadeDuration: TimeInterval = 0.2
    
    /// Duration for one complete glow rotation
    static let glowRotationDuration: TimeInterval = 3.0
}

/// Layout constants for floating button.
private enum FloatingButtonLayout {
    /// Total window size (includes padding)
    static let windowSize: CGFloat = 64
    
    /// Icon size within the window
    static let iconSize: CGFloat = 48
    
    /// Padding around the icon
    static let iconPadding: CGFloat = 8
    
    /// Corner radius for icon view
    static let iconCornerRadius: CGFloat = 10
    
    /// Corner radius for glow effect
    static let glowCornerRadius: CGFloat = 20
    
    /// Line widths for glow layers
    static let outerGlowWidth: CGFloat = 4.8
    static let middleGlowWidth: CGFloat = 3.2
    static let innerGlowWidth: CGFloat = 1.2
    
    /// Blur radii for glow layers
    static let outerGlowBlur: CGFloat = 6
    static let middleGlowBlur: CGFloat = 3
    static let innerGlowBlur: CGFloat = 0.5
    
    /// Insets for glow layers (account for padding)
    static let outerGlowInset: CGFloat = 10
    static let middleGlowInset: CGFloat = 11
    static let innerGlowInset: CGFloat = 12
    
    /// Minimum padding from screen edges
    static let screenEdgePadding: CGFloat = 20
    
    /// Threshold for distinguishing click from drag
    static let clickThreshold: CGFloat = 5.0
}

// MARK: - Floating Button Glow View

/// SwiftUI view for animated gradient glow effect on hover.
///
/// Creates a three-layer animated gradient that rotates around the button.
/// Each layer has different width and blur for depth effect.
///
/// Animation lifecycle:
/// 1. Created with isVisible=false (no glow)
/// 2. When isVisible becomes true, starts rotation animation
/// 3. When isVisible becomes false, cancels animation and resets
///
/// Used by:
/// - `DraggableView`: Updates visibility on mouse enter/exit
struct FloatingButtonGlow: View {
    /// Current rotation angle of the gradient (0-360 degrees)
    @State private var phase: CGFloat = 0
    
    /// Task handle for rotation animation (cancelled when not visible)
    @State private var animationTask: Task<Void, Never>?
    
    /// Whether the glow should be visible (controlled by hover state)
    let isVisible: Bool
    
    var body: some View {
        ZStack {
            // Outer glow layer
            RoundedRectangle(cornerRadius: FloatingButtonLayout.glowCornerRadius)
                .inset(by: FloatingButtonLayout.outerGlowInset)  // Account for 8px padding + icon internal padding
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
                    lineWidth: FloatingButtonLayout.outerGlowWidth
                )
                .blur(radius: FloatingButtonLayout.outerGlowBlur)
                .opacity(0.4)
            
            // Middle glow layer
            RoundedRectangle(cornerRadius: FloatingButtonLayout.glowCornerRadius)
                .inset(by: FloatingButtonLayout.middleGlowInset)  // Account for 8px padding + icon internal padding
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
                    lineWidth: FloatingButtonLayout.middleGlowWidth
                )
                .blur(radius: FloatingButtonLayout.middleGlowBlur)
                .opacity(0.6)
            
            // Inner sharp layer
            RoundedRectangle(cornerRadius: FloatingButtonLayout.glowCornerRadius)
                .inset(by: FloatingButtonLayout.innerGlowInset)  // Account for 8px padding + icon internal padding
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
                    lineWidth: FloatingButtonLayout.innerGlowWidth
                )
                .blur(radius: FloatingButtonLayout.innerGlowBlur)
        }
        .opacity(isVisible ? 1 : 0)
        .background(Color.clear)
        .animation(.easeInOut(duration: FloatingButtonTimings.glowFadeDuration), value: isVisible)
        .allowsHitTesting(false)  // Allow mouse events to pass through to button
        .onChange(of: isVisible) { oldValue, newValue in
            if newValue {
                // Start animation when becoming visible
                animationTask = Task {
                    withAnimation(.linear(duration: FloatingButtonTimings.glowRotationDuration).repeatForever(autoreverses: false)) {
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

// MARK: - Floating Panel

/// Custom NSPanel subclass that prevents the floating button from becoming key window.
///
/// This ensures the button never steals focus from other windows when clicked.
/// The panel can still receive mouse events but won't disrupt the user's workflow.
///
/// Key behaviors:
/// - canBecomeKey returns false (never becomes key window)
/// - acceptsFirstResponder returns true (receives mouse events)
/// - Overrides makeKey methods to prevent accidental key window status
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

// MARK: - Draggable View

/// Custom NSView that handles both click and drag interactions for the floating button.
///
/// Interaction model:
/// - Click: Shows prompt window if mouse moves < 5 pixels
/// - Drag: Moves button window and saves new position
/// - Hover: Shows/hides animated glow effect
///
/// The view manages:
/// - App icon display (48x48px with rounded corners)
/// - SwiftUI glow overlay (animated on hover)
/// - Mouse tracking for hover effects
/// - Drag threshold detection
///
/// Callbacks:
/// - dragCallback: Called during drag to save position
/// - clickCallback: Called on click to show prompt window
class DraggableView: NSView {
    /// Initial mouse location on mouseDown (used to calculate drag distance)
    private var initialLocation: NSPoint?
    
    /// Callback invoked during drag to save button position
    private let dragCallback: () -> Void
    
    /// Callback invoked on click to show prompt window
    private let clickCallback: () -> Void
    
    /// Tracking area for mouse enter/exit events
    private var trackingArea: NSTrackingArea?
    
    /// SwiftUI hosting view for the animated glow effect
    private var glowHostingView: NSHostingView<FloatingButtonGlow>?
    
    /// Image view displaying the app icon
    private var iconView: NSImageView?
    
    /// Current hover state (triggers glow visibility)
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
        let iconSize = FloatingButtonLayout.iconSize
        let padding = FloatingButtonLayout.iconPadding
        iconView = NSImageView(frame: NSRect(x: padding, y: padding, width: iconSize, height: iconSize))
        if let appIcon = NSImage(named: "AppIcon") {
            appIcon.size = NSSize(width: iconSize, height: iconSize)
            iconView?.image = appIcon
        }
        iconView?.imageScaling = .scaleProportionallyUpOrDown
        iconView?.wantsLayer = true
        iconView?.layer?.cornerRadius = FloatingButtonLayout.iconCornerRadius
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
            
            // Consider it a click if the mouse moved less than threshold
            let clickThreshold = FloatingButtonLayout.clickThreshold
            
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

// MARK: - Floating Button Manager

/// Manages the floating button window lifecycle and interactions.
///
/// Created by:
/// - `AppDelegate` during application startup
///
/// Manages:
/// - Button window creation and positioning
/// - Position persistence per screen configuration
/// - Multi-monitor support with automatic relocation
/// - Visibility maintenance across space switches
/// - Click handling to show prompt window
///
/// Position persistence:
/// - Saves position per screen configuration (not just screen ID)
/// - Validates saved positions on restore
/// - Falls back to default position if saved position invalid
/// - Uses screen corner (bottom-left + 20px padding) as default
///
/// Multi-monitor behavior:
/// - Follows mouse cursor to active screen
/// - Maintains separate saved position per screen
/// - Updates every 0.5 seconds via timer
class FloatingButtonManager {
    /// The floating button window (NSPanel subclass)
    private var buttonWindow: NSWindow?
    
    /// Reference to prompt window controller (set by AppDelegate)
    /// Called by: floatingButtonClicked() to show prompt window
    var promptWindowController: PromptWindowController?
    
    /// Reference to overlay controller (set by AppDelegate)
    /// Currently unused but available for future features
    var overlayController: OverlayController?
    
    /// Logger for debugging button behavior
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.transcendence.hyperchat", category: "FloatingButtonManager")
    
    /// Timer that checks if mouse moved to different screen
    private var screenUpdateTimer: Timer?
    
    /// Last screen the button was positioned on
    private var lastKnownScreen: NSScreen?
    
    /// UserDefaults key for storing button positions
    private let positionsKey = "HyperchatButtonPositions"
    
    /// Timer that ensures button stays visible
    private var visibilityTimer: Timer?

    init() {
        // Listen for floating button toggle notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(floatingButtonToggled(_:)),
            name: .floatingButtonToggled,
            object: nil
        )
    }
    
    deinit {
        screenUpdateTimer?.invalidate()
        visibilityTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    /// Shows the floating button window.
    ///
    /// Called by:
    /// - `AppDelegate.applicationDidFinishLaunching()` on startup
    /// - `ensureFloatingButtonVisible()` to restore visibility
    ///
    /// Process:
    /// 1. Checks for existing button (prevents duplicates)
    /// 2. Creates 64x64px borderless panel window
    /// 3. Sets up DraggableView with icon and glow
    /// 4. Positions based on saved position or default
    /// 5. Starts screen tracking and visibility timers
    ///
    /// Window configuration:
    /// - Level: .floating (always on top)
    /// - Collection behavior: .canJoinAllSpaces
    /// - Hides on deactivate: false (stays visible)
    func showFloatingButton() {
        logger.log("👇 showFloatingButton called.")
        
        // Check if floating button is enabled in settings
        guard SettingsManager.shared.isFloatingButtonEnabled else {
            logger.log("ℹ️ Floating button is disabled in settings")
            return
        }
        
        // Prevent creating duplicate buttons
        if let existingWindow = buttonWindow {
            logger.log("⚠️ Floating button already exists, bringing to front")
            existingWindow.orderFront(nil)
            
            // Update position in case screen geometry changed
            updateButtonPosition()
            return
        }
        
        let windowSize = FloatingButtonLayout.windowSize
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
        screenUpdateTimer = Timer.scheduledTimer(withTimeInterval: FloatingButtonTimings.screenUpdateInterval, repeats: true) { [weak self] _ in
            self?.checkAndUpdateScreenIfNeeded()
        }

        // Start timer to ensure button stays visible
        visibilityTimer = Timer.scheduledTimer(withTimeInterval: FloatingButtonTimings.visibilityCheckInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let window = self.buttonWindow, !window.isVisible {
                window.orderFront(nil)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + FloatingButtonTimings.visibilityVerificationDelay) {
            if let w = self.buttonWindow, w.isVisible {
                self.logger.log("✅ SUCCESS: Floating button window is visible on screen.")
            } else {
                self.logger.error("❌ FAILURE: Floating button window is NOT visible after 1 second.")
            }
        }
    }

    /// Ensures the floating button is visible.
    ///
    /// Called by:
    /// - `AppDelegate` when overlay hides (via notification)
    /// - Visibility timer every 1.0 seconds
    ///
    /// Simply brings button window to front if it exists.
    func ensureFloatingButtonVisible() {
        buttonWindow?.orderFront(nil)
    }
    
    /// Hides and destroys the floating button.
    ///
    /// Called by:
    /// - Currently not called (button persists for app lifetime)
    /// - Could be used for preferences to disable button
    ///
    /// Cleanup process:
    /// 1. Invalidates screen tracking timer
    /// 2. Invalidates visibility timer
    /// 3. Closes and releases button window
    func hideFloatingButton() {
        // Clean up timers
        screenUpdateTimer?.invalidate()
        screenUpdateTimer = nil
        visibilityTimer?.invalidate()
        visibilityTimer = nil
        
        // Close and remove button window
        buttonWindow?.close()
        buttonWindow = nil
        
        logger.log("✅ Floating button hidden")
    }
    
    /// Handles notification when floating button is toggled in settings.
    ///
    /// Called by:
    /// - Notification from SettingsManager when floating button is toggled
    ///
    /// Process:
    /// - If enabled: Shows the floating button
    /// - If disabled: Hides the floating button
    @objc private func floatingButtonToggled(_ notification: Notification) {
        if let isEnabled = notification.object as? Bool {
            logger.log("🔔 Floating button toggled: \(isEnabled)")
            
            if isEnabled {
                showFloatingButton()
            } else {
                hideFloatingButton()
            }
        }
    }

    /// Handles floating button click events.
    ///
    /// Called by:
    /// - `DraggableView.mouseUp()` when click detected
    ///
    /// Behavior:
    /// - If prompt window already visible: brings to front
    /// - If prompt window hidden: shows on button's screen
    /// - Never hides overlay (prevents app hanging)
    /// - Tracks analytics for floating button usage
    ///
    /// Screen selection priority:
    /// 1. Screen containing the button
    /// 2. Screen containing the mouse
    /// 3. Main screen as fallback
    private func floatingButtonClicked() {
        // Track floating button click for analytics
        AnalyticsManager.shared.trackFloatingButtonClicked()
        
        // Set prompt source for subsequent prompt submission attribution
        AnalyticsManager.shared.setPromptSource(.floatingButton)
        
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
    
    /// Checks if mouse moved to different screen and updates button position.
    ///
    /// Called by:
    /// - Screen update timer every 0.5 seconds
    ///
    /// Updates button position when:
    /// - Mouse moves to different screen
    /// - Screen configuration changes
    ///
    /// This enables the "follow mouse" behavior across monitors.
    private func checkAndUpdateScreenIfNeeded() {
        guard let currentScreen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) else { return }
        
        if currentScreen != lastKnownScreen {
            logger.log("🖱️ Mouse moved to different screen")
            lastKnownScreen = currentScreen
            updateButtonPosition()
        }
    }
    
    /// Updates button position for current screen.
    ///
    /// Called by:
    /// - `showFloatingButton()` on initial display
    /// - `checkAndUpdateScreenIfNeeded()` when screen changes
    ///
    /// Position logic:
    /// 1. Determines target screen (mouse location or main)
    /// 2. Loads saved position for screen configuration
    /// 3. Validates saved position is within bounds
    /// 4. Falls back to default position if needed
    ///
    /// Default position: bottom-left + 20px padding
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
    
    /// Saves current button position for the current screen.
    ///
    /// Called by:
    /// - `DraggableView.mouseDragged()` during drag operation
    ///
    /// Persistence:
    /// - Saves to UserDefaults with screen identifier as key
    /// - Position stored as dictionary with x,y coordinates
    /// - Persists across app launches
    private func saveCurrentPosition() {
        guard let window = buttonWindow,
              let screen = window.screen ?? lastKnownScreen else { return }
        
        let position = window.frame.origin
        savePosition(position, for: screen)
        logger.log("Saved position for screen: x=\(position.x), y=\(position.y)")
    }
    
    /// Creates unique identifier for a screen based on its geometry.
    ///
    /// Called by:
    /// - `savePosition()` and `loadPosition()` for persistence key
    ///
    /// Format: "x,y,width,height" (all values as integers)
    ///
    /// Why geometry-based:
    /// - Screen IDs can change between system restarts
    /// - Geometry is more stable for position persistence
    /// - Handles external monitor reconnection gracefully
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
    
    /// Validates and adjusts a saved position for screen bounds.
    ///
    /// Called by:
    /// - `updateButtonPosition()` when restoring saved position
    ///
    /// Validation:
    /// - Checks if position is completely outside screen
    /// - Adjusts position to be within safe bounds
    /// - Maintains 20px padding from screen edges
    ///
    /// - Parameters:
    ///   - position: Saved position to validate
    ///   - screen: Target screen for validation
    ///   - windowSize: Size of button window
    /// - Returns: Adjusted position or nil if completely invalid
    private func validatePosition(_ position: NSPoint, for screen: NSScreen, windowSize: NSSize) -> NSPoint? {
        let visibleFrame = screen.visibleFrame
        let padding = FloatingButtonLayout.screenEdgePadding
        
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
    
    /// Returns default position for button on given screen.
    ///
    /// Called by:
    /// - `updateButtonPosition()` when no saved position exists
    ///
    /// Default: Bottom-left corner + 20px padding
    ///
    /// This position was chosen to:
    /// - Avoid dock area on bottom
    /// - Avoid menu bar on top
    /// - Be easily accessible
    /// - Not obstruct content
    private func getDefaultPosition(for screen: NSScreen) -> NSPoint {
        let padding = FloatingButtonLayout.screenEdgePadding
        let xPos = screen.visibleFrame.minX + padding
        let yPos = screen.visibleFrame.minY + padding
        return NSPoint(x: xPos, y: yPos)
    }
} 