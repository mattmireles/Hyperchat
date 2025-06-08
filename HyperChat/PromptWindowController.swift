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
        
        // Create the SwiftUI view and hosting controller
        let promptView = PromptView()
        let hostingController = NSHostingController(rootView: promptView)
        window.contentViewController = hostingController
        self.promptViewController = hostingController
        
        // Set the window's content size to match our SwiftUI view
        window.setContentSize(NSSize(width: 540, height: 100))
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
        
        super.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        // DO NOT manually manage first responder here.
        // Let SwiftUI's @FocusState handle it.
        // The old code `makeFirstResponder(nil)` was breaking keyboard input.
    }
}

extension Notification.Name {
    static let showOverlay = Notification.Name("showOverlay")
}

struct PromptView: View {
    @State private var promptText: String = ""
    @FocusState private var isEditorFocused: Bool

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
                    closeWindow()
                }
                // Rely on standard window cancelOperation for ESC
                
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
    
    private func closeWindow() {
        if let window = NSApp.windows.first(where: { $0 is PromptWindow }) {
            window.close()
        }
    }
    
    private func handleSubmit() {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Grab a reference to the window *before* showing the overlay
        let windowToClose = NSApp.keyWindow
        
        // Post notification to show overlay with prompt
        NotificationCenter.default.post(name: .showOverlay, object: trimmed)
        
        // Clear the text
        promptText = ""
        
        // Close the prompt window
        windowToClose?.close()
    }
}