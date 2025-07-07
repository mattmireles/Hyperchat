/// PromptWindowController.swift - Floating Prompt Input Window
///
/// This file manages the floating prompt input window that appears when users click
/// the floating button or use the global hotkey. It provides a focused text input
/// for sending prompts to all AI services simultaneously.
///
/// Key responsibilities:
/// - Creates borderless floating window with blur background
/// - Manages text input with multi-line support (Shift+Enter)
/// - Handles window positioning and resizing
/// - Provides animated gradient border (Siri-like effect)
/// - Submits prompts via notification system
/// - Handles keyboard shortcuts (Cmd+A/C/V/X/Z)
///
/// Related files:
/// - `FloatingButtonManager.swift`: Shows prompt window on button click
/// - `AppDelegate.swift`: Creates and manages PromptWindowController
/// - `OverlayController.swift`: Receives prompts via showOverlay notification
/// - `ServiceManager.swift`: Executes prompts across all services
///
/// Architecture:
/// - Uses NSWindow subclass for keyboard event handling
/// - SwiftUI view for modern UI with animations
/// - NSHostingController bridges AppKit and SwiftUI
/// - Notification-based communication with other components

import Cocoa
import SwiftUI
import Combine

// MARK: - Timing Constants

/// Timing constants for prompt window animations and behavior.
private enum PromptWindowTimings {
    /// Delay for gentle window activation pattern
    static let windowActivationDelay: TimeInterval = 0.1
    
    /// Duration of gradient border rotation animation
    static let gradientRotationDuration: TimeInterval = 3.0
    
    /// Duration of submit button hover animation
    static let hoverAnimationDuration: TimeInterval = 0.2
    
    /// Delay before executing submit to show flame animation
    static let submitAnimationDelay: TimeInterval = 0.3
    
    /// Duration to show flame icon after submit
    static let flameIconDuration: TimeInterval = 1.0
}

/// Layout constants for prompt window.
private enum PromptWindowLayout {
    /// Window dimensions
    static let windowWidth: CGFloat = 840
    static let windowHeight: CGFloat = 164
    
    /// Content dimensions (without padding)
    static let contentWidth: CGFloat = 800
    static let contentHeight: CGFloat = 72
    
    /// Padding values
    static let outerPadding: CGFloat = 20
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 12
    
    /// Component sizes
    static let logoSize: CGFloat = 48
    static let logoCornerRadius: CGFloat = 10
    static let inputCornerRadius: CGFloat = 10
    static let windowCornerRadius: CGFloat = 12
    
    /// Text editor constraints
    static let textEditorMinHeight: CGFloat = 36
    static let textEditorMaxHeight: CGFloat = 36
    static let textEditorHorizontalPadding: CGFloat = 12
    static let textEditorVerticalPadding: CGFloat = 5
    
    /// Maximum window height as percentage of screen
    static let maxHeightPercentage: CGFloat = 0.8
}

// MARK: - AppKit Components

/// Custom NSWindow subclass for the prompt input window.
///
/// Handles:
/// - ESC key to close window (standard macOS behavior)
/// - Command key shortcuts in borderless window
/// - Enter key monitoring for submit
/// - Proper cleanup of event monitors
///
/// The window is:
/// - Borderless for clean appearance
/// - Floating level to stay above other windows
/// - Transparent background for visual effects
class PromptWindow: NSWindow {
    /// Event monitor for Enter key handling (currently unused)
    private var enterKeyMonitor: Any?
    
    /// Allow window to become key for text input
    override var canBecomeKey: Bool { true }
    
    /// Allow window to become main (needed for borderless windows)
    override var canBecomeMain: Bool { true }

    /// Handles ESC key to close window (standard macOS behavior).
    ///
    /// Called when:
    /// - User presses ESC key
    /// - cancelOperation is sent through responder chain
    override func cancelOperation(_ sender: Any?) {
        close()
    }
    
    override func close() {
        // Clean up event monitor when window closes
        if let monitor = enterKeyMonitor {
            NSEvent.removeMonitor(monitor)
            enterKeyMonitor = nil
        }
        super.close()
    }
    
