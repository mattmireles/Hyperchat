/// OverlayController.swift - Window Management and Lifecycle
///
/// This file manages all Hyperchat windows including overlay mode and normal windows.
/// It implements window hibernation for resource efficiency and handles proper WebView cleanup.
///
/// Key responsibilities:
/// - Creates and manages both overlay (full-screen) and normal windows
/// - Implements per-window ServiceManager isolation
/// - Handles window hibernation to reduce resource usage
/// - Manages proper WebView cleanup to prevent crashes
/// - Coordinates window activation and focus management
///
/// Related files:
/// - `ServiceManager.swift`: Created per-window for WebView isolation
/// - `AppDelegate.swift`: Triggers window creation via notifications
/// - `ContentView.swift`: SwiftUI content hosted in windows
/// - `BrowserViewController.swift`: Manages individual WebViews
/// - `WebViewFactory.swift`: Creates WebViews with proper configuration
///
/// Architecture:
/// - Each window has its own ServiceManager instance
/// - WebViews are never shared between windows
/// - Window hibernation pauses inactive windows
/// - Proper cleanup prevents WebKit crashes

import Cocoa
import SwiftUI
import WebKit
import Combine


// MARK: - Loading Overlay View

/// Timing constants for UI animations and transitions.
private enum UITimings {
    /// Delay before starting typewriter animation
    static let typewriterStartDelay: TimeInterval = 0.5
    
    /// Delay between each character in typewriter effect
    static let characterDelay: TimeInterval = 0.1
    
    /// Duration of loading overlay fade out
    static let loadingFadeOutDuration: TimeInterval = 0.7
    
    /// Delay before removing loading overlay
    static let loadingRemovalDelay: TimeInterval = 0.8
    
    /// Delay for WebView crash recovery
    static let crashRecoveryDelay: TimeInterval = 0.1
    
    /// Delay for window activation to prevent WebView disruption
    static let windowActivationDelay: TimeInterval = 0.1
}

extension Font {
    static func orbitronBold(size: CGFloat) -> Font {
        // Try custom font first, fallback to system font
        return Font.custom("Orbitron-Bold", size: size)
    }
}

/// Animated text view that reveals characters one by one.
/// Used for the "Hyperchat" branding on first window load.
struct TypewriterText: View {
    let text: String
    let font: Font
    let tracking: CGFloat
    @State private var revealedCharacters = 0
    
    var body: some View {
        Text(text)
            .font(font)
            .tracking(tracking)
            .foregroundStyle(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 1.0, green: 0.0, blue: 0.8), location: 0.0),        // Pink
                        .init(color: Color(red: 1.0, green: 0.0, blue: 0.8), location: 0.4),        // Pink
                        .init(color: Color(red: 0.6, green: 0.2, blue: 0.8), location: 0.6),      // Purple
                        .init(color: Color(red: 0.0, green: 0.6, blue: 1.0), location: 0.85),      // Blue
                        .init(color: Color(red: 0.0, green: 0.6, blue: 1.0), location: 1.0)      // Blue
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .mask(
                // Mask for typewriter effect
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(0..<text.count, id: \.self) { index in
                            Rectangle()
                                .frame(width: geometry.size.width / CGFloat(text.count))
                                .opacity(index < revealedCharacters ? 1 : 0)
                        }
                    }
                }
            )
        .onAppear {
            
            // Start typewriter effect after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + UITimings.typewriterStartDelay) {
                Timer.scheduledTimer(withTimeInterval: UITimings.characterDelay, repeats: true) { timer in
                    if revealedCharacters < text.count {
                        revealedCharacters += 1
                    } else {
                        timer.invalidate()
                    }
                }
            }
        }
    }
}

struct LoadingOverlayView: View {
    @Binding var opacity: Double
    let isFirstWindow: Bool
    
