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
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        // Ensure focus
        DispatchQueue.main.async { [weak self] in
            self?.promptViewController?.view.window?.makeFirstResponder(nil)
        }
    }
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
                .onSubmit {
                    handleSubmit()
                }
                // Enable standard keyboard shortcuts
                .onKeyPress(.escape) {
                    NSApp.keyWindow?.close()
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
        guard !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // TODO: Send prompt to services
        print("Submitted prompt: \(promptText)")
        
        // Clear the text
        promptText = ""
        
        // Close the window
        NSApp.keyWindow?.close()
    }
}