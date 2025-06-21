import Cocoa
import SwiftUI

class OverlayWindow: NSWindow {
    weak var overlayController: OverlayController?

    override var canBecomeKey: Bool { true }
    
    // Allow window to be moved by dragging anywhere
    override var isMovableByWindowBackground: Bool {
        get { return true }
        set { }
    }

    override func keyDown(with event: NSEvent) {
        print("🔵 OverlayWindow.keyDown: keyCode=\(event.keyCode)")
        if event.keyCode == 53 { // ESC key
            print("🔵 ESC key detected, isInOverlayMode=\(overlayController?.isInOverlayMode ?? false)")
            // Only handle ESC if we're in overlay mode
            if overlayController?.isInOverlayMode == true {
                print("🔵 Calling exitFullScreenOverlay()")
                overlayController?.exitFullScreenOverlay()
            }
        } else if event.keyCode == 45 && event.modifierFlags.contains(.command) { // Cmd+N
            NotificationCenter.default.post(name: .focusUnifiedInput, object: nil)
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        overlayController?.exitFullScreenOverlay()
    }
    
    override func close() {
        super.close()
        NotificationCenter.default.post(name: .overlayDidHide, object: nil)
    }
}

class OverlayController {
    private var overlayWindow: OverlayWindow?
    var serviceManager: ServiceManager
    private var isHiding = false
    
    // Store the normal window state
    private var savedWindowFrame: NSRect?
    private var savedWindowLevel: NSWindow.Level?
    private var savedStyleMask: NSWindow.StyleMask?
    var isInOverlayMode = false  // Made public for OverlayWindow access
    private var blurView: NSVisualEffectView?
    private var tintView: NSView?
    private var stackViewConstraints: [NSLayoutConstraint] = []
    private var inputBarHostingView: NSHostingView<UnifiedInputBar>?

    init(serviceManager: ServiceManager) {
        self.serviceManager = serviceManager
    }

    // Public entry point when no prompt yet
    func showOverlay() {
        showOverlay(with: nil)
    }

    // New unified API
    func showOverlay(with prompt: String?) {
        if let existingWindow = overlayWindow, existingWindow.isVisible {
            enterFullScreenOverlay()
            if let p = prompt {
                serviceManager.executePrompt(p)
            }
            return
        }

        createNormalWindow()
        
        if let p = prompt {
            enterFullScreenOverlay()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.serviceManager.executePrompt(p)
            }
        }
    }
    
    private func createNormalWindow() {
        // Service manager is now persistent and injected.

        let screen = NSScreen.screenWithMouse() ?? NSScreen.main!
        
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
        window.overlayController = self
        overlayWindow = window

        // Configure window for full-size content view with visible buttons
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.minSize = NSSize(width: 800, height: 600)
        window.level = .normal
        window.collectionBehavior = [.managed, .fullScreenPrimary]
        window.isMovable = true
        // Set contrasting background color based on system appearance
        let systemIsDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        window.backgroundColor = systemIsDarkMode ? 
            NSColor(calibratedWhite: 0.08, alpha: 1.0) : // Very dark gray for dark mode
            NSColor(calibratedWhite: 0.85, alpha: 1.0)   // Medium light gray for light mode

        let containerView = NSView(frame: window.contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]
        window.contentView = containerView

        setupBrowserViews(in: containerView)
        
        // Register for appearance change notifications
        DistributedNotificationCenter.default.addObserver(
            self, 
            selector: #selector(appearanceChanged(_:)), 
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), 
            object: nil
        )