    var body: some View {
        ZStack {
            // Black background that fills entire window
            Color.black
                .ignoresSafeArea()
            
            // Hyperchat logo with black background removed via blend mode
            // This extracts only the non-black pixels (the swoosh and effects)
            GeometryReader { geometry in
                Image("HyperchatLoadingIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: geometry.size.height)
                    .frame(maxWidth: geometry.size.width)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blendMode(.screen) // Screen blend mode: black becomes transparent, colors remain
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isFirstWindow {
                // Animated text for first window only
                TypewriterText(
                    text: "Hyperchat",
                    font: .orbitronBold(size: 48),
                    tracking: 10
                )
                .padding(.bottom, 75)
                .padding(.trailing, 90)
            } else {
                // Static text for subsequent windows
                Text("Hyperchat")
                    .font(.orbitronBold(size: 48))
                    .tracking(10)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(stops: [
                        .init(color: Color(red: 1.0, green: 0.0, blue: 0.8), location: 0.0),        // Pink
                        .init(color: Color(red: 1.0, green: 0.0, blue: 0.8), location: 0.4),        // Pink
                        .init(color: Color(red: 0.6, green: 0.2, blue: 0.8), location: 0.6),      // Purple
                        .init(color: Color(red: 0.0, green: 0.6, blue: 1.0), location: 0.85),      // Blue
                        .init(color: Color(red: 0.0, green: 0.6, blue: 1.0), location: 1.0)      // Blue
                    ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.bottom, 75)
                    .padding(.trailing, 90)
            }
        }
        .opacity(opacity) // Single opacity applied to entire stack
        .allowsHitTesting(false) // Allow clicks to pass through during fade
    }
}

/// Custom NSWindow subclass for Hyperchat windows.
///
/// This window:
/// - Maintains weak reference to controller to prevent retain cycles
/// - Implements proper cleanup in close() to prevent WebKit crashes
/// - Handles keyboard shortcuts (Cmd+N for focus)
/// - Can be moved by dragging anywhere on the window
///
/// CRITICAL: The close() method must clean up WebViews before calling super.close()
/// to prevent crashes during AppKit's window deallocation.
class OverlayWindow: NSWindow {
    /// Weak reference to prevent retain cycles
    weak var overlayController: OverlayController?
    
    /// Unique identifier for debugging lifecycle
    private let instanceId = UUID().uuidString.prefix(8)

    override var canBecomeKey: Bool { true }
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        let address = Unmanaged.passUnretained(self).toOpaque()
        print("🧻 [\(Date().timeIntervalSince1970)] OverlayWindow INIT \(instanceId) at \(address)")
    }
    
    deinit {
        print("🔴 [\(Date().timeIntervalSince1970)] OverlayWindow DEINIT \(instanceId)")
    }
    
    // Allow window to be moved by dragging anywhere
    override var isMovableByWindowBackground: Bool {
        get { return true }
        set { }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 45 && event.modifierFlags.contains(.command) { // Cmd+N
            // Focus input through the window's ServiceManager
            if let controller = overlayController,
               let serviceManager = controller.serviceManager(for: self) {
                serviceManager.focusInputPublisher.send()
            }
        } else {
            super.keyDown(with: event)
        }
    }
    
    /// Handles window closure with proper WebView cleanup.
    ///
    /// CRITICAL cleanup sequence:
    /// 1. Wrap everything in autoreleasepool for WebKit objects
    /// 2. Clear weak reference to prevent double cleanup
    /// 3. Call removeWindow() BEFORE super.close()
    /// 4. Let AppKit handle the rest
    ///
    /// This order prevents crashes in objc_release during deallocation.
    override func close() {
        print("🛎 [\(Date().timeIntervalSince1970)] OverlayWindow.close() called for \(instanceId)")
        
        // Wrap cleanup in autoreleasepool to ensure WebKit's autoreleased objects
        // are released immediately, preventing crashes during run loop drain
        autoreleasepool {
            // Capture controller reference before any deallocation
            let controller = overlayController
            overlayController = nil // Clear reference immediately to prevent double cleanup
            
            print("🛑 [\(Date().timeIntervalSince1970)] OverlayWindow \(instanceId) calling removeWindow")
            
            // First, inform the controller that this window is going away **before** the window begins
            // its teardown inside super.close(). Doing it afterwards can lead to accessing objects
            // that have already started deallocating, which causes crashes in objc_release.
            controller?.removeWindow(self)
            NotificationCenter.default.post(name: .overlayDidHide, object: nil)

            print("🏁 [\(Date().timeIntervalSince1970)] OverlayWindow \(instanceId) calling super.close()")
            
            // Now let AppKit perform the actual close and deallocation work.
            super.close()
            
            print("✅ [\(Date().timeIntervalSince1970)] OverlayWindow \(instanceId) close() complete")
        }
    }
}

/// Central controller for all Hyperchat windows.
///
/// Manages window lifecycle, hibernation, and WebView isolation:
/// - Each window gets its own ServiceManager instance
/// - Inactive windows are hibernated to save resources
/// - Proper cleanup prevents WebKit crashes
/// - Supports both overlay (full-screen) and normal windows
///
/// Created by:
/// - `AppDelegate` as a singleton instance
///
/// Creates:
/// - `ServiceManager` instances per window
/// - `BrowserViewController` instances per service
/// - `ContentView` as SwiftUI content
///
/// Window types:
/// - Overlay: Full-screen window with black background
/// - Normal: Regular window with title bar
class OverlayController: NSObject, NSWindowDelegate, ObservableObject {
    // MARK: - Properties
    
    /// Direct reference to the AppDelegate to avoid timing issues with NSApp.delegate
    weak var appDelegate: AppDelegate?
    
    /// All active windows managed by this controller
    private var windows: [OverlayWindow] = []
    
    /// Flag to prevent recursive hiding
    private var isHiding = false
    
    /// Unique identifier for debugging
    private let instanceId = UUID().uuidString.prefix(8)
    
    // MARK: - Per-Window Instances
    
    /// ServiceManager instance for each window.
    /// Key: NSWindow, Value: ServiceManager for that window
    private var windowServiceManagers: [NSWindow: ServiceManager] = [:]
    
    /// BrowserViewControllers for each window.
    /// Key: NSWindow, Value: Array of BrowserViewControllers
    private var windowBrowserViewControllers: [NSWindow: [BrowserViewController]] = [:]
    
    /// LocalChatView hosting controllers for local services.
    /// Key: Service ID, Value: NSHostingController for LocalChatView
    private var localViewControllers: [String: NSHostingController<LocalChatView>] = [:]
    
    // MARK: - Window Hibernation
    
    /// Snapshot views for hibernated windows.
    /// Key: NSWindow, Value: NSImageView containing screenshot
    private var windowSnapshots: [NSWindow: NSImageView] = [:]
    
    /// Set of windows currently hibernated
    private var hibernatedWindows: Set<NSWindow> = []
    
    // MARK: - Loading Overlay
    
    /// Loading overlay views for each window.
    /// Shows "Hyperchat" branding during initial load.
    private var loadingOverlayViews: [NSWindow: NSHostingView<LoadingOverlayView>] = [:]
    
    /// Opacity values for loading overlay fade animation
    private var loadingOverlayOpacities: [NSWindow: Double] = [:]
    
    /// Timers for loading overlay fade out
    private var loadingTimers: [NSWindow: Timer] = [:]
    
    /// Whether this is the first window being loaded (shows typewriter animation)
    private var isFirstWindowLoad = true
    
    /// Windows currently hiding their loading overlays
    private var hidingOverlays: Set<NSWindow> = []
    
    private var stackViewConstraints: [NSLayoutConstraint] = []
    private var inputBarHostingView: NSHostingView<UnifiedInputBar>?
    
    // Combine subscriptions
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - App Focus State
    
    /// Published property indicating whether the Hyperchat app has focus.
    ///
    /// This state is used by UI components to show/hide focus indicators:
    /// - `true`: App is active and focused - show focus borders
    /// - `false`: App is inactive or background - hide focus borders
    ///
    /// Updated by:
    /// - `applicationDidBecomeActive(_:)` when app gains focus
    /// - `applicationWillResignActive(_:)` when app loses focus
    @Published public private(set) var isAppFocused: Bool = false
    
    /// Published property indicating whether any main window has key window status.
    ///
    /// This state is used to differentiate between main window focus and prompt window focus:
    /// - `true`: A main window (OverlayWindow) is the key window
    /// - `false`: No main window is key (prompt window, other app, etc.)
    ///
    /// Updated by:
    /// - `windowDidBecomeKey(_:)` when main window gains key status
    /// - `windowDidResignKey(_:)` when main window loses key status
    @Published public private(set) var isMainWindowFocused: Bool = false
    
    // Public accessor for window's ServiceManager
    func serviceManager(for window: NSWindow) -> ServiceManager? {
        return windowServiceManagers[window]
    }
    
    /// Public accessor for the number of windows currently managed by this controller.
    /// Used by AppDelegate to determine activation policy based on window count.
    public var windowCount: Int {
        return windows.count
    }
    
    /// Returns all managed overlay windows as NSWindows.
    ///
    /// Used by:
    /// - `AppDelegate.getWindowsOnCurrentSpace()` for space-aware filtering
    /// - Space-aware window management throughout the app
    ///
    /// - Returns: Array of all NSWindow instances managed by this controller
    public func getAllWindows() -> [NSWindow] {
        return windows.map { $0 as NSWindow }
    }
    
    /// Focuses the unified input bar in the most recent window.
    ///
    /// Used by:
    /// - `bringCurrentSpaceWindowToFront()` after bringing window to front
    /// - Keyboard shortcuts and other focus management
    ///
    /// This triggers the focus publisher that UnifiedInputBar listens to
    /// for immediate text input after window activation.
    public func focusInputBar() {
        // Get the most recent window's ServiceManager and trigger focus
        if let firstWindow = windows.first,
           let serviceManager = windowServiceManagers[firstWindow] {
            serviceManager.focusInputPublisher.send()
            print("🎯 Focused input bar for window '\(firstWindow.title)'")
        }
    }
    
    /// Returns all overlay windows that are visible on the current desktop space.
    ///
    /// This method provides space-aware window filtering for the floating button
    /// to determine if there are existing windows on the user's current space.
    ///
    /// Used by:
    /// - `FloatingButtonManager` to check for existing windows before showing prompt
    /// - Space-aware window management throughout the app
    ///
    /// Process:
    /// 1. Gets all overlay windows from this controller
    /// 2. Filters to only visible, non-miniaturized windows
    /// 3. Uses SpaceDetector to check if each window is on current space
    /// 4. Returns filtered list of space-visible windows
    ///
    /// - Returns: Array of NSWindows visible on current desktop space
    public func getWindowsOnCurrentSpace() -> [NSWindow] {
        let allOverlayWindows = getAllWindows()
        let visibleWindows = allOverlayWindows.filter { $0.isVisible && !$0.isMiniaturized }
        
        // Filter to only windows on current space
        let spaceVisibleWindows = visibleWindows.filter { window in
            SpaceDetector.shared.isWindowOnCurrentSpace(window)
        }
        
        print("🏠 Space-aware window check: \(allOverlayWindows.count) total, \(visibleWindows.count) visible, \(spaceVisibleWindows.count) on current space")
        
        return spaceVisibleWindows
    }
    
    /// Brings the most recently used window on the current space to the front.
    ///
    /// This method implements the core functionality for the floating button's
    /// space-aware behavior. When there are existing windows on the current space,
    /// it brings the most recent one to the front instead of showing the prompt.
    ///
    /// Used by:
    /// - `FloatingButtonManager` when windows exist on current space
    ///
    /// Process:
    /// 1. Gets windows on current space
    /// 2. Selects the first (most recent) window
    /// 3. Brings it to front and makes it key
    /// 4. Focuses the unified input bar for immediate typing
    ///
    /// - Returns: true if a window was brought to front, false if no windows on current space
    @discardableResult
    public func bringCurrentSpaceWindowToFront() -> Bool {
        let windowsOnSpace = getWindowsOnCurrentSpace()
        
        guard let mostRecentWindow = windowsOnSpace.first else {
            print("🏠 No windows on current space - cannot bring to front")
            return false
        }
        
        print("🏠 Bringing window '\(mostRecentWindow.title)' to front on current space")
        
        // Bring window to front and make it key
        mostRecentWindow.orderFront(nil)
        mostRecentWindow.makeKeyAndOrderFront(nil)
        
        // Activate the app to ensure it's in the foreground
        NSApp.activate(ignoringOtherApps: true)
        
        // Focus the unified input bar for immediate typing
        focusInputBar()
        
        return true
    }

    /// Initializes the overlay controller.
    ///
    /// Called by:
    /// - `AppDelegate` during application startup
    ///
    /// Sets up:
    /// - Window notifications for hibernation support
    /// - Debug logging for lifecycle tracking
    override init() {
        super.init()
        let address = Unmanaged.passUnretained(self).toOpaque()
        print("🟢 [\(Date().timeIntervalSince1970)] OverlayController INIT \(instanceId) at \(address)")
        setupWindowNotifications()
    }
    
    /// Cleans up resources when controller is deallocated.
    ///
    /// Cleanup includes:
    /// - Invalidating all loading timers
    /// - Removing notification observers
    /// - Clearing all window references
    ///
    /// Note: Windows clean up their own WebViews in their close() method.
    deinit {
        print("🔴 [\(Date().timeIntervalSince1970)] OverlayController DEINIT \(instanceId) starting")
        
        // Clean up all timers
        print("🧹 [\(Date().timeIntervalSince1970)] Invalidating \(loadingTimers.count) timers")
        for timer in loadingTimers.values {
            timer.invalidate()
        }
        loadingTimers.removeAll()
        
        // Remove all notification observers
        print("🧹 [\(Date().timeIntervalSince1970)] Removing notification observers")
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default.removeObserver(self)
        
        print("✅ [\(Date().timeIntervalSince1970)] OverlayController DEINIT \(instanceId) complete")
    }
    
    /// Sets up window notifications for hibernation support and app focus tracking.
    ///
    /// Observes:
    /// - didBecomeKey: Restores hibernated windows
    /// - didResignKey: Hibernates inactive windows
    /// - didBecomeActive: Updates app focus state for focus indicators
    /// - willResignActive: Updates app focus state for focus indicators
    ///
    /// This enables automatic resource management as users switch between windows
    /// and provides app-level focus state for UI focus indicators.
    private func setupWindowNotifications() {
        // Window-level notifications for hibernation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )
        
        // App-level notifications for focus indicators
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive(_:)),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
        
        // Observe reload overlay UI notification from SettingsManager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadOverlayUI(_:)),
            name: .reloadOverlayUI,
            object: nil
        )
        
        // Note: isAppFocused starts as false and will be set when app becomes active
        // This prevents crash on macOS 15.1 where NSApp.isActive isn't ready during init
        
        // Note: allServicesDidLoad is now handled via Combine subscription in createNormalWindow
    }

