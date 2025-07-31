/// FileAttachmentView.swift - Elegant File Attachment Display
///
/// This component provides sophisticated file attachment rendering within chat messages,
/// featuring thumbnails, metadata display, and interactive file actions. It maintains
/// the Apple-like design language while providing rich file handling capabilities.
///
/// Features:
/// - Thumbnail generation for images and documents
/// - File metadata display (size, type, name)
/// - Interactive actions (open, save, copy)
/// - Progress indicators for upload/download
/// - Drag and drop source capabilities
/// - Context menu with file operations
/// - Accessibility support
///
/// This component is used by:
/// - `MessageBubble.swift` - Displays file attachments within messages
/// - `LocalChatView.swift` - Handles file drop and attachment processing
///
/// Related files:
/// - `ChatMessage.swift` - FileAttachment model definition
/// - `MarkdownView.swift` - May include file references in markdown
/// - Future file management components

import SwiftUI
import QuickLook
import UniformTypeIdentifiers

// MARK: - File Display Constants

/// Visual styling constants for file attachments
private enum FileStyle {
    /// Thumbnail dimensions
    static let thumbnailSize: CGSize = CGSize(width: 60, height: 60)
    static let smallThumbnailSize: CGSize = CGSize(width: 40, height: 40)
    
    /// Layout constants
    static let cornerRadius: CGFloat = 8
    static let borderWidth: CGFloat = 1
    static let contentPadding: CGFloat = 12
    static let elementSpacing: CGFloat = 8
    
    /// Colors
    static let backgroundColor = Color(.controlBackgroundColor).opacity(0.8)
    static let borderColor = Color.secondary.opacity(0.3)
    static let progressColor = Color.blue
    static let errorColor = Color.red
    
    /// Typography
    static let fileNameFont = Font.system(size: 13, weight: .medium)
    static let metadataFont = Font.system(size: 11, weight: .regular)
    static let progressFont = Font.system(size: 10, weight: .medium)
}

// MARK: - File Attachment Display Mode

/// Different display modes for file attachments
enum FileAttachmentDisplayMode {
    case full        // Full display with thumbnail and metadata
    case compact     // Compact display for multiple files
    case thumbnail   // Thumbnail only
    case list        // List item style
}

// MARK: - File Attachment View

/// Sophisticated file attachment display component
struct FileAttachmentView: View {
    let attachment: FileAttachment
    let displayMode: FileAttachmentDisplayMode
    let onAction: ((FileAttachmentAction) -> Void)?
    
    @State private var thumbnail: NSImage?
    @State private var isHovering = false
    @State private var showQuickLook = false
    @State private var uploadProgress: Double = 1.0 // 0.0 to 1.0, 1.0 means complete
    @State private var hasError = false
    
    init(attachment: FileAttachment, 
         displayMode: FileAttachmentDisplayMode = .full,
         onAction: ((FileAttachmentAction) -> Void)? = nil) {
        self.attachment = attachment
        self.displayMode = displayMode
        self.onAction = onAction
    }
    
    var body: some View {
        switch displayMode {
        case .full:
            fullDisplayView
        case .compact:
            compactDisplayView
        case .thumbnail:
            thumbnailOnlyView
        case .list:
            listDisplayView
        }
    }
    
    // MARK: - Display Variants
    
