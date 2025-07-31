/// ChatMessage.swift - Enhanced Chat Message Models
///
/// This file contains the enhanced message models that support rich content types,
/// attachments, markdown rendering, and advanced message states. These models
/// provide the foundation for a sophisticated chat experience in the local LLM interface.
///
/// Key features:
/// - Support for multiple content types (text, markdown, files, images)
/// - File attachment handling with metadata
/// - Message status tracking (sending, delivered, failed, etc.)
/// - Timestamp and metadata management
/// - Thread and conversation grouping
/// - Rich message context for better UX
///
/// This file is used by:
/// - `LocalChatView.swift` - Main chat interface
/// - `MessageBubble.swift` - Message display component
/// - `ServiceManager.swift` - Message processing and storage
/// - Future conversation management components
///
/// Related files:
/// - `MessageBubble.swift` - Uses these models for display
/// - `MarkdownView.swift` - Renders markdown content from messages
/// - `LocalLLMHeader.swift` - Manages model context

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Attachment Model

/// Represents a file attachment within a chat message
public struct FileAttachment: Identifiable, Codable, Equatable {
    public let id = UUID()
    let originalName: String
    let fileExtension: String
    let mimeType: String
    let sizeInBytes: Int64
    let localPath: URL
    let thumbnailPath: URL?
    let uploadedAt: Date
    
    /// Computed properties for display
    var displayName: String {
        return originalName
    }
    
    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeInBytes)
    }
    
    var fileType: UTType? {
        return UTType(mimeType: mimeType)
    }
    
    var isImage: Bool {
        return fileType?.conforms(to: .image) ?? false
    }
    
    var isDocument: Bool {
        return fileType?.conforms(to: .data) ?? false
    }
    
    var systemIconName: String {
        if isImage {
            return "photo"
        } else if fileType?.conforms(to: .pdf) == true {
            return "doc.richtext"
        } else if fileType?.conforms(to: .plainText) == true {
            return "doc.text"
        } else if fileType?.conforms(to: .archive) == true {
            return "archivebox"
        } else {
            return "doc"
        }
    }
    
    public init(originalName: String, fileExtension: String, mimeType: String, 
         sizeInBytes: Int64, localPath: URL, thumbnailPath: URL? = nil) {
        self.originalName = originalName
        self.fileExtension = fileExtension
        self.mimeType = mimeType
        self.sizeInBytes = sizeInBytes
        self.localPath = localPath
        self.thumbnailPath = thumbnailPath
        self.uploadedAt = Date()
    }
}

// MARK: - Message Content Types

/// Represents the different types of content a message can contain
public enum MessageContentType: Codable, Equatable {
    case text(String)
    case markdown(String)
    case image(FileAttachment)
    case file(FileAttachment)
    case multipleFiles([FileAttachment])
    case typing
    case error(String)
    case system(String) // System messages like "Model loaded", "Connection lost", etc.
    
    /// Get the primary text content for search/indexing
    var textContent: String {
        switch self {
        case .text(let content), .markdown(let content):
            return content
        case .error(let message), .system(let message):
            return message
        case .image(let attachment), .file(let attachment):
            return attachment.originalName
        case .multipleFiles(let attachments):
            return attachments.map { $0.originalName }.joined(separator: ", ")
        case .typing:
            return "typing..."
        }
    }
    
    /// Check if content contains attachments
    var hasAttachments: Bool {
        switch self {
        case .image, .file, .multipleFiles:
            return true
        default:
            return false
        }
    }
    
    /// Get all attachments from the content
    var attachments: [FileAttachment] {
        switch self {
        case .image(let attachment), .file(let attachment):
            return [attachment]
        case .multipleFiles(let attachments):
            return attachments
        default:
            return []
        }
    }
}

// MARK: - Message Status

/// Represents the current status of a message
public enum MessageStatus: String, Codable, CaseIterable {
    case composing = "composing"      // User is typing
    case sending = "sending"          // Message is being sent
    case delivered = "delivered"      // Message delivered successfully
    case generating = "generating"    // AI is generating response
    case completed = "completed"      // AI response completed
    case failed = "failed"           // Message failed to send/generate
    case cancelled = "cancelled"      // Generation was cancelled
    