    // MARK: - Public API
    
    /// Shows a new window without a prompt.
    ///
    /// Called by:
    /// - `AppDelegate` when floating button is clicked
    /// - `AppDelegate` when global hotkey is pressed
    func showOverlay() {
        showOverlay(with: nil)
    }

    /// Shows a new window with optional prompt execution.
    ///
    /// Called by:
    /// - `showOverlay()` without prompt
    /// - Direct API calls with prompt
    ///
    /// This method:
    /// 1. Creates a new window in the current space
    /// 2. Optionally executes a prompt after window loads
    ///
    /// Note: Despite the name "overlay", this creates normal windows.
    /// The overlay mode (full-screen) is toggled with ESC key.
    func showOverlay(with prompt: String?) {
        // Always create a new window in the current space
        // This prevents switching to other spaces
        createNormalWindow()
        
        if let p = prompt, let window = windows.last, 
           let windowServiceManager = windowServiceManagers[window] {
            DispatchQueue.main.asyncAfter(deadline: .now() + UITimings.windowActivationDelay) {
                windowServiceManager.executePrompt(p)
            }
        }
    }
    
    // MARK: - Window Creation
    
    /// Window dimension constants.
    private enum WindowDimensions {
        /// Default width for new windows
        static let defaultWidth: CGFloat = 1200
        
        /// Default height for new windows
        static let defaultHeight: CGFloat = 800
    }
    
