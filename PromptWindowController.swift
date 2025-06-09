import Cocoa
import SwiftUI

class PromptWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    // Make ESC key close the window
    override func cancelOperation(_ sender: Any?) {
        self.close()
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
                    return NSApp.sendAction(Selector(("redo:")), to: nil, from: self)
                } else {
                    return NSApp.sendAction(Selector(("undo:")), to: nil, from: self)
                }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

class PromptWindowController: NSWindowController {
    private var promptViewController: NSHostingController<PromptView>?
    
    convenience init() {
        // Borderless floating window
        let window = PromptWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.center()
        
        self.init(window: window)
        
        // Create the SwiftUI view with closures that control this controller
        let promptView = PromptView(
            onSubmit: { [weak self] prompt in
                // Tell the app to show the overlay
                NotificationCenter.default.post(name: .showOverlay, object: prompt)
                // Close our own window
                self?.close()
            },
            onCancel: { [weak self] in
                // Just close our own window
                self?.close()
            }
        )
        let hostingController = NSHostingController(rootView: promptView)
        window.contentViewController = hostingController
        self.promptViewController = hostingController
        
        // Set the window's content size to match our SwiftUI view
        window.setContentSize(hostingController.view.fittingSize)
    }
    
    func showWindow(on screen: NSScreen?) {
        guard let window = self.window else { return }
        
        // Use the provided screen or default to the main screen
        let targetScreen = screen ?? NSScreen.main
        
        // Center the window on the target screen
        let screenRect = targetScreen?.visibleFrame ?? NSRect.zero
        let windowRect = window.frame
        let newOriginX = screenRect.origin.x + (screenRect.width - windowRect.width) / 2
        let newOriginY = screenRect.origin.y + (screenRect.height - windowRect.height) / 2
        window.setFrameOrigin(NSPoint(x: newOriginX, y: newOriginY))
        
        // Set the window's content size to match our SwiftUI view
        if let size = promptViewController?.view.fittingSize, size != .zero {
            window.setContentSize(size)
        }
        
        super.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

extension Notification.Name {
    static let showOverlay = Notification.Name("showOverlay")
}

struct PromptView: View {
    @State private var promptText: String = ""
    @FocusState private var isEditorFocused: Bool

    // Callbacks for the controller to handle logic
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $promptText)
                    .font(.system(size: 16))
                    .frame(minHeight: 40, maxHeight: 200) // Auto-resizing up to a limit
                    .focused($isEditorFocused)
                    .scrollContentBackground(.hidden) // Make it transparent
                    .onKeyPress { press in
                        // Handle submit on Enter, allow newlines with Shift+Enter
                        if press.key == .return {
                            if press.modifiers.contains(.shift) {
                                return .ignored // Allow newline
                            } else {
                                handleSubmit()
                                return .handled // Prevent newline
                            }
                        }
                        return .ignored
                    }
            
                if promptText.isEmpty {
                    Text("Ask anything...")
                        .font(.system(size: 16))
                        .foregroundColor(Color.gray.opacity(0.6))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Ask All Services") {
                    handleSubmit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500) // Keep the overall width fixed
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
        .onAppear {
            isEditorFocused = true
        }
    }
    
    private func handleSubmit() {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
    }
}