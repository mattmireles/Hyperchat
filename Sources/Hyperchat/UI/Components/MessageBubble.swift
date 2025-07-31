/// MessageBubble.swift - Enhanced Message Display with Apple-Like Polish
///
/// This component renders individual chat messages with sophisticated Apple-like styling,
/// including gradient backgrounds, glass morphism effects, and integrated markdown rendering.
/// It provides a premium user experience that matches the quality of leading AI chat applications.
///
/// Features:
/// - User messages: Gradient backgrounds matching app theme
/// - AI messages: Glass morphism with backdrop blur effects
/// - Integrated markdown rendering via MarkdownView
/// - Smooth corner radius and proper spacing
/// - Hover effects and micro-interactions
/// - Context menu support for message actions
/// - Typing indicator animations
///
/// This component is used by:
/// - `LocalChatView.swift` for displaying conversation messages
/// - Future message list implementations
///
/// Related files:
/// - `MarkdownView.swift` - Renders markdown content within messages
/// - `GradientToolbarButton.swift` - Shares gradient color scheme
/// - `LocalChatView.swift` - Primary consumer of this component

import SwiftUI

// MARK: - Visual Constants

/// Styling constants for message bubbles
private enum BubbleStyle {
    /// Corner radius for modern Apple-like appearance
    static let cornerRadius: CGFloat = 16
    
    /// Maximum width as percentage of container
    static let maxWidthRatio: CGFloat = 0.75
    
    /// Internal padding for message content
    static let contentPadding: CGFloat = 16
    
    /// Spacing between message elements
    static let elementSpacing: CGFloat = 8
    
    /// Shadow properties
    static let shadowRadius: CGFloat = 8
    static let shadowOpacity: Double = 0.1
    static let shadowOffset: CGSize = CGSize(width: 0, height: 2)
    
    /// Gradient colors matching app theme
    static let userGradientColors = [
        Color(red: 1.0, green: 0.0, blue: 0.8),  // Pink
        Color(red: 0.6, green: 0.2, blue: 0.8),  // Purple
        Color(red: 0.0, green: 0.6, blue: 1.0)   // Blue
    ]
    
    /// Glass morphism colors for AI messages
    static let aiBackgroundColor = Color.primary.opacity(0.03)
    static let aiBackgroundBlur: CGFloat = 10
    static let aiBorderColor = Color.primary.opacity(0.1)
}

// MARK: - Animation Constants

/// Animation timing and easing constants
private enum AnimationStyle {
    /// Message appearance animation
    static let appearanceDuration: Double = 0.6
    static let appearanceDelay: Double = 0.1
    
    /// Hover effect timing
    static let hoverDuration: Double = 0.2
    
    /// Typing indicator timing
    static let typingDotDuration: Double = 0.6
    static let typingDotDelay: Double = 0.2
    
    /// Spring animation parameters
    static let springResponse: Double = 0.5
    static let springDamping: Double = 0.8
}

// MARK: - Message Content Types

// Note: MessageContentType is defined in Models/ChatMessage.swift

// MARK: - Enhanced Message Model
// Note: EnhancedChatMessage is defined in Models/ChatMessage.swift

// MARK: - Message Bubble Component