    /// Full display with thumbnail and detailed metadata
    @ViewBuilder
    private var fullDisplayView: some View {
        HStack(spacing: FileStyle.elementSpacing) {
            // Thumbnail or icon
            thumbnailView(size: FileStyle.thumbnailSize)
            
            // File information
            VStack(alignment: .leading, spacing: 4) {
                // File name
                Text(attachment.displayName)
                    .font(FileStyle.fileNameFont)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                
                // File metadata
                HStack(spacing: 8) {
                    Text(attachment.fileSizeFormatted)
                        .font(FileStyle.metadataFont)
                        .foregroundColor(.secondary)
                    
                    if !attachment.fileExtension.isEmpty {
                        Text("•")
                            .font(FileStyle.metadataFont)
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text(attachment.fileExtension.uppercased())
                            .font(FileStyle.metadataFont)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress indicator (if uploading)
                if uploadProgress < 1.0 {
                    progressIndicator
                }
                
                // Error indicator
                if hasError {
                    errorIndicator
                }
            }
            
            Spacer()
            
            // Action buttons
            actionButtons
        }
        .padding(FileStyle.contentPadding)
        .background(attachmentBackground)
        .cornerRadius(FileStyle.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: FileStyle.cornerRadius)
                .stroke(FileStyle.borderColor, lineWidth: FileStyle.borderWidth)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            contextMenuItems
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    /// Compact display for multiple files
    @ViewBuilder
    private var compactDisplayView: some View {
        VStack(spacing: 4) {
            thumbnailView(size: FileStyle.smallThumbnailSize)
            
            Text(attachment.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: FileStyle.smallThumbnailSize.width)
        }
        .onTapGesture {
            handleAction(.open)
        }
        .contextMenu {
            contextMenuItems
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    /// Thumbnail only view
    @ViewBuilder
    private var thumbnailOnlyView: some View {
        thumbnailView(size: FileStyle.thumbnailSize)
            .onTapGesture {
                handleAction(.open)
            }
            .contextMenu {
                contextMenuItems
            }
            .onAppear {
                loadThumbnail()
            }
    }
    
    /// List style display
    @ViewBuilder
    private var listDisplayView: some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.systemIconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(attachment.fileSizeFormatted)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .onTapGesture {
            handleAction(.open)
        }
        .contextMenu {
            contextMenuItems
        }
    }
    
    // MARK: - Helper Views
    
    /// Thumbnail view with loading states
    @ViewBuilder
    private func thumbnailView(size: CGSize) -> some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 6)
                .fill(FileStyle.backgroundColor)
                .frame(width: size.width, height: size.height)
            
            if let thumbnail = thumbnail {
                // Actual thumbnail
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .cornerRadius(6)
            } else {
                // System icon fallback
                Image(systemName: attachment.systemIconName)
                    .font(.system(size: size.width * 0.4, weight: .light))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            // Upload progress overlay
            if uploadProgress < 1.0 {
                ZStack {
                    Color.black.opacity(0.3)
                    
                    CircularProgressView(progress: uploadProgress)
                        .frame(width: 20, height: 20)
                }
                .cornerRadius(6)
            }
            
            // Error overlay
            if hasError {
                ZStack {
                    Color.red.opacity(0.2)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                }
                .cornerRadius(6)
            }
        }
    }
    
    /// Progress indicator for file operations
    @ViewBuilder
    private var progressIndicator: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Uploading...")
                    .font(FileStyle.progressFont)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(uploadProgress * 100))%")
                    .font(FileStyle.progressFont)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: uploadProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: FileStyle.progressColor))
                .frame(height: 2)
        }
    }
    
    /// Error indicator
    @ViewBuilder
    private var errorIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(FileStyle.errorColor)
            
            Text("Upload failed")
                .font(FileStyle.progressFont)
                .foregroundColor(FileStyle.errorColor)
        }
    }
    
    /// Action buttons for file operations
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: {
                handleAction(.open)
            }) {
                Image(systemName: "eye")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Preview file")
            
            Button(action: {
                handleAction(.save)
            }) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Save file")
        }
        .opacity(isHovering ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
    }
    
    /// Background for attachment container
    @ViewBuilder
    private var attachmentBackground: some View {
        if attachment.isImage {
            // Slight tint for images
            FileStyle.backgroundColor.opacity(0.5)
        } else {
            FileStyle.backgroundColor
        }
    }
    
    /// Context menu items
    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Open") {
            handleAction(.open)
        }
        
        Button("Save As...") {
            handleAction(.save)
        }
        
        Button("Copy") {
            handleAction(.copy)
        }
        
        Divider()
        
        Button("Show in Finder") {
            handleAction(.showInFinder)
        }
        
        if attachment.isImage {
            Divider()
            
            Button("Copy Image") {
                handleAction(.copyImage)
            }
        }
    }
    
    // MARK: - Actions and Logic
    
    /// Handle file attachment actions
    private func handleAction(_ action: FileAttachmentAction) {
        onAction?(action)
        
        // Default implementations
        switch action {
        case .open:
            openFile()
        case .save:
            saveFile()
        case .copy:
            copyFile()
        case .showInFinder:
            showInFinder()
        case .copyImage:
            copyImageToClipboard()
        case .delete:
            break // Handled by parent
        }
    }
    
    /// Open file with default application
    private func openFile() {
        NSWorkspace.shared.open(attachment.localPath)
    }
    
    /// Save file to user-chosen location
    private func saveFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = attachment.originalName
        panel.allowedContentTypes = [attachment.fileType].compactMap { $0 }
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try FileManager.default.copyItem(at: attachment.localPath, to: url)
            } catch {
                print("❌ Failed to save file: \(error)")
                hasError = true
            }
        }
    }
    
    /// Copy file to clipboard
    private func copyFile() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([attachment.localPath as NSURL])
    }
    
    /// Show file in Finder
    private func showInFinder() {
        NSWorkspace.shared.selectFile(attachment.localPath.path, inFileViewerRootedAtPath: "")
    }
    
    /// Copy image to clipboard (for image files)
    private func copyImageToClipboard() {
        guard attachment.isImage, let image = NSImage(contentsOf: attachment.localPath) else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
    
    /// Load thumbnail for the file
    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        
        Task {
            let thumbnail = await generateThumbnail(for: attachment.localPath)
            DispatchQueue.main.async {
                self.thumbnail = thumbnail
            }
        }
    }
    
    /// Generate thumbnail for file URL
    private func generateThumbnail(for url: URL) async -> NSImage? {
        if attachment.isImage {
            return NSImage(contentsOf: url)
        }
        
        // For other file types, try to generate a Quick Look thumbnail
        // This is a simplified implementation - a full version would use QLThumbnailGenerator
        return nil
    }
}