    var displayText: String {
        switch self {
        case .composing:
            return "Typing..."
        case .sending:
            return "Sending..."
        case .delivered:
            return "Delivered"
        case .generating:
            return "Generating..."
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    var isInProgress: Bool {
        switch self {
        case .composing, .sending, .generating:
            return true
        default:
            return false
        }
    }
    
    var isCompleted: Bool {
        switch self {
        case .delivered, .completed:
            return true
        default:
            return false
        }
    }
    
    var isError: Bool {
        switch self {
        case .failed, .cancelled:
            return true
        default:
            return false
        }
    }
}

// MARK: - Enhanced Chat Message

/// Enhanced chat message model with rich content support and metadata
public struct EnhancedChatMessage: Identifiable, Codable, Equatable {
    public let id: UUID
    let isFromUser: Bool
    var contentType: MessageContentType
    var status: MessageStatus
    let timestamp: Date
    var lastUpdated: Date
    let conversationId: UUID?
    let threadId: UUID?
    let modelUsed: String?
    var tokenCount: Int?
    var processingTimeMs: Int?
    var metadata: [String: String]
    
    // MARK: - Initializers
    
    public init(isFromUser: Bool, contentType: MessageContentType, status: MessageStatus = .delivered,
         conversationId: UUID? = nil, threadId: UUID? = nil, modelUsed: String? = nil,
         tokenCount: Int? = nil, processingTimeMs: Int? = nil, metadata: [String: String] = [:]) {
        self.id = UUID()
        self.isFromUser = isFromUser
        self.contentType = contentType
        self.status = status
        self.timestamp = Date()
        self.lastUpdated = Date()
        self.conversationId = conversationId
        self.threadId = threadId
        self.modelUsed = modelUsed
        self.tokenCount = tokenCount
        self.processingTimeMs = processingTimeMs
        self.metadata = metadata
    }
    
    // Convenience initializers for common message types
    public static func userText(_ text: String, conversationId: UUID? = nil) -> EnhancedChatMessage {
        return EnhancedChatMessage(
            isFromUser: true,
            contentType: .text(text),
            conversationId: conversationId
        )
    }
    
    public static func aiMarkdown(_ markdown: String, modelUsed: String, conversationId: UUID? = nil,
                          tokenCount: Int? = nil, processingTimeMs: Int? = nil) -> EnhancedChatMessage {
        return EnhancedChatMessage(
            isFromUser: false,
            contentType: .markdown(markdown),
            status: .completed,
            conversationId: conversationId,
            modelUsed: modelUsed,
            tokenCount: tokenCount,
            processingTimeMs: processingTimeMs
        )
    }
    
    static func userImage(_ attachment: FileAttachment, conversationId: UUID? = nil) -> EnhancedChatMessage {
        return EnhancedChatMessage(
            isFromUser: true,
            contentType: .image(attachment),
            conversationId: conversationId
        )
    }
    
    static func userFiles(_ attachments: [FileAttachment], conversationId: UUID? = nil) -> EnhancedChatMessage {
        return EnhancedChatMessage(
            isFromUser: true,
            contentType: .multipleFiles(attachments),
            conversationId: conversationId
        )
    }
    
    public static func systemMessage(_ message: String, conversationId: UUID? = nil) -> EnhancedChatMessage {
        return EnhancedChatMessage(
            isFromUser: false,
            contentType: .system(message),
            status: .completed,
            conversationId: conversationId
        )
    }
    
    public static func typingIndicator(conversationId: UUID? = nil) -> EnhancedChatMessage {
        return EnhancedChatMessage(
            isFromUser: false,
            contentType: .typing,
            status: .generating,
            conversationId: conversationId
        )
    }
    
    public static func errorMessage(_ error: String, conversationId: UUID? = nil) -> EnhancedChatMessage {
        return EnhancedChatMessage(
            isFromUser: false,
            contentType: .error(error),
            status: .failed,
            conversationId: conversationId
        )
    }
    
    // MARK: - Computed Properties
    
    /// Get the primary text content for display/search
    var textContent: String {
        return contentType.textContent
    }
    
    /// Check if message has attachments
    var hasAttachments: Bool {
        return contentType.hasAttachments
    }
    
    /// Get all file attachments
    var attachments: [FileAttachment] {
        return contentType.attachments
    }
    
    /// Check if message is currently being processed
    var isInProgress: Bool {
        return status.isInProgress
    }
    
    /// Check if message completed successfully
    var isCompleted: Bool {
        return status.isCompleted
    }
    
    /// Check if message has an error state
    var hasError: Bool {
        return status.isError
    }
    
    /// Check if message is currently being generated (for typing indicators)
    var isGenerating: Bool {
        return status == .generating
    }
    
    /// Format timestamp for display
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: timestamp)
    }
    
