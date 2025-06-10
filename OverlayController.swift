import Cocoa
import SwiftUI

class OverlayWindow: NSWindow {
    weak var overlayController: OverlayController?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            overlayController?.exitFullScreenOverlay()
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
    private var escMonitor: Any?
    private var isHiding = false
    
    // Store the normal window state
    private var savedWindowFrame: NSRect?
    private var savedWindowLevel: NSWindow.Level?
    private var savedStyleMask: NSWindow.StyleMask?
    private var isInOverlayMode = false
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
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.overlayController = self
        overlayWindow = window

        window.title = "HyperChat"
        window.minSize = NSSize(width: 800, height: 600)
        window.level = .normal
        window.collectionBehavior = [.managed, .fullScreenPrimary]
        window.backgroundColor = NSColor.windowBackgroundColor

        let containerView = NSView(frame: window.contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]
        window.contentView = containerView

        setupBrowserViews(in: containerView)

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
        browserStackView.spacing = 10
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
            mainStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            mainStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
            mainStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            mainStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            
            // Set input bar height constraint
            inputBarHostingView.heightAnchor.constraint(equalToConstant: 60)
        ]
        NSLayoutConstraint.activate(constraints)
        stackViewConstraints = constraints
    }
    
    private func enterFullScreenOverlay() {
        guard let window = overlayWindow, !isInOverlayMode else { return }
        
        savedWindowFrame = window.frame
        savedWindowLevel = window.level
        savedStyleMask = window.styleMask
        isInOverlayMode = true
        
        let targetScreen = NSScreen.screenWithMouse() ?? window.screen ?? NSScreen.main!
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            window.styleMask = [.borderless]
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.animator().setFrame(targetScreen.frame, display: true)
            
        }, completionHandler: {
            self.addOverlayEffects()
        })
        
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] ev in
            if ev.keyCode == 53 && self?.isInOverlayMode == true {
                self?.exitFullScreenOverlay()
                return nil
            }
            return ev
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
            inputBarHostingView?.heightAnchor.constraint(equalToConstant: 60)
        ].compactMap { $0 }
        NSLayoutConstraint.activate(newConstraints)
        stackViewConstraints = newConstraints
    }
    
    func exitFullScreenOverlay() {
        guard let window = overlayWindow, isInOverlayMode, !isHiding else { return }
        
        isHiding = true
        
        blurView?.removeFromSuperview()
        tintView?.removeFromSuperview()
        blurView = nil
        tintView = nil
        
        if let m = escMonitor {
            NSEvent.removeMonitor(m)
            escMonitor = nil
        }
        
        if let contentView = window.contentView,
           let stackView = contentView.subviews.first(where: { 
               $0.identifier == NSUserInterfaceItemIdentifier("mainStackView") 
           }) as? NSStackView {
            NSLayoutConstraint.deactivate(stackViewConstraints)
            let newConstraints = [
                stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
                stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
                stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
                stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
                
                // Keep the input bar height constraint
                inputBarHostingView?.heightAnchor.constraint(equalToConstant: 60)
            ].compactMap { $0 }
            NSLayoutConstraint.activate(newConstraints)
            stackViewConstraints = newConstraints
        }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            if let savedStyle = self.savedStyleMask { window.styleMask = savedStyle }
            if let savedLevel = self.savedWindowLevel { window.level = savedLevel }
            window.collectionBehavior = [.managed, .fullScreenPrimary]
            
            if let savedFrame = self.savedWindowFrame {
                window.animator().setFrame(savedFrame, display: true)
            }
        }, completionHandler: {
            self.isInOverlayMode = false
            self.isHiding = false
            window.title = "HyperChat"
        })
    }

    func hideOverlay() {
        // This function is now only responsible for closing the window entirely.
        // It should not be called when just exiting full-screen mode.
        overlayWindow?.close() // This will trigger the close logic in OverlayWindow
        overlayWindow = nil
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
            }
            .padding(12)
            .background(.regularMaterial)
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusUnifiedInput)) { _ in
            isInputFocused = true
        }
    }
} 