/// Enhanced message bubble with Apple-like styling and markdown support
struct MessageBubble: View {
    let message: EnhancedChatMessage
    @State private var isHovering = false
    @State private var hasAppeared = false
    @State private var showContextMenu = false
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 60)
            }
            
            messageContent
                .contextMenu {
                    contextMenuItems
                }
            
            if !message.isFromUser {
                Spacer(minLength: 60)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: AnimationStyle.springResponse, 
                                dampingFraction: AnimationStyle.springDamping)
                         .delay(AnimationStyle.appearanceDelay)) {
                hasAppeared = true
            }
        }
    }
    
    /// Main message content with styling
    @ViewBuilder
    private var messageContent: some View {
        VStack(alignment: .leading, spacing: BubbleStyle.elementSpacing) {
            // Message content based on type
            switch message.contentType {
            case .text(let text):
                Text(text)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(message.isFromUser ? .white : .primary)
                    .lineSpacing(2)
                
            case .markdown(let markdown):
                MarkdownView(markdown)
                    .foregroundColor(message.isFromUser ? .white : .primary)
                
            case .image(let attachment):
                FileAttachmentView(
                    attachment: attachment,
                    displayMode: .full,
                    onAction: { action in
                        handleFileAction(attachment, action)
                    }
                )
                
            case .file(let attachment):
                FileAttachmentView(
                    attachment: attachment,
                    displayMode: .full,
                    onAction: { action in
                        handleFileAction(attachment, action)
                    }
                )
                
            case .multipleFiles(let attachments):
                MultipleFilesView(
                    attachments: attachments,
                    onAction: { attachment, action in
                        handleFileAction(attachment, action)
                    }
                )
                
            case .typing:
                typingIndicator
                
            case .error(let errorMessage):
                errorView(errorMessage)
                
            case .system(let systemMessage):
                Text(systemMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            // Timestamp (appears on hover)
            if isHovering {
                timestampView
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(BubbleStyle.contentPadding)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: BubbleStyle.cornerRadius))
        .shadow(color: .black.opacity(BubbleStyle.shadowOpacity),
                radius: BubbleStyle.shadowRadius,
                x: BubbleStyle.shadowOffset.width,
                y: BubbleStyle.shadowOffset.height)
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: AnimationStyle.hoverDuration)) {
                isHovering = hovering
            }
        }
    }
    
    /// Background styling based on message sender
    @ViewBuilder
    private var backgroundView: some View {
        if message.isFromUser {
            // User messages: Gradient background
            LinearGradient(
                colors: BubbleStyle.userGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // AI messages: Glass morphism effect
            ZStack {
                // Background blur
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .opacity(0.8)
                
                // Subtle background color
                BubbleStyle.aiBackgroundColor
                
                // Border overlay
                RoundedRectangle(cornerRadius: BubbleStyle.cornerRadius)
                    .stroke(BubbleStyle.aiBorderColor, lineWidth: 0.5)
            }
        }
    }
    
    /// Typing indicator with animated dots
    @ViewBuilder
    private var typingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(typingAnimation(for: index))
                    .animation(
                        .easeInOut(duration: AnimationStyle.typingDotDuration)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * AnimationStyle.typingDotDelay),
                        value: message.isGenerating
                    )
            }
            
            Text("AI is thinking...")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    /// Error view for failed messages
    @ViewBuilder
    private func errorView(_ errorMessage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.system(size: 14))
            
            Text(errorMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }
    
    /// Timestamp view that appears on hover
    @ViewBuilder
    private var timestampView: some View {
        Text(formatTimestamp(message.timestamp))
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary.opacity(0.8))
            .padding(.top, 4)
    }
    
    /// Context menu items for message actions
    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Copy Text") {
            copyMessageText()
        }
        
        if case .markdown = message.contentType {
            Button("Copy as Markdown") {
                copyMarkdownText()
            }
        }
        
        if !message.isFromUser {
            Button("Regenerate Response") {
                regenerateResponse()
            }
        }
        
        Divider()
        
        Button("Select All") {
            selectAllText()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Calculate typing animation scale for dot at given index
    private func typingAnimation(for index: Int) -> CGFloat {
        return message.isGenerating ? 1.2 : 1.0
    }
    
    /// Format timestamp for display
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Copy message text to clipboard
    private func copyMessageText() {
        var textToCopy = ""
        
        switch message.contentType {
        case .text(let text), .markdown(let text):
            textToCopy = text
        case .error(let error):
            textToCopy = error
        case .typing:
            textToCopy = "AI is typing..."
        case .system(let system):
            textToCopy = system
        case .image(let attachment):
            textToCopy = attachment.originalName
        case .file(let attachment):
            textToCopy = attachment.originalName
        case .multipleFiles(let attachments):
            textToCopy = attachments.map { $0.originalName }.joined(separator: ", ")
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textToCopy, forType: .string)
    }
    
    /// Copy markdown text to clipboard
    private func copyMarkdownText() {
        if case .markdown(let markdown) = message.contentType {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(markdown, forType: .string)
        }
    }
    
    /// Trigger response regeneration
    ///
    /// Current implementation: Posts notification to LocalChatView
    /// Future enhancement: Could include regeneration parameters (temperature, etc.)
    private func regenerateResponse() {
        // Send notification to parent LocalChatView for handling
        NotificationCenter.default.post(
            name: .regenerateLocalResponse,
            object: nil,
            userInfo: ["messageId": message.id]
        )
    }
    
    /// Select all text in message
    ///
    /// Future Enhancement: Native text selection
    /// This would integrate with NSTextView or similar for proper text selection,
    /// including partial selection and copy functionality
    ///
    /// Current behavior: Placeholder - full text copy available via context menu
    private func selectAllText() {
        // Text selection feature deferred - use copy from context menu instead
    }
    
    /// Handle file attachment actions
    private func handleFileAction(_ attachment: FileAttachment, _ action: FileAttachmentAction) {
        switch action {
        case .open:
            NSWorkspace.shared.open(attachment.localPath)
        case .save:
            saveFileAs(attachment)
        case .copy:
            copyFileToClipboard(attachment)
        case .showInFinder:
            NSWorkspace.shared.selectFile(attachment.localPath.path, inFileViewerRootedAtPath: "")
        case .copyImage:
            if attachment.isImage, let image = NSImage(contentsOf: attachment.localPath) {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([image])
            }
        case .delete:
            /// Future Enhancement: File attachment deletion
            /// This would remove the attachment from the message and update the UI
            /// Current behavior: No-op placeholder
            break
        }
    }
    
    /// Save file to user-chosen location
    private func saveFileAs(_ attachment: FileAttachment) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = attachment.originalName
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try FileManager.default.copyItem(at: attachment.localPath, to: url)
            } catch {
                print("❌ Failed to save file: \(error)")
            }
        }
    }
    
    /// Copy file URL to clipboard
    private func copyFileToClipboard(_ attachment: FileAttachment) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([attachment.localPath as NSURL])
    }
}