    /// Creates a new normal (non-fullscreen) window.
    ///
    /// Called by:
    /// - `showOverlay()` to create new windows
    ///
    /// This method:
    /// 1. Creates dedicated ServiceManager for WebView isolation
    /// 2. Sets up loading overlay subscription
    /// 3. Creates window centered on current screen
    /// 4. Configures window properties and delegates
    /// 5. Creates SwiftUI content view
    /// 6. Shows loading overlay until services load
    ///
    /// Each window gets its own:
    /// - ServiceManager instance
    /// - Set of WebViews
    /// - BrowserViewControllers
    /// - ContentView instance
    private func createNormalWindow() {
        // Create a dedicated ServiceManager for this window
        let windowServiceManager = ServiceManager()
        
        // Subscribe to areAllServicesLoaded publisher
        windowServiceManager.$areAllServicesLoaded
            .sink { [weak self, weak windowServiceManager] isLoaded in
                guard isLoaded, let self = self, let serviceManager = windowServiceManager else { return }
                
                // Find the window for this ServiceManager
                for (window, manager) in self.windowServiceManagers {
                    if manager === serviceManager {
                        self.hideLoadingOverlay(for: window)
                        break
                    }
                }
            }
            .store(in: &cancellables)
        
        // Debug logging for new window creation
        if LoggingSettings.shared.debugPrompts {
            WebViewLogger.shared.log("🪟 New window created with dedicated ServiceManager", for: "system", type: .info)
        }
        
        guard let screen = NSScreen.screenWithMouse() ?? NSScreen.main ?? NSScreen.screens.first else {
            print("OverlayController: No screens available")
            return
        }
        
        let windowRect = NSRect(
            x: screen.frame.midX - WindowDimensions.defaultWidth/2,
            y: screen.frame.midY - WindowDimensions.defaultHeight/2,
            width: WindowDimensions.defaultWidth,
            height: WindowDimensions.defaultHeight
        )
        
        let window = OverlayWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // CRITICAL: Prevent the window from deallocating itself on close
        // This aligns window behavior with ARC and prevents EXC_BAD_ACCESS crashes
        window.isReleasedWhenClosed = false
        
        window.overlayController = self
        windows.append(window)
        
        // Update activation policy now that we have a window
        print("🪟 showOverlay: calling updateActivationPolicy")
        print("🪟 delegate class:", String(describing: appDelegate))
        if let appDelegate = self.appDelegate {
            appDelegate.updateActivationPolicy(source: "OverlayController.showOverlay")
        }
        
        // Store the window-specific ServiceManager
        windowServiceManagers[window] = windowServiceManager
        
        // Set window delegate to handle cleanup before close
        window.delegate = self

        // Configure window for full-size content view with visible buttons
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.minSize = NSSize(width: 800, height: 600)
        window.level = .normal
        // Don't use canJoinAllSpaces - we want window to stay in current space
        // By adding .moveToActiveSpace, we ensure new windows appear on the active
        // space rather than forcing a switch to a space with an existing window.
        window.collectionBehavior = [.managed, .fullScreenPrimary, .moveToActiveSpace]
        window.isMovable = true
        // Make window background transparent so visual effect shows through
        window.backgroundColor = NSColor.clear

        let containerView = NSView(frame: window.contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]
        window.contentView = containerView
        
        // Add visual effect background to entire window
        let backgroundEffectView = NSVisualEffectView(frame: containerView.bounds)
        backgroundEffectView.material = .hudWindow
        backgroundEffectView.blendingMode = .behindWindow
        backgroundEffectView.state = .active
        backgroundEffectView.autoresizingMask = [.width, .height]
        containerView.addSubview(backgroundEffectView)

        setupBrowserViews(in: containerView, using: windowServiceManager, for: window)
        
        // Add loading overlay
        setupLoadingOverlay(for: window, in: containerView)
        
        // Register for appearance change notifications
        DistributedNotificationCenter.default.addObserver(
            self, 
            selector: #selector(appearanceChanged(_:)), 
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), 
            object: nil
        )

        // Activate the app to bring it to foreground (essential for LSUIElement apps)
        NSApp.activate(ignoringOtherApps: true)
        