        window.makeKeyAndOrderFront(nil)
    }
    
    private func setupBrowserViews(in containerView: NSView) {
        let sortedServices = serviceManager.activeServices.sorted { $0.order < $1.order }
        let browserViews = sortedServices.compactMap { service in
            serviceManager.webServices[service.id]?.browserView
        }
        
        let browserStackView = NSStackView(views: browserViews)
        browserStackView.distribution = .fillEqually
        browserStackView.orientation = .horizontal
        browserStackView.spacing = 8
        browserStackView.translatesAutoresizingMaskIntoConstraints = false
        browserStackView.identifier = NSUserInterfaceItemIdentifier("browserStackView")
        
        // Create the UnifiedInputBar SwiftUI view
        let inputBar = UnifiedInputBar(serviceManager: serviceManager)
        let inputBarHostingView = NSHostingView(rootView: inputBar)
        inputBarHostingView.translatesAutoresizingMaskIntoConstraints = false
        self.inputBarHostingView = inputBarHostingView
        
        // Create a vertical stack view to hold browser views and input bar
        let mainStackView = NSStackView(views: [browserStackView, inputBarHostingView])
        mainStackView.distribution = .fill
        mainStackView.orientation = .vertical
        mainStackView.spacing = 0
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        mainStackView.identifier = NSUserInterfaceItemIdentifier("mainStackView")
        containerView.addSubview(mainStackView)
        
        let constraints = [
            mainStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 0), // Minimal spacing
            mainStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -5),
            mainStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 2),
            mainStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -2),
            
            // Set input bar height constraint
            inputBarHostingView.heightAnchor.constraint(equalToConstant: 44)
        ]
        NSLayoutConstraint.activate(constraints)
        stackViewConstraints = constraints
    }
    
    private func enterFullScreenOverlay() {
        print("🟢 enterFullScreenOverlay() called")
        guard let window = overlayWindow, !isInOverlayMode else { 
            print("🟢 Enter blocked: window=\(overlayWindow != nil), isInOverlayMode=\(isInOverlayMode)")
            return 
        }
        
        print("🟢 Saving window state...")
        savedWindowFrame = window.frame
        savedWindowLevel = window.level
        savedStyleMask = window.styleMask
        isInOverlayMode = true
        
        let targetScreen = NSScreen.screenWithMouse() ?? window.screen ?? NSScreen.main!
        print("🟢 Target screen: \(targetScreen.frame)")
        
        // Log memory before transition
        logMemoryUsage("Before enter animation")
        
        print("🟢 Starting enter animation...")
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            print("🟢 Setting borderless style")
            window.styleMask = [.borderless]
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.animator().setFrame(targetScreen.frame, display: true)
            
        }, completionHandler: {
            print("🟢 Enter animation completed, adding overlay effects")
            self.addOverlayEffects()
            self.logMemoryUsage("After enter animation")
        })
        
        // Remove the local monitor since we're handling ESC in the window's keyDown method
        // This prevents double handling and potential conflicts
    }
    
    private func logMemoryUsage(_ context: String) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let memoryMB = Double(info.resident_size) / 1024.0 / 1024.0
            print("💾 Memory usage (\(context)): \(String(format: "%.1f", memoryMB)) MB")
        }
    }
    
    private func addOverlayEffects() {
        guard let window = overlayWindow, let contentView = window.contentView else { return }
        guard let stackView = contentView.subviews.first(where: { 
            $0.identifier == NSUserInterfaceItemIdentifier("mainStackView") 
        }) as? NSStackView else { return }
        
        let blur = NSVisualEffectView(frame: contentView.bounds)
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.autoresizingMask = [.width, .height]
        contentView.addSubview(blur, positioned: .below, relativeTo: stackView)
        self.blurView = blur
        
        let tint = NSView(frame: contentView.bounds)
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        tint.autoresizingMask = [.width, .height]
        contentView.addSubview(tint, positioned: .below, relativeTo: stackView)
        self.tintView = tint
        
        NSLayoutConstraint.deactivate(stackViewConstraints)
        let newConstraints = [
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            
            // Keep the input bar height constraint
            inputBarHostingView?.heightAnchor.constraint(equalToConstant: 44)
        ].compactMap { $0 }
        NSLayoutConstraint.activate(newConstraints)
        stackViewConstraints = newConstraints
    }
    
    func exitFullScreenOverlay() {
        print("🟡 exitFullScreenOverlay() called")
        guard let window = overlayWindow, isInOverlayMode, !isHiding else { 
            print("🟡 Exit blocked: window=\(overlayWindow != nil), isInOverlayMode=\(isInOverlayMode), isHiding=\(isHiding)")
            return 
        }
        
        print("🟡 Starting exit transition...")
        isHiding = true
        
        // Immediately update the flag to prevent re-entry
        isInOverlayMode = false
        
        print("🟡 Removing blur and tint views...")
        blurView?.removeFromSuperview()
        tintView?.removeFromSuperview()
        blurView = nil
        tintView = nil
        
        // ESC monitoring is handled in the window's keyDown method
        
        print("🟡 Updating constraints...")
        if let contentView = window.contentView,
           let stackView = contentView.subviews.first(where: { 
               $0.identifier == NSUserInterfaceItemIdentifier("mainStackView") 
           }) as? NSStackView {
            print("🟡 Deactivating \(stackViewConstraints.count) constraints")
            NSLayoutConstraint.deactivate(stackViewConstraints)
            let newConstraints = [
                stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
                stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
                stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
                stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
                
                // Keep the input bar height constraint
                inputBarHostingView?.heightAnchor.constraint(equalToConstant: 44)
            ].compactMap { $0 }
            print("🟡 Activating \(newConstraints.count) new constraints")
            NSLayoutConstraint.activate(newConstraints)
            stackViewConstraints = newConstraints
        }
        
        // Log WebView states before animation
        print("🟡 Active WebViews: \(serviceManager.activeServices.count)")
        for service in serviceManager.activeServices {
            if let webService = serviceManager.webServices[service.id] {
                let isLoading = webService.browserView.webView.isLoading
                let url = webService.browserView.webView.url?.absoluteString ?? "nil"
                print("🟡   - \(service.name): loading=\(isLoading), url=\(url)")
            }
        }
        
        logMemoryUsage("Before exit animation")
        
        print("🟡 Starting animation...")
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            print("🟡 Setting window properties in animation block")
            if let savedStyle = self.savedStyleMask { 
                print("🟡 Restoring style mask")
                window.styleMask = savedStyle 
            }
            if let savedLevel = self.savedWindowLevel { 
                print("🟡 Restoring window level")
                window.level = savedLevel 
            }
            window.collectionBehavior = [.managed, .fullScreenPrimary]
            
            if let savedFrame = self.savedWindowFrame {
                print("🟡 Animating to saved frame: \(savedFrame)")
                window.animator().setFrame(savedFrame, display: true)
            }
        }, completionHandler: {
            print("🟡 Animation completed")
            self.logMemoryUsage("After exit animation")
            self.isHiding = false
            // Remove title - using borderless window
            // Make sure the window can receive key events again
            print("🟡 Making window key and ordering front")
            window.makeKeyAndOrderFront(nil)
            print("🟡 exitFullScreenOverlay() completed")
            
            // Final WebView state check
            print("🟡 Final WebView states:")
            for service in self.serviceManager.activeServices {
                if let webService = self.serviceManager.webServices[service.id] {
                    let isLoading = webService.browserView.webView.isLoading
                    print("🟡   - \(service.name): loading=\(isLoading)")
                }
            }
        })
    }

    func hideOverlay() {
        // This function is now only responsible for closing the window entirely.
        // It should not be called when just exiting full-screen mode.
        overlayWindow?.close() // This will trigger the close logic in OverlayWindow
        overlayWindow = nil
    }
    
    private func updateBackgroundColorForAppearance() {
        guard let window = overlayWindow else { return }
        let systemIsDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        window.backgroundColor = systemIsDarkMode ? 
            NSColor(calibratedWhite: 0.08, alpha: 1.0) : 
            NSColor(calibratedWhite: 0.85, alpha: 1.0)
        
        // Update tint view for overlay mode if present
        if let tintView = tintView {
            tintView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        }
    }
    
    @objc private func appearanceChanged(_ notification: Notification) {
        updateBackgroundColorForAppearance()
    }
}