    override func resignKey() {
        // Clean up event monitor when window loses key status
        if let monitor = enterKeyMonitor {
            NSEvent.removeMonitor(monitor)
            enterKeyMonitor = nil
        }
        super.resignKey()
    }

    /// Handles command key shortcuts in borderless window.
    ///
    /// Borderless windows don't get automatic menu shortcuts,
    /// so we manually handle common text editing commands:
    /// - Cmd+A: Select All
    /// - Cmd+C: Copy
    /// - Cmd+V: Paste
    /// - Cmd+X: Cut
    /// - Cmd+Z: Undo
    /// - Cmd+Shift+Z: Redo
    ///
    /// Returns true if handled, false to pass to next responder.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "a":
                return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
            case "c":
                return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
            case "v":
                return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
            case "x":
                return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
            case "z":
                if event.modifierFlags.contains(.shift) {
                    // Cmd+Shift+Z for Redo
                    return NSApp.sendAction(Selector(("redo:")), to: nil, from: self)
                } else {
                    // Cmd+Z for Undo
                    return NSApp.sendAction(Selector(("undo:")), to: nil, from: self)
                }
            default:
                // Not a recognized shortcut, let the system handle it.
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - Prompt Window Controller

/// Manages the prompt input window lifecycle and positioning.
///
/// Created by:
/// - `AppDelegate` during initialization (single persistent instance)
///
/// Shown by:
/// - `FloatingButtonManager.floatingButtonClicked()`
/// - Global hotkey handler (if configured)
///
/// Window behavior:
/// - Centers on target screen when shown
/// - Adjusts height dynamically (future: multi-line input)
/// - Uses gentle activation to prevent menu bar issues
/// - Closes on ESC or after submit
class PromptWindowController: NSWindowController {
    /// SwiftUI hosting controller for the prompt view
    private var hostingController: NSHostingController<PromptView>?
    
    /// Current screen for positioning and max height calculations
    private var currentScreen: NSScreen?
    
    /// App focus publisher for accessing app focus state
    private var appFocusPublisher: AnyPublisher<Bool, Never>?
    
    /// Tracks whether this prompt window is the key window
    @Published public private(set) var isPromptWindowFocused: Bool = false