        // Use gentle activation pattern to prevent WebView disruption
        window.orderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeKey()
        }
        
        // Focus the input field after all web views have loaded
        // This delay allows web views to do their initial setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            windowServiceManager.focusInputPublisher.send()
        }
    }
    
    private func setupBrowserViews(in containerView: NSView, using windowServiceManager: ServiceManager, for window: NSWindow) {
        let sortedServices = windowServiceManager.activeServices.sorted { $0.order < $1.order }
        
        var browserViewControllers: [BrowserViewController] = []
        var browserViews: [NSView] = []
        
        for (index, service) in sortedServices.enumerated() {
            // Handle local services with LocalChatView
            if case .local(let modelPath, _) = service.backend {
                let chatView = LocalChatView(modelPath: modelPath)
                let hostingController = NSHostingController(rootView: chatView)
                
                let view = hostingController.view
                view.translatesAutoresizingMaskIntoConstraints = false
                
                view.wantsLayer = true
                view.layer?.cornerRadius = 8
                view.layer?.masksToBounds = true
                
                browserViews.append(view)
                self.localViewControllers[service.id] = hostingController
                
                print("✅ Created LocalChatView for \(service.name)")
                continue // Skip to the next service in the loop
            }
            
            if let webService = windowServiceManager.webServices[service.id] {
                let webView = webService.webView
                let isFirstService = index == 0
                
                // Pass app focus publisher to BrowserViewController for proper focus indicator binding
                let controller = BrowserViewController(
                    webView: webView, 
                    service: service, 
                    isFirstService: isFirstService,
                    appFocusPublisher: self.$isAppFocused.eraseToAnyPublisher()
                )
                browserViewControllers.append(controller)
                
                // Get the BrowserView directly - no wrapper container
                let browserView = controller.view
                browserView.translatesAutoresizingMaskIntoConstraints = false
                
                // Add corner radius styling back to BrowserView since no container
                browserView.wantsLayer = true
                browserView.layer?.cornerRadius = 8
                browserView.layer?.masksToBounds = true
                
                browserViews.append(browserView)
                
                // Register the controller with ServiceManager for delegate handoff
                windowServiceManager.browserViewControllers[service.id] = controller
                
                print("✅ [DIRECT LAYOUT] Created BrowserView directly for \(service.name)")
            }
        }
        
        // Store controllers for this window
        windowBrowserViewControllers[window] = browserViewControllers
        
        // DIRECT PATTERN: Put BrowserView instances directly into NSStackView (bb49011 pattern)
        let browserStackView = NSStackView(views: browserViews)
        browserStackView.distribution = .fillEqually
        browserStackView.orientation = .horizontal
        browserStackView.spacing = 20
        browserStackView.translatesAutoresizingMaskIntoConstraints = false
        browserStackView.identifier = NSUserInterfaceItemIdentifier("browserStackView")
        
        // Create explicit height constraints: each BrowserView.height == browserStackView.height
        // This is the missing piece - horizontal stack views don't propagate height automatically
        for browserView in browserViews {
            browserView.heightAnchor.constraint(equalTo: browserStackView.heightAnchor).isActive = true
        }
        
        // Create the UnifiedInputBar SwiftUI view with window-specific ServiceManager
        let inputBar = UnifiedInputBar(serviceManager: windowServiceManager, overlayController: self)
        let inputBarHostingView = NSHostingView(rootView: inputBar)
        inputBarHostingView.translatesAutoresizingMaskIntoConstraints = false
        self.inputBarHostingView = inputBarHostingView
        
        // Add browser stack and input bar on top of the background effect view
        containerView.addSubview(browserStackView)
        containerView.addSubview(inputBarHostingView)
        
        print("✅ [DIRECT LAYOUT] \(browserViews.count) BrowserViews added directly to stack")
        
        let constraints = [
            // Browser stack with margins
            browserStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 0),
            browserStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            browserStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            browserStackView.bottomAnchor.constraint(equalTo: inputBarHostingView.topAnchor),
            
            // Input bar full width
            inputBarHostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            inputBarHostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            inputBarHostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            inputBarHostingView.heightAnchor.constraint(equalToConstant: 94)
        ]
        NSLayoutConstraint.activate(constraints)
        stackViewConstraints = constraints
        
        
        // Focus indicators are now handled individually by each BrowserViewController
        // Each BrowserViewController manages its own focus indicator with proper app focus binding
    }
    

    func hideOverlay() {
        // Close all windows
        for window in windows {
            window.close()
        }
        windows.removeAll()
        // Clean up all window-specific ServiceManagers and controllers
        windowServiceManagers.removeAll()
        windowBrowserViewControllers.removeAll()
        // Clean up hibernation data
        windowSnapshots.removeAll()
        hibernatedWindows.removeAll()
    }
    
    func removeWindow(_ window: OverlayWindow) {
        print("🗑 [\(Date().timeIntervalSince1970)] OverlayController.removeWindow called for window")
        
        // Guard against multiple cleanup calls
        guard windows.contains(where: { $0 == window }) else {
            print("⚠️ [\(Date().timeIntervalSince1970)] Window already removed, skipping cleanup")
            return
        }
        
        // Remove window from array
        windows.removeAll { $0 == window }
        print("📊 [\(Date().timeIntervalSince1970)] Remaining windows: \(windows.count)")
        
        // Update activation policy now that window count may have changed
        // Use DispatchQueue.main.async to defer policy update to next run loop
        // This ensures the window is fully closed before evaluating policy
        DispatchQueue.main.async {
            print("🪟 removeWindow: calling updateActivationPolicy")
            print("🪟 delegate class:", String(describing: self.appDelegate))
            if let appDelegate = self.appDelegate {
                appDelegate.updateActivationPolicy(source: "OverlayController.closeWindow")
            }
        }
        
        // Note: WebView cleanup is now handled in windowWillClose delegate method
        // This ensures script message handlers are removed before deallocation
        
        // Clean up view controllers for this window
        windowBrowserViewControllers.removeValue(forKey: window)
        
        // Clean up hibernation data
        windowSnapshots.removeValue(forKey: window)
        hibernatedWindows.remove(window)
        
        // Clean up loading overlay data
        loadingTimers[window]?.invalidate()
        loadingTimers.removeValue(forKey: window)
        loadingOverlayViews[window]?.removeFromSuperview()
        loadingOverlayViews.removeValue(forKey: window)
        loadingOverlayOpacities.removeValue(forKey: window)
        hidingOverlays.remove(window)
        
        print("✅ [\(Date().timeIntervalSince1970)] removeWindow complete")
    }
    
    private func updateBackgroundColorForAppearance() {
        // Window now uses visual effect background instead of solid color
    }
    
    @objc private func appearanceChanged(_ notification: Notification) {
        updateBackgroundColorForAppearance()
    }
    
    // MARK: - Window Hibernation
    
    @objc func windowDidBecomeKey(_ notification: Notification) {
        // Only handle OverlayWindow instances, not PromptWindow
        guard let window = notification.object as? OverlayWindow,
              windows.contains(where: { $0 == window }) else {
            // If this is not an OverlayWindow (e.g., PromptWindow), main windows lose focus
            isMainWindowFocused = false
            return
        }
        
        // A main window gained key status
        isMainWindowFocused = true
        
        // Restore this window if it was hibernated
        if hibernatedWindows.contains(window) {
            restoreWindow(window)
        }
        
        // Hibernate other OverlayWindows when this one gains focus
        // This ensures only one full window is active at a time
        for otherWindow in windows where otherWindow != window {
            if otherWindow.isVisible && !hibernatedWindows.contains(otherWindow) {
                hibernateWindow(otherWindow)
            }
        }
    }
    
    /// Handles window losing key status.
    ///
    /// Note: Hibernation is NOT triggered here anymore.
    /// Windows only hibernate when another Hyperchat window gains focus.
    /// This prevents unwanted hibernation when:
    /// - Prompt window appears
    /// - User switches to other apps
    /// - System dialogs appear
    @objc func windowDidResignKey(_ notification: Notification) {
        // Check if a main window lost key status
        if let window = notification.object as? OverlayWindow,
           windows.contains(where: { $0 == window }) {
            // A main window resigned key status
            // Don't immediately set isMainWindowFocused = false because another main window might become key
            // The windowDidBecomeKey handler will update the state appropriately
        }
        
        // Don't automatically hibernate when window loses focus
        // Hibernation now only happens when another OverlayWindow gains focus
        // This prevents hibernation when the prompt window appears or when switching to other apps
    }
    
    // MARK: - App Focus Handling
    
    /// Handles application becoming active (gaining focus).
    ///
    /// Called when:
    /// - User clicks on the app or its windows
    /// - User switches to the app via Cmd+Tab
    /// - User activates the app from Dock
    ///
    /// Updates the `isAppFocused` published property to `true`, which triggers
    /// focus indicator borders to become visible in UI components throughout the app.
    @objc func applicationDidBecomeActive(_ notification: Notification) {
        print("🔵 [APP FOCUS DEBUG] App became active - focus indicators enabled, isAppFocused: false -> true")
        isAppFocused = true
    }
    
    /// Handles application losing active status (losing focus).
    ///
    /// Called when:
    /// - User switches to another application
    /// - User clicks on desktop or Finder
    /// - Another app becomes active
    ///
    /// Updates the `isAppFocused` published property to `false`, which triggers
    /// focus indicator borders to become hidden in UI components throughout the app.
    @objc func applicationWillResignActive(_ notification: Notification) {
        print("🔴 [APP FOCUS DEBUG] App resigned active - focus indicators disabled, isAppFocused: true -> false")
        isAppFocused = false
    }
    
    // MARK: - Window Hibernation
    
    /// Hibernates a window to reduce resource usage.
    ///
    /// Called when:
    /// - Another Hyperchat window gains focus
    ///
    /// Hibernation process:
    /// 1. Capture screenshot of current window content
    /// 2. Overlay screenshot on top of WebViews
    /// 3. Pause JavaScript execution in all WebViews
    /// 4. Hide WebViews to stop GPU rendering
    ///
    /// Benefits:
    /// - Reduces CPU usage to near zero
    /// - Frees GPU resources
    /// - Maintains visual continuity
    /// - Instant restoration when reactivated
    ///
    /// Implementation in:
    /// - `ServiceManager.pauseAllWebViews()`
    private func hibernateWindow(_ window: NSWindow) {
        guard let serviceManager = windowServiceManagers[window],
              !hibernatedWindows.contains(window) else { return }
        
        autoreleasepool {
            // Capture screenshot of current content
            if let contentView = window.contentView,
               let imageRep = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) {
                contentView.cacheDisplay(in: contentView.bounds, to: imageRep)
                let snapshot = NSImage(size: contentView.bounds.size)
                snapshot.addRepresentation(imageRep)
                
                // Create and add snapshot view
                let snapshotView = NSImageView(frame: contentView.bounds)
                snapshotView.image = snapshot
                snapshotView.imageScaling = .scaleAxesIndependently
                snapshotView.autoresizingMask = [.width, .height]
                snapshotView.wantsLayer = true
                contentView.addSubview(snapshotView)
                
                windowSnapshots[window] = snapshotView
            }
            
            // Pause all WebViews to free resources
            serviceManager.pauseAllWebViews()
            hibernatedWindows.insert(window)
            
            print("🛌 Hibernated window with \(serviceManager.activeServices.count) services")
        }
    }
    
    /// Restores a hibernated window to active state.
    ///
    /// Called when:
    /// - Window gains focus (becomes key)
    ///
    /// Restoration process:
    /// 1. Remove screenshot overlay
    /// 2. Restore JavaScript timer functions
    /// 3. Show WebViews for GPU rendering
    /// 4. Force small scroll to trigger re-render
    ///
    /// The window becomes immediately interactive without reload.
    ///
    /// Implementation in:
    /// - `ServiceManager.resumeAllWebViews()`
    private func restoreWindow(_ window: NSWindow) {
        guard let serviceManager = windowServiceManagers[window],
              hibernatedWindows.contains(window) else { return }
        
        // Remove snapshot overlay
        if let snapshotView = windowSnapshots[window] {
            snapshotView.removeFromSuperview()
            windowSnapshots.removeValue(forKey: window)
        }
        
        // Resume all WebViews
        serviceManager.resumeAllWebViews()
        hibernatedWindows.remove(window)
        
        print("⏰ Restored window with \(serviceManager.activeServices.count) services")
    }
    
    // MARK: - Service Reload
    
    /// Handles notification to reload overlay UI when services are enabled/disabled.
    ///
    /// Called by:
    /// - ServiceManager when detecting service enable/disable changes
    ///
    /// Process:
    /// 1. Iterates through all active windows
    /// 2. Recreates browser views with updated service list
    /// 3. Maintains window state and focus
    ///
    /// This ensures the UI instantly reflects settings changes without
    /// requiring a new request or window recreation.
    @objc private func reloadOverlayUI(_ notification: Notification) {
        print("🔄 Received reloadOverlayUI notification, refreshing all windows...")
        
        // Refresh browser views for all windows
        for window in windows {
            guard let serviceManager = windowServiceManagers[window],
                  let contentView = window.contentView else { continue }
            
            print("🔄 Refreshing browser views for window...")
            
            // Find and remove the existing browser stack view
            if let browserStackView = contentView.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("browserStackView") }) {
                browserStackView.removeFromSuperview()
            }
            
            // Remove the input bar hosting view
            if let inputBar = self.inputBarHostingView {
                inputBar.removeFromSuperview()
            }
            
            // Deactivate existing constraints
            NSLayoutConstraint.deactivate(stackViewConstraints)
            stackViewConstraints.removeAll()
            
            // Clear browser view controllers for this window
            windowBrowserViewControllers.removeValue(forKey: window)
            
            // Recreate browser views with updated services
            setupBrowserViews(in: contentView, using: serviceManager, for: window)
            
            print("✅ Browser views refreshed for window")
        }
        
        print("✅ All windows refreshed")
    }
    
    // MARK: - Loading Overlay Management
    
    /// Loading overlay timing constants.
    private enum LoadingTimings {
        /// Maximum duration to show loading overlay for first window
        static let firstWindowMaxDuration: TimeInterval = 7.0
        
        /// Brief delay before hiding overlay for subsequent windows
        static let subsequentWindowDelay: TimeInterval = 0.1
    }
    
    /// Sets up the loading overlay for a window.
    ///
    /// Called by:
    /// - `createNormalWindow()` after window creation
    ///
    /// The loading overlay:
    /// - Shows "Hyperchat" branding during service loading
    /// - Uses typewriter animation for first window
    /// - Shows static text for subsequent windows
    /// - Automatically hides when services load or timer expires
    ///
    /// First window: Up to 7 seconds with typewriter effect
    /// Subsequent windows: Brief flash then fade out
    private func setupLoadingOverlay(for window: NSWindow, in containerView: NSView) {
        // Create SwiftUI binding for loading overlay opacity
        loadingOverlayOpacities[window] = 1.0
        
        let loadingView = LoadingOverlayView(
            opacity: Binding(
                get: { [weak self] in self?.loadingOverlayOpacities[window] ?? 0 },
                set: { [weak self] in self?.loadingOverlayOpacities[window] = $0 }
            ),
            isFirstWindow: isFirstWindowLoad
        )
        
        let hostingView = NSHostingView(rootView: loadingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostingView)
        
        // Constrain to fill entire window
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        loadingOverlayViews[window] = hostingView
        
        // Set up timer and behavior based on whether this is first window or subsequent
        if isFirstWindowLoad {
            isFirstWindowLoad = false
            
            // For first window: maximum duration timer
            let timer = Timer.scheduledTimer(withTimeInterval: LoadingTimings.firstWindowMaxDuration, repeats: false) { [weak self, weak window] _ in
                guard let self = self, let window = window else { return }
                self.hideLoadingOverlay(for: window)
            }
            loadingTimers[window] = timer
        } else {
            // For subsequent windows: show briefly then start fading
            DispatchQueue.main.asyncAfter(deadline: .now() + LoadingTimings.subsequentWindowDelay) { [weak self, weak window] in
                guard let self = self, let window = window else { return }
                self.hideLoadingOverlay(for: window)
            }
        }
    }
    
    /// Hides the loading overlay with fade animation.
    ///
    /// Called by:
    /// - `setupLoadingOverlay()` timer expiration
    /// - ServiceManager when all services load
    ///
    /// Animation:
    /// - 2 second fade out with easeOut curve
    /// - 60 FPS timer-based animation
    /// - Removes overlay after animation completes
    private func hideLoadingOverlay(for window: NSWindow) {
        // Check if already hiding this overlay
        guard !hidingOverlays.contains(window) else {
            print("🎬 Loading overlay already hiding for window, skipping duplicate animation")
            return
        }
        
        // Mark as hiding
        hidingOverlays.insert(window)
        
        // Cancel any existing timer
        loadingTimers[window]?.invalidate()
        loadingTimers.removeValue(forKey: window)
        
        // Animation constants
        let animationDuration: TimeInterval = UITimings.loadingFadeOutDuration * 2.86 // ~2.0 seconds
        let frameRate: TimeInterval = 60.0 // 60 FPS for smooth animation
        let totalFrames = Int(animationDuration * frameRate)
        var currentFrame = 0
        
        let animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / frameRate, repeats: true) { [weak self, weak window] timer in
            guard let self = self, let window = window else {
                timer.invalidate()
                return
            }
            
            currentFrame += 1
            let progress = Double(currentFrame) / Double(totalFrames)
            
            // Apply easeOut curve: 1 - (1 - t)^2
            let easeOutProgress = 1.0 - pow(1.0 - progress, 2.0)
            
            // Update opacity
            self.loadingOverlayOpacities[window] = 1.0 - easeOutProgress
            
            // Force SwiftUI to update
            if let hostingView = self.loadingOverlayViews[window] {
                hostingView.rootView = LoadingOverlayView(
                    opacity: Binding(
                        get: { [weak self] in self?.loadingOverlayOpacities[window] ?? 0 },
                        set: { [weak self] in self?.loadingOverlayOpacities[window] = $0 }
                    ),
                    isFirstWindow: false  // Animation already started, this is just updating opacity
                )
            }
            
            if currentFrame >= totalFrames {
                timer.invalidate()
                // Remove the view after animation completes
                DispatchQueue.main.async { [weak self, weak window] in
                    guard let self = self, let window = window else { return }
                    self.loadingOverlayViews[window]?.removeFromSuperview()
                    self.loadingOverlayViews.removeValue(forKey: window)
                    self.loadingOverlayOpacities.removeValue(forKey: window)
                    // Remove from hiding set
                    self.hidingOverlays.remove(window)
                }
            }
        }
        
        // Store the animation timer so it can be cancelled if needed
        loadingTimers[window] = animationTimer
    }
    
    
    // MARK: - NSWindowDelegate
    
    func windowDidResize(_ notification: Notification) {
        // Focus indicators are now handled by individual BrowserViewController instances
        // Each BrowserViewController automatically manages its own focus indicator positioning
    }
    
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let serviceManager = windowServiceManagers[window] else { return }
        
        print("🚨 [\(Date().timeIntervalSince1970)] windowWillClose - Starting comprehensive WebView cleanup BEFORE window closes")
        
        // Wrap cleanup in autoreleasepool to ensure WebKit's autoreleased objects
        // are released immediately, preventing crashes during run loop drain
        autoreleasepool {
            // Critical: Remove script message handlers BEFORE anything else deallocates
            for (serviceId, webService) in serviceManager.webServices {
                let webView = webService.webView
                let controller = webView.configuration.userContentController
                
                print("🧨 [\(Date().timeIntervalSince1970)] Beginning cleanup for \(serviceId)")
                
                // 1. Stop all activity immediately
                webView.stopLoading()
                
                // 2. Terminate JavaScript environment by loading blank page
                // This unloads the previous page's entire execution context
                webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
                
                // 3. Remove ALL message handlers using centralized names - this prevents the crash
                for handlerName in WebViewFactory.scriptMessageHandlerNames {
                    controller.removeScriptMessageHandler(forName: handlerName)
                }
                
                // 4. Sever delegate connections to prevent callbacks
                webView.navigationDelegate = nil
                webView.uiDelegate = nil
                
                // 5. Remove from view hierarchy
                webView.removeFromSuperview()
                
                print("✅ [\(Date().timeIntervalSince1970)] Cleaned up WebView for \(serviceId)")
            }
            
            // Clean up loading timers for this window
            if let timer = loadingTimers[window] {
                timer.invalidate()
                loadingTimers.removeValue(forKey: window)
            }
            
            // Clean up loading overlay references
            loadingOverlayViews.removeValue(forKey: window)
            loadingOverlayOpacities.removeValue(forKey: window)
            hidingOverlays.remove(window)
            
            // Clean up hibernation references
            windowSnapshots.removeValue(forKey: window)
            hibernatedWindows.remove(window)
            
            // Clean up ServiceManager reference
            windowServiceManagers.removeValue(forKey: window)
            
            // Clean up view controller references
            windowBrowserViewControllers.removeValue(forKey: window)
            
            print("✅ [\(Date().timeIntervalSince1970)] windowWillClose cleanup complete")
        }
    }
}

