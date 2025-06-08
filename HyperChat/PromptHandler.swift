import Cocoa

class PromptHandler: NSResponder, NSTextViewDelegate {
    private var promptPanel: NSPanel?
    private var textView: NSTextView?
    var overlayController: OverlayController?
    private var promptPanelInitialFrame: NSRect?
    
    @objc func showPrompt(on screen: NSScreen) {
        if let promptPanel = promptPanel, promptPanel.isVisible {
            promptPanel.orderFront(nil)
            return
        }

        let initialWidth: CGFloat = 500
        
        let tempTextView = NSTextView()
        tempTextView.font = .systemFont(ofSize: 18)
        let lineHeight = tempTextView.layoutManager?.defaultLineHeight(for: tempTextView.font!) ?? 22
        let initialHeight = (lineHeight * 3) + 20 // 3 lines + 20 for padding

        let panelRect = NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight)

        let panel = NSPanel(contentRect: panelRect,
                           styleMask: [.borderless, .titled, .closable, .resizable],
                           backing: .buffered,
                           defer: false)
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = .canJoinAllSpaces
        panel.title = ""
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        
        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 12.0
        
        panel.contentView = contentView

        let scrollView = NSScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        // Give textView an initial size so it has real width/height
        let contentWidth = initialWidth - 20   // account for 10pt padding each side
        let contentHeight = initialHeight - 20 // account for top/bottom padding
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight))
        self.textView = textView
        
        // Configure proper sizing behaviour inside scroll view
        textView.minSize = NSSize(width: contentWidth, height: contentHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        textView.isRichText = false
        textView.font = .systemFont(ofSize: 18)
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.labelColor
        textView.typingAttributes = [.foregroundColor: NSColor.labelColor, .font: NSFont.systemFont(ofSize: 18)]
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.drawsBackground = true
        textView.delegate = self
        
        // To handle Enter key
        textView.enclosingScrollView?.nextResponder = self
        
        scrollView.documentView = textView
        
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
        ])

        let x = screen.visibleFrame.midX - panel.frame.width / 2
        let y = screen.visibleFrame.midY - panel.frame.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        self.promptPanelInitialFrame = panel.frame

        panel.makeKeyAndOrderFront(nil)
        
        self.promptPanel = panel
        
        DispatchQueue.main.async {
            panel.makeFirstResponder(textView)
        }
    }
    
    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView,
              let panel = promptPanel,
              let screen = panel.screen else { return }

        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        var newHeight = usedRect.height + 30 // Add some vertical padding

        if let initialFrame = promptPanelInitialFrame {
            newHeight = max(newHeight, initialFrame.height)
        }
        
        let maxHeight = screen.visibleFrame.height * 0.4
        var newWidth = panel.frame.width

        if newHeight > maxHeight {
            newWidth = 800
        } else if let initialFrame = promptPanelInitialFrame {
            newWidth = initialFrame.width
        }

        var frame = panel.frame
        let oldHeight = frame.height
        frame.size.height = min(newHeight, maxHeight + 10) // allow scrolling when at max height
        frame.size.width = newWidth
        let heightChange = frame.height - oldHeight
        frame.origin.y -= heightChange / 2
        
        // Center horizontally
        frame.origin.x = screen.visibleFrame.midX - frame.width / 2
        
        panel.setFrame(frame, display: true, animate: true)
    }

    @objc private func executeQuery() {
        guard let prompt = textView?.string, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        print("Prompt entered: \(prompt)")
        overlayController?.showOverlay(with: prompt)
        
        promptPanel?.orderOut(nil)
        promptPanel = nil
    }
    
    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.insertNewline(_:)) {
            // Check if Command key is pressed for newline
            if let event = NSApp.currentEvent, event.modifierFlags.contains(.command) {
                textView.insertNewline(nil)
                return true
            }
            executeQuery()
            return true
        } else if selector == #selector(NSResponder.cancelOperation(_:)) {
             promptPanel?.orderOut(nil)
             promptPanel = nil
             return true
        }
        return false
    }
}