// MARK: - Visual Effect View Helper

/// Helper for glass morphism effects
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Custom Notifications

extension Notification.Name {
    /// Notification sent when user requests response regeneration
    static let regenerateLocalResponse = Notification.Name("regenerateLocalResponse")
}

// MARK: - Preview

#if DEBUG
struct MessageBubble_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // User message
            MessageBubble(message: EnhancedChatMessage(
                isFromUser: true,
                contentType: .text("Hello! Can you help me understand how SwiftUI works?")
            ))
            
            // AI markdown response
            MessageBubble(message: EnhancedChatMessage(
                isFromUser: false,
                contentType: .markdown("""
                # SwiftUI Overview
                
                SwiftUI is Apple's **declarative** framework for building user interfaces. Here are the key concepts:
                
                ## Core Principles
                
                - **Declarative**: You describe *what* the UI should look like
                - **Data-driven**: UI updates automatically when data changes
                - **Cross-platform**: Works on iOS, macOS, watchOS, and tvOS
                
                ```swift
                struct ContentView: View {
                    var body: some View {
                        Text("Hello, SwiftUI!")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                }
                ```
                
                The framework handles the *how* automatically!
                """)
            ))
            
            // Typing indicator
            MessageBubble(message: EnhancedChatMessage(
                isFromUser: false,
                contentType: .typing,
                status: .generating
            ))
            
            // Error message
            MessageBubble(message: EnhancedChatMessage(
                isFromUser: false,
                contentType: .error("Failed to generate response. Please try again.")
            ))
        }
        .padding()
        .frame(width: 600)
        .background(Color(.windowBackgroundColor))
        .previewDisplayName("Message Bubbles")
    }
}
#endif