extension Notification.Name {
    static let overlayDidHide = Notification.Name("overlayDidHide")
}

// MARK: - Focus Indicator for Input Bar

/// Reusable animated glowing border component for focus indication.
///
/// Provides a consistent visual language for focus states using
/// the same pink-to-blue animated gradient pattern as other app components.
private struct InputFocusIndicatorView: View {
    let isVisible: Bool
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    
    @State private var phase: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?
    
    private enum Appearance {
        static let pinkColor = Color(red: 1.0, green: 0.0, blue: 0.8)
        static let blueColor = Color(red: 0.0, green: 0.6, blue: 1.0)
        static let outerGlowOpacity: Double = 0.4
        static let middleGlowOpacity: Double = 0.6
        static let outerGlowBlur: CGFloat = 6
        static let middleGlowBlur: CGFloat = 3
        static let innerGlowBlur: CGFloat = 0.5
        static let outerGlowMultiplier: CGFloat = 1.2
        static let middleGlowMultiplier: CGFloat = 0.8
        static let innerGlowMultiplier: CGFloat = 0.3
        static let gradientRotationDuration: TimeInterval = 3.0
        static let fadeDuration: TimeInterval = 0.2
    }
    
    var body: some View {
        ZStack {
            // Outer glow layer
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Appearance.pinkColor, Appearance.blueColor,
                            Appearance.pinkColor, Appearance.blueColor, Appearance.pinkColor
                        ]),
                        center: .center,
                        startAngle: .degrees(phase),
                        endAngle: .degrees(phase + 360)
                    ),
                    lineWidth: lineWidth * Appearance.outerGlowMultiplier
                )
                .blur(radius: Appearance.outerGlowBlur)
                .opacity(Appearance.outerGlowOpacity)
            
            // Middle glow layer
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Appearance.pinkColor, Appearance.blueColor,
                            Appearance.pinkColor, Appearance.blueColor, Appearance.pinkColor
                        ]),
                        center: .center,
                        startAngle: .degrees(phase),
                        endAngle: .degrees(phase + 360)
                    ),
                    lineWidth: lineWidth * Appearance.middleGlowMultiplier
                )
                .blur(radius: Appearance.middleGlowBlur)
                .opacity(Appearance.middleGlowOpacity)
            
            // Inner sharp layer
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Appearance.pinkColor, Appearance.blueColor,
                            Appearance.pinkColor, Appearance.blueColor, Appearance.pinkColor
                        ]),
                        center: .center,
                        startAngle: .degrees(phase),
                        endAngle: .degrees(phase + 360)
                    ),
                    lineWidth: lineWidth * Appearance.innerGlowMultiplier
                )
                .blur(radius: Appearance.innerGlowBlur)
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: Appearance.fadeDuration), value: isVisible)
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
    
    private func startAnimation() {
        animationTask?.cancel()
        animationTask = Task {
            while !Task.isCancelled {
                withAnimation(.linear(duration: Appearance.gradientRotationDuration)) {
                    phase += 360
                }
                try? await Task.sleep(nanoseconds: UInt64(Appearance.gradientRotationDuration * 1_000_000_000))
            }
        }
    }
    
    private func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }
}