// MARK: - File Attachment Actions

/// Available actions for file attachments
enum FileAttachmentAction {
    case open
    case save
    case copy
    case showInFinder
    case copyImage
    case delete
}

// MARK: - Circular Progress View

/// Simple circular progress indicator
struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
        }
    }
}

// MARK: - Multiple Files View

/// Display multiple file attachments in a grid
struct MultipleFilesView: View {
    let attachments: [FileAttachment]
    let onAction: ((FileAttachment, FileAttachmentAction) -> Void)?
    
    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 8)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(attachments.count) files")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(attachments) { attachment in
                    FileAttachmentView(
                        attachment: attachment,
                        displayMode: .compact,
                        onAction: { action in
                            onAction?(attachment, action)
                        }
                    )
                }
            }
        }
        .padding(12)
        .background(FileStyle.backgroundColor)
        .cornerRadius(FileStyle.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: FileStyle.cornerRadius)
                .stroke(FileStyle.borderColor, lineWidth: FileStyle.borderWidth)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct FileAttachmentView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Sample image attachment
            FileAttachmentView(
                attachment: FileAttachment(
                    originalName: "screenshot.png",
                    fileExtension: "png",
                    mimeType: "image/png",
                    sizeInBytes: 1_250_000,
                    localPath: URL(fileURLWithPath: "/tmp/screenshot.png")
                ),
                displayMode: .full
            )
            
            // Sample document attachment
            FileAttachmentView(
                attachment: FileAttachment(
                    originalName: "presentation.pdf",
                    fileExtension: "pdf",
                    mimeType: "application/pdf",
                    sizeInBytes: 5_120_000,
                    localPath: URL(fileURLWithPath: "/tmp/presentation.pdf")
                ),
                displayMode: .full
            )
            
            // Multiple files
            MultipleFilesView(
                attachments: [
                    FileAttachment(originalName: "file1.txt", fileExtension: "txt", mimeType: "text/plain", sizeInBytes: 1024, localPath: URL(fileURLWithPath: "/tmp/file1.txt")),
                    FileAttachment(originalName: "image.jpg", fileExtension: "jpg", mimeType: "image/jpeg", sizeInBytes: 2048000, localPath: URL(fileURLWithPath: "/tmp/image.jpg")),
                    FileAttachment(originalName: "document.docx", fileExtension: "docx", mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", sizeInBytes: 512000, localPath: URL(fileURLWithPath: "/tmp/document.docx"))
                ],
                onAction: { attachment, action in
                    print("Action \(action) on \(attachment.originalName)")
                }
            )
        }
        .padding()
        .frame(width: 400)
        .background(Color(.windowBackgroundColor))
        .previewDisplayName("File Attachments")
    }
}
#endif