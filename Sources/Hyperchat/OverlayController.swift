import Cocoa
import SwiftUI
import WebKit
import Combine

// MARK: - Loading Overlay View

extension Font {
    static func orbitronBold(size: CGFloat) -> Font {
        // Try custom font first, fallback to system font
        return Font.custom("Orbitron-Bold", size: size)
    }
}

struct TypewriterText: View {
    let text: String
    let font: Font
    let tracking: CGFloat
    @State private var revealedCharacters = 0
    
    private let characterDelay: TimeInterval = 0.1
    
    var body: some View {
        Text(text)
            .font(font)
            .tracking(tracking)
            .foregroundStyle(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 1.0, green: 0.0, blue: 0.6), location: 0.0),      // Pink
                        .init(color: Color(red: 0.6, green: 0.2, blue: 0.8), location: 1)     // Purple
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Timer.scheduledTimer(withTimeInterval: characterDelay, repeats: true) { timer in
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
                        .init(color: Color(red: 1.0, green: 0.0, blue: 0.6), location: 0.0),      // Pink
                        .init(color: Color(red: 0.6, green: 0.2, blue: 0.8), location: 1)     // Purple
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
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

class OverlayWindow: NSWindow {
    weak var overlayController: OverlayController?
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

class OverlayController: NSObject, NSWindowDelegate {
    private var windows: [OverlayWindow] = []
    private var isHiding = false
    private let instanceId = UUID().uuidString.prefix(8)
    
    // Per-window ServiceManager instances
    private var windowServiceManagers: [NSWindow: ServiceManager] = [:]
    
    // Per-window BrowserViewController instances
    private var windowBrowserViewControllers: [NSWindow: [BrowserViewController]] = [:]
    
    // Window hibernation support
    private var windowSnapshots: [NSWindow: NSImageView] = [:]
    private var hibernatedWindows: Set<NSWindow> = []
    
    // Loading overlay support
    private var loadingOverlayViews: [NSWindow: NSHostingView<LoadingOverlayView>] = [:]
    private var loadingOverlayOpacities: [NSWindow: Double] = [:]
    private var loadingTimers: [NSWindow: Timer] = [:]
    private var isFirstWindowLoad = true
    private var hidingOverlays: Set<NSWindow> = []
    
    private var stackViewConstraints: [NSLayoutConstraint] = []
    private var inputBarHostingView: NSHostingView<UnifiedInputBar>?
    
    // Combine subscriptions
    private var cancellables: Set<AnyCancellable> = []
    
    // Public accessor for window's ServiceManager
    func serviceManager(for window: NSWindow) -> ServiceManager? {
        return windowServiceManagers[window]
    }

    override init() {
        super.init()
        let address = Unmanaged.passUnretained(self).toOpaque()
        print("🟢 [\(Date().timeIntervalSince1970)] OverlayController INIT \(instanceId) at \(address)")
        setupWindowNotifications()
    }
    
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
    
    private func setupWindowNotifications() {
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
        
        // Note: allServicesDidLoad is now handled via Combine subscription in createNormalWindow
    }

    // Public entry point when no prompt yet
    func showOverlay() {
        showOverlay(with: nil)
    }

    // New unified API
    func showOverlay(with prompt: String?) {
        // Always create a new window in the current space
        // This prevents switching to other spaces
        createNormalWindow()
        
        if let p = prompt, let window = windows.last, 
           let windowServiceManager = windowServiceManagers[window] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                windowServiceManager.executePrompt(p)
            }
        }
    }
    
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
        
        let windowWidth: CGFloat = 1200
        let windowHeight: CGFloat = 800
        let windowRect = NSRect(
            x: screen.frame.midX - windowWidth/2,
            y: screen.frame.midY - windowHeight/2,
            width: windowWidth,
            height: windowHeight
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
        window.collectionBehavior = [.managed, .fullScreenPrimary]
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
            if let webService = windowServiceManager.webServices[service.id] {
                let webView = webService.webView
                let isFirstService = index == 0
                let controller = BrowserViewController(webView: webView, service: service, isFirstService: isFirstService)
                browserViewControllers.append(controller)
                browserViews.append(controller.view)
                
                // Register the controller with ServiceManager for delegate handoff
                windowServiceManager.browserViewControllers[service.id] = controller
            }
        }
        
        // Store controllers for this window
        windowBrowserViewControllers[window] = browserViewControllers
        
        let browserStackView = NSStackView(views: browserViews)
        browserStackView.distribution = .fillEqually
        browserStackView.orientation = .horizontal
        browserStackView.spacing = 20
        browserStackView.translatesAutoresizingMaskIntoConstraints = false
        browserStackView.identifier = NSUserInterfaceItemIdentifier("browserStackView")
        
        // Create the UnifiedInputBar SwiftUI view with window-specific ServiceManager
        let inputBar = UnifiedInputBar(serviceManager: windowServiceManager)
        let inputBarHostingView = NSHostingView(rootView: inputBar)
        inputBarHostingView.translatesAutoresizingMaskIntoConstraints = false
        self.inputBarHostingView = inputBarHostingView
        
        // Add browser stack and input bar on top of the background effect view
        containerView.addSubview(browserStackView)
        containerView.addSubview(inputBarHostingView)
        
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
              windows.contains(where: { $0 == window }) else { return }
        
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
    
    @objc func windowDidResignKey(_ notification: Notification) {
        // Don't automatically hibernate when window loses focus
        // Hibernation now only happens when another OverlayWindow gains focus
        // This prevents hibernation when the prompt window appears or when switching to other apps
    }
    
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
    
    // MARK: - Loading Overlay Management
    
    private func setupLoadingOverlay(for window: NSWindow, in containerView: NSView) {
        // Create SwiftUI wrapper for binding
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
            
            // For first window: 7-second maximum timer
            let timer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: false) { [weak self, weak window] _ in
                guard let self = self, let window = window else { return }
                self.hideLoadingOverlay(for: window)
            }
            loadingTimers[window] = timer
        } else {
            // For subsequent windows: show briefly then start fading
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak window] in
                guard let self = self, let window = window else { return }
                self.hideLoadingOverlay(for: window)
            }
        }
    }
    
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
        
        // Animate opacity using Timer for smooth easeOut curve
        let animationDuration: TimeInterval = 2.0
        let frameRate: TimeInterval = 60.0 // 60 FPS
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

struct UnifiedInputBar: View {
    @ObservedObject var serviceManager: ServiceManager
    @FocusState private var isInputFocused: Bool
    @State private var isRefreshHovering = false
    @State private var isSubmitHovering = false
    @State private var showFlameIcon = false
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Hyperchat logo
                Image("HyperchatIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 62, height: 62)
                    .cornerRadius(13)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                
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
                                        gradient: Gradient(colors: [
                                            Color(red: 0.0, green: 0.6, blue: 1.0),  // Blue
                                            Color(red: 1.0, green: 0.0, blue: 0.8)   // Pink/Magenta
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
                            gradient: Gradient(colors: [
                                Color(red: 0.0, green: 0.6, blue: 1.0),  // Blue
                                Color(red: 1.0, green: 0.0, blue: 0.8)   // Pink/Magenta
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