extension Notification.Name {
    static let overlayDidHide = Notification.Name("overlayDidHide")
    static let focusUnifiedInput = Notification.Name("focusUnifiedInput")
}

struct UnifiedInputBar: View {
    @ObservedObject var serviceManager: ServiceManager
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Mode toggle with visual feedback
                HStack(spacing: 8) {
                    Image(systemName: serviceManager.replyToAll ? 
                        "bubble.left.and.bubble.right.fill" : "plus.bubble.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    
                    Picker("", selection: $serviceManager.replyToAll) {
                        Text("Reply to All").tag(true)
                        Text("New Chat").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    
                    // Show loading indicator when services are loading
                    if serviceManager.loadingStates.values.contains(true) {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Input field with clear and send buttons
                HStack(spacing: 8) {
                    TextField("Ask all services...", text: $serviceManager.sharedPrompt)
                        .textFieldStyle(.plain)
                        .focused($isInputFocused)
                        .onSubmit {
                            serviceManager.executeSharedPrompt()
                        }
                        .font(.system(size: 14))
                    
                    if !serviceManager.sharedPrompt.isEmpty {
                        Button(action: {
                            serviceManager.sharedPrompt = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: {
                        serviceManager.executeSharedPrompt()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(serviceManager.sharedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .accentColor)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(serviceManager.sharedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(6)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusUnifiedInput)) { _ in
            isInputFocused = true
        }
    }
} 