    init(appFocusPublisher: AnyPublisher<Bool, Never>?) {
        let window = PromptWindow(
            contentRect: NSRect(x: 0, y: 0, width: PromptWindowLayout.windowWidth, height: PromptWindowLayout.windowHeight), // Includes padding
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating

        super.init(window: window)
        self.appFocusPublisher = appFocusPublisher
        setupWindowFocusTracking()
        setupPromptView()
    }
    
    convenience init() {
        self.init(appFocusPublisher: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        // Clean up notification observers
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Sets up window focus tracking for the prompt window.
    ///
    /// Called during initialization to track when this prompt window
    /// becomes/resigns key window status for conditional glow border display.
    private func setupWindowFocusTracking() {
        guard let window = window else { return }
        
        // Listen for this window becoming key
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.isPromptWindowFocused = true
        }
        
        // Listen for this window resigning key
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.isPromptWindowFocused = false
        }
    }
    
    private func setupPromptView() {
        guard let window = window else { return }

        // Create the SwiftUI view with callbacks for dynamic behavior
        // onHeightChange: Adjusts window height for multi-line input (future)
        // maxHeight: Provides screen-aware maximum height
        // appFocusPublisher: Provides app focus state for conditional glow border
        // windowFocusPublisher: Provides prompt window focus state for window-specific glow border
        let promptView = PromptView(
            onHeightChange: { [weak self] newHeight in
                self?.adjustWindowHeight(to: newHeight)
            }, 
            maxHeight: { [weak self] in
                self?.getMaxHeight() ?? 600
            },
            appFocusPublisher: appFocusPublisher,
            windowFocusPublisher: $isPromptWindowFocused.eraseToAnyPublisher()
        )
        
        hostingController = NSHostingController(rootView: promptView)
        window.contentViewController = hostingController
    }

    /// Shows the prompt window centered on the specified screen.
    ///
    /// Called by:
    /// - `FloatingButtonManager.floatingButtonClicked()`
    ///
    /// Process:
    /// 1. Centers window on target screen
    /// 2. Shows window with orderFront
    /// 3. Makes key after delay (gentle activation)
    ///
    /// The gentle activation pattern prevents:
    /// - Menu bar disruption
    /// - Focus stealing from other apps
    /// - WebView interference
    func showWindow(on screen: NSScreen?) {
        guard let window = window else { return }
        
        currentScreen = screen

        // Center the window on the target screen
        if let targetScreen = screen {
            let screenRect = targetScreen.visibleFrame
            let windowFrame = window.frame
            let x = screenRect.origin.x + (screenRect.width - windowFrame.width) / 2
            let y = screenRect.origin.y + (screenRect.height - windowFrame.height) / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        super.showWindow(nil)
        // Use gentle activation pattern to prevent menu bar reset
        window.orderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + PromptWindowTimings.windowActivationDelay) {
            window.makeKey()
        }
    }
    
    /// Calculates maximum window height based on screen size.
    ///
    /// Used by:
    /// - SwiftUI view for constraining multi-line input
    ///
    /// Returns 80% of screen height to leave room for:
    /// - Menu bar
    /// - Dock
    /// - Visual breathing room
    private func getMaxHeight() -> CGFloat {
        let screen = currentScreen ?? NSScreen.main ?? NSScreen.screens.first
        let screenHeight = screen?.visibleFrame.height ?? 800
        return screenHeight * PromptWindowLayout.maxHeightPercentage
    }

    /// Adjusts window height for dynamic content.
    ///
    /// Called by:
    /// - SwiftUI view when content height changes
    ///
    /// Currently supports:
    /// - Fixed 2-line input (no actual resizing yet)
    ///
    /// Future enhancement:
    /// - Multi-line input with auto-growing window
    /// - Smooth animation during resize
    /// - Maintains top edge position (grows downward)
    private func adjustWindowHeight(to newHeight: CGFloat) {
        guard let window = window else { return }
        
        let maxHeight = getMaxHeight()
        let constrainedHeight = min(newHeight, maxHeight)
        
        let currentFrame = window.frame
        // Only resize if the height difference is significant
        if abs(constrainedHeight - currentFrame.height) > 1 {
            // Keep the window anchored at its current top position
            // In macOS coordinates, we need to adjust the origin.y to maintain the top edge position
            let newFrame = NSRect(
                x: currentFrame.origin.x,
                y: currentFrame.origin.y - (constrainedHeight - currentFrame.height), // Grow downward
                width: currentFrame.width,
                height: constrainedHeight
            )
            
            // Ensure the window doesn't go below the screen bounds
            if let screen = currentScreen ?? window.screen {
                let screenFrame = screen.visibleFrame
                var adjustedFrame = newFrame
                
                // If the bottom would go below the screen, adjust the position
                if adjustedFrame.origin.y < screenFrame.origin.y {
                    adjustedFrame.origin.y = screenFrame.origin.y
                }
                
                window.setFrame(adjustedFrame, display: true, animate: true)
            } else {
                window.setFrame(newFrame, display: true, animate: true)
            }
        }
    }
}

// MARK: - SwiftUI View and Helpers

/// Creates animated gradient border with rotating colors.
///
/// Visual design:
/// - Three-layer glow effect (outer, middle, inner)
/// - Pink-to-blue gradient that rotates continuously
/// - Different blur levels for depth
/// - Inspired by Siri activation effect
///
/// Animation:
/// - 3-second full rotation
/// - Linear, non-reversing
/// - Starts/stops based on visibility state
/// - Fades in/out when visibility changes
struct AnimatedGradientBorder: View {
    /// Current rotation angle of gradient (0-360)
    @State private var phase: CGFloat = 0
    
    /// Controls border visibility and animation
    let isVisible: Bool
    
    /// Corner radius matching the window shape
    let cornerRadius: CGFloat
    
    /// Base line width (multiplied for different layers)
    let lineWidth: CGFloat
    