    /// Format full date and time
    var formattedFullTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .medium
        return formatter.string(from: timestamp)
    }
    
    /// Processing time description
    var processingTimeDescription: String? {
        guard let processingTimeMs = processingTimeMs else { return nil }
        
        if processingTimeMs < 1000 {
            return "\(processingTimeMs)ms"
        } else {
            let seconds = Double(processingTimeMs) / 1000.0
            return String(format: "%.1fs", seconds)
        }
    }
    
    /// Token count description
    var tokenCountDescription: String? {
        guard let tokenCount = tokenCount else { return nil }
        
        if tokenCount < 1000 {
            return "\(tokenCount) tokens"
        } else {
            let k = Double(tokenCount) / 1000.0
            return String(format: "%.1fk tokens", k)
        }
    }
    
    // MARK: - Mutating Methods
    
    /// Update the message status
    mutating func updateStatus(_ newStatus: MessageStatus) {
        status = newStatus
        lastUpdated = Date()
    }
    
    /// Update message content (for streaming responses)
    mutating func updateContent(_ newContent: MessageContentType) {
        contentType = newContent
        lastUpdated = Date()
    }
    
    /// Add metadata
    mutating func addMetadata(key: String, value: String) {
        metadata[key] = value
        lastUpdated = Date()
    }
}

// MARK: - Conversation Model

/// Represents a conversation thread containing multiple messages
public struct Conversation: Identifiable, Codable {
    public let id: UUID
    let title: String
    let createdAt: Date
    let lastMessageAt: Date
    let modelUsed: String?
    let messageCount: Int
    let totalTokens: Int
    let isArchived: Bool
    let tags: [String]
    
    public init(title: String, modelUsed: String? = nil, tags: [String] = []) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.lastMessageAt = Date()
        self.modelUsed = modelUsed
        self.messageCount = 0
        self.totalTokens = 0
        self.isArchived = false
        self.tags = tags
    }
    
    /// Generate a title from the first user message
    static func generateTitle(from message: EnhancedChatMessage) -> String {
        let text = message.textContent
        let words = text.components(separatedBy: .whitespaces)
        let truncated = Array(words.prefix(6)).joined(separator: " ")
        return truncated.isEmpty ? "New Conversation" : truncated
    }
}

// MARK: - Legacy Compatibility

/// Legacy ChatMessage for backward compatibility
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let isFromUser: Bool
    var text: String
    
    /// Convert to enhanced message
    func toEnhanced() -> EnhancedChatMessage {
        return EnhancedChatMessage(
            isFromUser: isFromUser,
            contentType: .text(text)
        )
    }
}

// MARK: - Extensions

extension EnhancedChatMessage {
    /// Convert to legacy ChatMessage for backward compatibility
    func toLegacy() -> ChatMessage {
        return ChatMessage(isFromUser: isFromUser, text: textContent)
    }
}

#if DEBUG
// MARK: - Sample Data for Previews

extension EnhancedChatMessage {
    static let sampleUserText = EnhancedChatMessage.userText("Hello! Can you help me understand how SwiftUI works?")
    
    static let sampleAIMarkdown = EnhancedChatMessage.aiMarkdown("""
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
        """, modelUsed: "Llama-2-7B-Chat", tokenCount: 150, processingTimeMs: 1250)
    
    static let sampleTyping = EnhancedChatMessage.typingIndicator()
    
    static let sampleError = EnhancedChatMessage.errorMessage("Failed to generate response. Please try again.")
    
    static let sampleSystem = EnhancedChatMessage.systemMessage("Model Llama-2-7B-Chat loaded successfully")
}
#endif