import Cocoa
import SwiftUI

class PromptWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
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

        // Ensure focus
        DispatchQueue.main.async { [weak self] in
            self?.promptViewController?.view.window?.makeFirstResponder(nil)
        }
    }
}

extension Notification.Name {
    static let showOverlay = Notification.Name("showOverlay")
}

struct PromptView: View {
    @State private var promptText: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Ask anything...", text: $promptText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 18))
                .focused($isTextFieldFocused)
                .onChange(of: promptText) { oldValue, newValue in
                    // Force view update when text changes (fixes paste display issues)
                    isTextFieldFocused = true
                }
                .onSubmit {
                    handleSubmit()
                }
                // Enable standard keyboard shortcuts
                .onKeyPress(.escape) {
                    if let window = NSApp.windows.first(where: { $0 is PromptWindow }) {
                        window.close()
                    }
                    return .handled
                }
        }
        .frame(width: 500, height: 60)  // Fixed frame size
        .padding(20)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
        .onAppear {
            isTextFieldFocused = true
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