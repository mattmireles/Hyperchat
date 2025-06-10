import Cocoa
import SwiftUI

// MARK: - AppKit Components

// The NSWindow subclass for our prompt.
// This is where we handle window-level keyboard events.
class PromptWindow: NSWindow {
    private var enterMonitor: Any?
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        
        // Install local event monitor for Enter key
        enterMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 36 && !event.modifierFlags.contains(.shift) {
                // Enter pressed without Shift
                NotificationCenter.default.post(name: .submitPrompt, object: nil)
                return nil // Swallow the event
            }
            return event // Let other keys through (including Shift+Enter)
        }
    }
    
    override func close() {
        if let monitor = enterMonitor {
            NSEvent.removeMonitor(monitor)
        }
        super.close()
    }

    // Make the ESC key close the window, which is standard AppKit behavior.
    override func cancelOperation(_ sender: Any?) {
        close()
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
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
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
    @FocusState private var isEditorFocused: Bool

    private let minHeight: CGFloat = 60
    private func maxEditorHeight() -> CGFloat {
        if let screen = NSScreen.main {
            return screen.visibleFrame.height * 0.4
        }
        return 400
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
                TextEditor(text: $promptText)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .focused($isEditorFocused)
                    .frame(minHeight: minHeight, maxHeight: maxEditorHeight())
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.system(size: 14))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                if promptText.isEmpty {
                    Text("Type your prompt...")
                        .foregroundColor(.secondary)
                        .padding(.leading, 14)
                        .padding(.top, 12)
                }
            }
            .padding(0)

            HStack {
                Button("Cancel", role: .cancel, action: closeWindow)
                Spacer()
                Button("Ask All Services", action: handleSubmit)
                    .buttonStyle(.borderedProminent)
                    .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
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
        .onAppear { isEditorFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .submitPrompt)) { _ in
            handleSubmit()
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