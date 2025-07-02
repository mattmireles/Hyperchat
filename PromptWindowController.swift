import Cocoa
import SwiftUI

// MARK: - AppKit Components

// The NSWindow subclass for our prompt.
// This is where we handle window-level keyboard events.
class PromptWindow: NSWindow {
    private var enterKeyMonitor: Any?
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Make the ESC key close the window, which is standard AppKit behavior.
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

    // Manually handle command-key shortcuts to ensure they work in a borderless window.
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

// The NSWindowController that manages the PromptWindow.
class PromptWindowController: NSWindowController {
    private var hostingController: NSHostingController<PromptView>?
    private var currentScreen: NSScreen?

    convenience init() {
        let window = PromptWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 124), // Set initial size
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating

        self.init(window: window)

        // Create the SwiftUI view, passing a callback to handle size changes.
        let promptView = PromptView(onHeightChange: { [weak self] newHeight in
            self?.adjustWindowHeight(to: newHeight)
        }, maxHeight: { [weak self] in
            self?.getMaxHeight() ?? 600
        })
        
        hostingController = NSHostingController(rootView: promptView)
        window.contentViewController = hostingController
    }

    // Show the window and center it on the correct screen.
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeKey()
        }
    }
    
    private func getMaxHeight() -> CGFloat {
        let screen = currentScreen ?? NSScreen.main ?? NSScreen.screens.first
        let screenHeight = screen?.visibleFrame.height ?? 800
        return screenHeight * 0.8 // 80% of screen height
    }

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

// Notification name for showing the main overlay.
extension Notification.Name {
    static let showOverlay = Notification.Name("showOverlay")
    static let submitPrompt = Notification.Name("submitPrompt")
}

// Preference key to communicate the view's height up the hierarchy.
struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// The SwiftUI view for the prompt input.
struct PromptView: View {
    var onHeightChange: (CGFloat) -> Void
    var maxHeight: () -> CGFloat

    @State private var promptText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var isSubmitHovering = false
    @State private var showFlameIcon = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Hyperchat logo
                Image("HyperchatIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .cornerRadius(10)
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
                        .frame(minHeight: 36, maxHeight: 36)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
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
                        .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .animation(.easeInOut(duration: 0.2), value: promptText.isEmpty)
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
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(height: 72)
            .background(
                VisualEffectBackground()
            )
        }
        .frame(width: 800)
        .cornerRadius(12)
        .shadow(radius: 20)
        .overlay(
            GeometryReader { geometry in
                Color.clear.preference(key: HeightPreferenceKey.self, value: geometry.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self) { newTotalHeight in
            if newTotalHeight > 0 {
                onHeightChange(newTotalHeight)
            }
        }
        .onAppear { isInputFocused = true }
    }
    
    private func submitWithAnimation() {
        // Trigger flame animation
        withAnimation(.easeInOut(duration: 0.2)) {
            showFlameIcon = true
        }
        
        // Delay execution to ensure animation is visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            handleSubmit()
        }
        
        // Reset icon after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showFlameIcon = false
            }
        }
    }

    // Handlers
    private func closeWindow() {
        NSApp.keyWindow?.close()
    }

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