    /// Animation task for continuous rotation
    @State private var animationTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // Outermost glow layer - softly blurred
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.0, blue: 0.8),      // Pink/Magenta
                            Color(red: 0.0, green: 0.6, blue: 1.0),      // Blue
                            Color(red: 1.0, green: 0.0, blue: 0.8),      // Pink/Magenta (repeat for seamless loop)
                            Color(red: 0.0, green: 0.6, blue: 1.0),      // Blue 
                            Color(red: 1.0, green: 0.0, blue: 0.8)      // Pink/Magenta (final)
                        ]),
                        center: .center,
                        startAngle: .degrees(phase),
                        endAngle: .degrees(phase + 360)
                    ),
                    lineWidth: lineWidth * 1.2
                )
                .blur(radius: 6)
                .opacity(0.4)
            
            // Middle glow layer - subtle blur
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.0, blue: 0.8),      // Pink/Magenta
                            Color(red: 0.0, green: 0.6, blue: 1.0),      // Blue
                            Color(red: 1.0, green: 0.0, blue: 0.8),      // Pink/Magenta (repeat for seamless loop)
                            Color(red: 0.0, green: 0.6, blue: 1.0),      // Blue 
                            Color(red: 1.0, green: 0.0, blue: 0.8)      // Pink/Magenta (final)
                        ]),
                        center: .center,
                        startAngle: .degrees(phase),
                        endAngle: .degrees(phase + 360)
                    ),
                    lineWidth: lineWidth * 0.8
                )
                .blur(radius: 3)
                .opacity(0.6)
            
            // Inner sharp layer - minimal blur for definition
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.0, blue: 0.8),      // Pink/Magenta
                            Color(red: 0.0, green: 0.6, blue: 1.0),      // Blue
                            Color(red: 1.0, green: 0.0, blue: 0.8),      // Pink/Magenta (repeat for seamless loop)
                            Color(red: 0.0, green: 0.6, blue: 1.0),      // Blue 
                            Color(red: 1.0, green: 0.0, blue: 0.8)      // Pink/Magenta (final)
                        ]),
                        center: .center,
                        startAngle: .degrees(phase),
                        endAngle: .degrees(phase + 360)
                    ),
                    lineWidth: lineWidth * 0.3
                )
                .blur(radius: 0.5)
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
        .allowsHitTesting(false)
        .onChange(of: isVisible) { oldValue, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
        .onAppear {
            if isVisible {
                startAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    /// Starts the continuous gradient rotation animation.
    ///
    /// Uses a Task-based approach instead of SwiftUI's repeatForever
    /// to allow proper start/stop control based on visibility state.
    private func startAnimation() {
        animationTask?.cancel()
        animationTask = Task {
            while !Task.isCancelled {
                withAnimation(.linear(duration: PromptWindowTimings.gradientRotationDuration)) {
                    phase += 360
                }
                try? await Task.sleep(nanoseconds: UInt64(PromptWindowTimings.gradientRotationDuration * 1_000_000_000))
            }
        }
    }
    
    /// Stops the gradient rotation animation.
    ///
    /// Cancels the animation task to prevent unnecessary CPU usage
    /// when the border is not visible.
    private func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }
}

// MARK: - Notifications

/// Notification names for inter-component communication.
extension Notification.Name {
    /// Sent when prompt is submitted, carries prompt text as object
    /// Posted by: PromptView.handleSubmit()
    /// Received by: OverlayController to show window and execute prompt
    static let showOverlay = Notification.Name("showOverlay")
    
    /// Currently unused - for future direct prompt submission
    static let submitPrompt = Notification.Name("submitPrompt")
}

// MARK: - SwiftUI Preferences

/// Preference key for communicating view height changes.
///
/// Used for:
/// - Future multi-line input support
/// - Dynamic window resizing
///
/// The reduce function takes maximum height if multiple views report.
struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Prompt View

/// SwiftUI view providing the prompt input interface.
///
/// Layout:
/// - Hyperchat logo (48x48)
/// - Text input field with placeholder
/// - Clear button (when text exists)
/// - Submit button with gradient effect
///
/// Features:
/// - Auto-focuses on appearance
/// - Enter to submit, Shift+Enter for newline
/// - Animated submit button (flame icon)
/// - Blur background with conditional gradient border
/// - Focus-aware glow border (only shows when app is focused)
///
/// Callbacks:
/// - onHeightChange: Reports height for window sizing
/// - maxHeight: Gets maximum allowed height
/// - appFocusPublisher: Provides app focus state for conditional border
struct PromptView: View {
    /// Callback when view height changes (for dynamic sizing)
    var onHeightChange: (CGFloat) -> Void
    
    /// Callback to get maximum height from window controller
    var maxHeight: () -> CGFloat
    
    /// Publisher that provides app focus state for conditional glow border
    let appFocusPublisher: AnyPublisher<Bool, Never>?
    
    /// Publisher that provides window focus state for window-specific glow border
    let windowFocusPublisher: AnyPublisher<Bool, Never>?

    /// Current prompt text
    @State private var promptText: String = ""
    
    /// Focus state for auto-focusing input
    @FocusState private var isInputFocused: Bool
    
    /// Hover state for submit button animation
    @State private var isSubmitHovering = false
    
    /// Shows flame icon during submit animation
    @State private var showFlameIcon = false
    
    /// Tracks whether the app has focus (for conditional glow border)
    @State private var isAppFocused: Bool = false
    
    /// Tracks whether the prompt window has focus (for window-specific glow border)
    @State private var isWindowFocused: Bool = false
    
    /// Combine subscription for app focus updates
    @State private var cancellables: Set<AnyCancellable> = []

    var body: some View {
        // Outer transparent padding container
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Hyperchat logo
                Image("HyperchatIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: PromptWindowLayout.logoSize, height: PromptWindowLayout.logoSize)
                    .cornerRadius(PromptWindowLayout.logoCornerRadius)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Input field section - fills remaining space
                HStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        if promptText.isEmpty {
                            Text("Ask your AIs anything. `Esc` to dismiss.")
                                .foregroundColor(.secondary.opacity(0.4))
                                .font(.system(size: 14))
                                .padding(.leading, 17)  // Adjusted to align with cursor
                                .padding(.top, 5)
                        }
                        
                        CustomTextEditor(text: $promptText, onSubmit: {
                            submitWithAnimation()
                        })
                        .font(.system(size: 14))
                        .frame(minHeight: PromptWindowLayout.textEditorMinHeight, maxHeight: PromptWindowLayout.textEditorMaxHeight)
                        .padding(.horizontal, PromptWindowLayout.textEditorHorizontalPadding)
                        .padding(.vertical, PromptWindowLayout.textEditorVerticalPadding)
                        .focused($isInputFocused)
                    }
                    .frame(minHeight: 44)
                    
                    // Action buttons
                    HStack(spacing: 8) {
                        if !promptText.isEmpty {
                            Button(action: {
                                promptText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        Button(action: {
                            submitWithAnimation()
                        }) {
                            ZStack {
                                if !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || showFlameIcon {
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: Color(red: 1.0, green: 0.0, blue: 0.8), location: 0.0),        // Pink
                                            .init(color: Color(red: 1.0, green: 0.0, blue: 0.8), location: 0.4),        // Pink
                                            .init(color: Color(red: 0.6, green: 0.2, blue: 0.8), location: 0.6),        // Purple
                                            .init(color: Color(red: 0.0, green: 0.6, blue: 1.0), location: 0.85),       // Blue
                                            .init(color: Color(red: 0.0, green: 0.6, blue: 1.0), location: 1.0)         // Blue
                                        ]),
                                        startPoint: .bottomLeading,
                                        endPoint: .topTrailing
                                    )
                                    .mask(
                                        Image(systemName: showFlameIcon ? "flame.fill" : "chevron.up.2")
                                            .font(.system(size: 18, weight: .bold))
                                    )
                                    .scaleEffect(isSubmitHovering ? 1.15 : 1.0)
                                    .scaleEffect(showFlameIcon ? 1.2 : 1.0)
                                } else {
                                    Image(systemName: "chevron.up.2")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                            }
                            .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .animation(.easeInOut(duration: PromptWindowTimings.hoverAnimationDuration), value: promptText.isEmpty)
                        .animation(.easeInOut(duration: PromptWindowTimings.hoverAnimationDuration), value: isSubmitHovering)
                        .onHover { hovering in
                            isSubmitHovering = hovering
                        }
                    }
                    .padding(.trailing, 20)
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(PromptWindowLayout.inputCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: PromptWindowLayout.inputCornerRadius)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, PromptWindowLayout.horizontalPadding)
            .padding(.vertical, PromptWindowLayout.verticalPadding)
            .frame(height: PromptWindowLayout.contentHeight)
        }
        .frame(width: PromptWindowLayout.contentWidth)
        .background(
            VisualEffectBackground()
                .clipShape(RoundedRectangle(cornerRadius: PromptWindowLayout.windowCornerRadius))
        )
        .overlay(
            AnimatedGradientBorder(
                isVisible: isInputFocused && isAppFocused && isWindowFocused,
                cornerRadius: PromptWindowLayout.windowCornerRadius, 
                lineWidth: 4
            )
        )
        .overlay(
            GeometryReader { geometry in
                Color.clear.preference(key: HeightPreferenceKey.self, value: geometry.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self) { newTotalHeight in
            if newTotalHeight > 0 {
                // Add padding to the reported height
                onHeightChange(newTotalHeight + PromptWindowLayout.outerPadding * 2)
            }
        }
        .padding(PromptWindowLayout.outerPadding) // Add transparent padding around everything
        .onAppear { 
            isInputFocused = true 
            
            // Subscribe to app focus updates if publisher is available
            if let publisher = appFocusPublisher {
                publisher
                    .receive(on: DispatchQueue.main)
                    .sink { newAppFocusState in
                        isAppFocused = newAppFocusState
                    }
                    .store(in: &cancellables)
            }
            
            // Subscribe to window focus updates if publisher is available
            if let publisher = windowFocusPublisher {
                publisher
                    .receive(on: DispatchQueue.main)
                    .sink { newWindowFocusState in
                        isWindowFocused = newWindowFocusState
                    }
                    .store(in: &cancellables)
            }
        }
        .onDisappear {
            // Clean up subscriptions
            cancellables.removeAll()
        }
    }
    
    /// Submits prompt with flame icon animation.
    ///
    /// Animation sequence:
    /// 1. Show flame icon (0.2s)
    /// 2. Delay for visibility (0.3s)
    /// 3. Execute submit
    /// 4. Hide flame icon after 1s
    ///
    /// The flame icon provides visual feedback that
    /// the prompt is being processed.
    private func submitWithAnimation() {
        // Trigger flame animation
        withAnimation(.easeInOut(duration: PromptWindowTimings.hoverAnimationDuration)) {
            showFlameIcon = true
        }
        
        // Delay execution to ensure animation is visible
        DispatchQueue.main.asyncAfter(deadline: .now() + PromptWindowTimings.submitAnimationDelay) {
            handleSubmit()
        }
        
        // Reset icon after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + PromptWindowTimings.flameIconDuration) {
            withAnimation(.easeInOut(duration: PromptWindowTimings.hoverAnimationDuration)) {
                showFlameIcon = false
            }
        }
    }

    // MARK: - Action Handlers
    
    /// Closes the prompt window.
    ///
    /// Currently unused but available for cancel button.
    private func closeWindow() {
        NSApp.keyWindow?.close()
    }

    /// Handles prompt submission.
    ///
    /// Called by:
    /// - submitWithAnimation() after animation delay
    /// - Enter key in text editor
    ///
    /// Process:
    /// 1. Validates prompt is not empty
    /// 2. Posts showOverlay notification with prompt
    /// 3. Clears prompt text
    /// 4. Closes window
    ///
    /// The notification is received by OverlayController
    /// which shows the main window and executes the prompt.
    private func handleSubmit() {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let windowToClose = NSApp.keyWindow {
            NotificationCenter.default.post(name: .showOverlay, object: trimmed)
            promptText = ""
            windowToClose.close()
        }
    }
}