struct UnifiedInputBar: View {
    @ObservedObject var serviceManager: ServiceManager
    @ObservedObject var overlayController: OverlayController
    @FocusState private var isInputFocused: Bool
    @State private var isRefreshHovering = false
    @State private var isSubmitHovering = false
    @State private var showFlameIcon = false
    @State private var isHyperchatIconHovering = false
    
    private var isLoading: Bool {
        serviceManager.loadingStates.values.contains(true)
    }
    
    private func submitWithAnimation() {
        // Trigger flame animation
        withAnimation(.easeInOut(duration: 0.2)) {
            showFlameIcon = true
        }
        
        // Delay execution to ensure animation is visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            serviceManager.executeSharedPrompt()
        }
        
        // Reset icon after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showFlameIcon = false
            }
        }
    }
    
    /// Opens the Settings window when the Hyperchat icon is clicked.
    ///
    /// Called by:
    /// - Hyperchat icon button in the lower left of the main window
    ///
    /// This method uses the same mechanism as the menu bar Settings action,
    /// ensuring consistent behavior across the application.
    private func openSettings() {
        // Simulate Cmd+, keyboard shortcut (same pathway as menu bar)
        NSApp.sendAction(#selector(AppDelegate.showSettings(_:)), to: nil, from: nil)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Hyperchat logo - clickable to open Settings
                Button(action: {
                    openSettings()
                }) {
                    Image("HyperchatIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 62, height: 62)
                        .cornerRadius(13)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .scaleEffect(isHyperchatIconHovering ? 1.05 : 1.0)
                }
                .buttonStyle(.plain)
                .help("Open Hyperchat Settings")
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHyperchatIconHovering = hovering
                    }
                }
                
                // Input field section - fills remaining space
                HStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        if serviceManager.sharedPrompt.isEmpty {
                            Text("Ask your AIs anything")
                                .foregroundColor(.secondary.opacity(0.4))
                                .font(.system(size: 14))
                                .padding(.leading, 20)  // Adjusted to align with cursor
                                .padding(.top, 8)
                        }
                        
                        CustomTextEditor(text: $serviceManager.sharedPrompt, onSubmit: {
                            submitWithAnimation()
                        })
                        .font(.system(size: 14))
                        .frame(minHeight: 47, maxHeight: 47)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .focused($isInputFocused)
                    }
                    .frame(minHeight: 63)
                    
                    // Action buttons
                    HStack(spacing: 8) {
                        if !serviceManager.sharedPrompt.isEmpty {
                            Button(action: {
                                serviceManager.sharedPrompt = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                            .help("Clear input field")
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        Button(action: {
                            submitWithAnimation()
                        }) {
                            ZStack {
                                if !serviceManager.sharedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || showFlameIcon {
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
                        .disabled(serviceManager.sharedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .help("Send Message to All")
                        .animation(.easeInOut(duration: 0.2), value: serviceManager.sharedPrompt.isEmpty)
                        .animation(.easeInOut(duration: 0.2), value: isSubmitHovering)
                        .onHover { hovering in
                            isSubmitHovering = hovering
                        }
                    }
                    .padding(.trailing, 20)
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                )
                .overlay(
                    // Animated focus indicator border
                    InputFocusIndicatorView(
                        isVisible: isInputFocused && overlayController.isAppFocused && overlayController.isMainWindowFocused,
                        cornerRadius: 10,
                        lineWidth: 4
                    )
                )
                .frame(maxWidth: .infinity)
                
                // Refresh button - mirrors the Hyperchat logo
                Button(action: {
                    // Always start new threads with current prompt (may be empty)
                    serviceManager.startNewThreadWithPrompt()
                }) {
                    ZStack {
                        // Background - black on hover, matching logo style
                        if isRefreshHovering {
                            Color.black
                                .cornerRadius(13)
                        } else {
                            Color(NSColor.controlBackgroundColor)
                                .cornerRadius(13)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 13)
                                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        // Plus icon with gradient
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
                        .opacity(1.0)  // 100% opacity
                        .mask(
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .symbolEffect(.pulse.wholeSymbol, isActive: isLoading)
                        )
                    }
                    .frame(width: 62, height: 62)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .scaleEffect(isRefreshHovering ? 1.05 : 1.0)
                }
                .buttonStyle(.plain)
                .help("Start New Chat Thread")
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isRefreshHovering = hovering
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(height: 94)
        }
        .onReceive(serviceManager.focusInputPublisher) { _ in
            isInputFocused = true
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.insertionPointColor = NSColor(red: 1.0, green: 0.0, blue: 0.8, alpha: 1.0)
        
        // Set up for 2 lines
        textView.textContainer?.containerSize = NSSize(width: scrollView.frame.width, height: 36)
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = false
        
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextEditor
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Check if Shift is pressed
                let modifierFlags = NSEvent.modifierFlags
                if modifierFlags.contains(.shift) {
                    // Shift+Enter: Insert newline
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                } else {
                    // Enter alone: Submit
                    parent.onSubmit()
                    return true
                }
            }
            return false
        }
    }
}