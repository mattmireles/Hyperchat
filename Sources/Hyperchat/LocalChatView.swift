/// LocalChatView.swift - Enhanced Local LLM Chat Interface
///
/// This file provides a sophisticated chat interface for local LLM interactions with
/// Apple-like polish, markdown rendering, and smooth animations. It serves as the main
/// conversation view for the local AI service with premium UX design.
///
/// Key features:
/// - Elegant header with model selection and status
/// - Enhanced message bubbles with markdown rendering
/// - Smooth animations and micro-interactions
/// - File attachment support (drag & drop)
/// - Glass morphism effects and gradient styling
/// - Context menus and message actions
/// - Proper conversation management
///
/// This component integrates:
/// - `LocalLLMHeader.swift` - Sophisticated header with model management
/// - `MessageBubble.swift` - Enhanced message display with Apple-like styling
/// - `MarkdownView.swift` - Rich text rendering for AI responses
/// - `EnhancedChatMessage.swift` - Advanced message models
///
/// Related files:
/// - `ServiceManager.swift` - Message processing and model management
/// - `InferenceEngine.swift` - Local AI inference and streaming
/// - `GradientToolbarButton.swift` - Shared visual styling

import SwiftUI
import UniformTypeIdentifiers

/// LocalChatView Dependencies:
/// - EnhancedChatMessage, Conversation: Models/ChatMessage.swift
/// - MessageBubble: UI/Components/MessageBubble.swift  
/// - LocalLLMHeader: UI/Components/LocalLLMHeader.swift
/// - LocalModel: LocalModel.swift (via ModelManager system)
///
/// Architecture Note: LocalLLMHeader uses ModelInfo for UI presentation,
/// while LocalChatView uses LocalModel for core data. This separation maintains
/// clean boundaries between data models and UI presentation.

// MARK: - Animation Constants

/// Timing constants for smooth animations throughout the interface
private enum UIAnimations {
    /// Message appearance animations
    static let messageAppearanceDuration: Double = 0.6
    static let messageAppearanceDelay: Double = 0.1
    
    /// Scroll animations
    static let scrollToBottomDuration: Double = 0.8
    
    /// State transition animations
    static let stateTransitionDuration: Double = 0.4
    
    /// Spring animation parameters
    static let springResponse: Double = 0.6
    static let springDamping: Double = 0.8
}

// MARK: - Layout Constants

/// Layout and spacing constants for consistent design
private enum LayoutConstants {
    /// Main content padding
    static let contentPadding: CGFloat = 20
    
    /// Message list spacing
    static let messageSpacing: CGFloat = 16
    
    /// Empty state spacing
    static let emptyStateSpacing: CGFloat = 24
    
    /// Minimum scroll view height
    static let minScrollViewHeight: CGFloat = 200
}

// MARK: - Enhanced Local Chat View

/// Sophisticated local LLM chat interface with Apple-like design
struct LocalChatView: View {
    // MARK: - State Management
    @State private var messages: [EnhancedChatMessage] = []
    @State private var currentConversation: Conversation?
    @State private var isGenerating: Bool = false
    @State private var currentTypingMessage: EnhancedChatMessage?
    // Note: ScrollViewReader is a ViewBuilder, not a storable type
    @State private var isDraggingFile: Bool = false
    
    // MARK: - Service Configuration
    private var inferenceEngine: InferenceEngine?
    private let model: LocalModel
    private let serviceId: String
    
    // MARK: - Initializer
    
    /// Initialize the chat view with model configuration
    init(model: LocalModel, serviceId: String) {
        self.model = model
        self.serviceId = serviceId
        
        // Only initialize engine if model is installed and ready
        if model.isReady, let modelPath = model.localPath {
            do {
                self.inferenceEngine = try InferenceEngine(modelPath: modelPath)
                print("✅ Initialized InferenceEngine for \(model.prettyName)")
            } catch {
                print("❌ Failed to initialize InferenceEngine for \(model.prettyName): \(error)")
                self.inferenceEngine = nil
            }
        } else {
            print("⚠️ Model \(model.prettyName) is not ready for inference")
            self.inferenceEngine = nil
        }
    }
    
    // MARK: - Main Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Sophisticated header with model selection
            LocalLLMHeader(
                onModelSelected: { model in
                    handleModelSelection(model)
                },
                onRefreshModels: {
                    refreshAvailableModels()
                }
            )
            
            // Main conversation area
            conversationArea
                .background(conversationBackground)
        }
        .onReceive(NotificationCenter.default.publisher(for: .localServiceExecutePrompt)) { notification in
            handlePromptNotification(notification)
        }
        .onAppear {
            initializeConversation()
        }
    }
    
    // MARK: - Conversation Area
    
    /// Main conversation display area with messages
    @ViewBuilder
    private var conversationArea: some View {
        GeometryReader { geometry in
            if messages.isEmpty {
                emptyStateView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                messageScrollView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDraggingFile) { providers in
            handleFileDrop(providers)
        }
        .overlay(
            // Drag and drop overlay
            dragDropOverlay
        )
    }
    
    /// Beautiful empty state when no messages exist
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: LayoutConstants.emptyStateSpacing) {
            // Animated gradient icon
            Image(systemName: "brain.head.profile")
                .font(.system(size: 72, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.0, blue: 0.8),  // Pink
                            Color(red: 0.6, green: 0.2, blue: 0.8),  // Purple
                            Color(red: 0.0, green: 0.6, blue: 1.0)   // Blue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(isDraggingFile ? 1.2 : 1.0)
                .animation(.spring(response: UIAnimations.springResponse, 
                                dampingFraction: UIAnimations.springDamping), 
                          value: isDraggingFile)
            
            VStack(spacing: 8) {
                Text("Ready to Chat")
                    .font(.system(size: 28, weight: .light, design: .default))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.0, blue: 0.8),
                                Color(red: 0.0, green: 0.6, blue: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Use the input bar below to start a conversation")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            // Helpful tips
            VStack(alignment: .leading, spacing: 12) {
                tipRow(icon: "doc.text", text: "Drag & drop files to include them in your conversation")
                tipRow(icon: "text.cursor", text: "Responses are rendered with full markdown support")
                tipRow(icon: "brain", text: "Switch models anytime from the header above")
            }
            .padding(.top, 16)
            .opacity(0.7)
        }
        .padding(LayoutConstants.contentPadding)
    }
    
    /// Message scroll view with smooth animations
    @ViewBuilder
    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: LayoutConstants.messageSpacing) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    
                    // Typing indicator if generating
                    if isGenerating, let typingMessage = currentTypingMessage {
                        MessageBubble(message: typingMessage)
                            .id("typing")
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(LayoutConstants.contentPadding)
                .animation(.spring(response: UIAnimations.springResponse, 
                                 dampingFraction: UIAnimations.springDamping), 
                          value: messages.count)
            }
            .onAppear {
                // ScrollViewReader proxy is available in this scope
            }
            .onChange(of: messages.count) { _ in
                withAnimation(.easeInOut(duration: UIAnimations.scrollToBottomDuration)) {
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    } else if isGenerating {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    /// Elegant conversation background with subtle gradients
    @ViewBuilder
    private var conversationBackground: some View {
        // Subtle gradient background
        LinearGradient(
            colors: [
                Color(.windowBackgroundColor),
                Color(.windowBackgroundColor).opacity(0.95),
                Color(.windowBackgroundColor)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            // Subtle texture overlay
            Color.primary.opacity(0.01)
        )
    }
    
    /// Drag and drop overlay for file attachments
    @ViewBuilder
    private var dragDropOverlay: some View {
        if isDraggingFile {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.3)
                
                // Drop zone indicator
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Drop files here to attach")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                .scaleEffect(1.1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDraggingFile)
            }
            .transition(.opacity)
        }
    }
    
    // MARK: - Helper Views
    
    /// Helper view for tips in empty state
    @ViewBuilder
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary.opacity(0.6))
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Event Handlers
    
    /// Handle prompt execution from the unified input bar
    private func handlePromptNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let notificationServiceId = userInfo["serviceId"] as? String,
              let prompt = userInfo["prompt"] as? String,
              notificationServiceId == serviceId else {
            print("🔍 LocalChatView (\(serviceId)): Ignoring notification for different service: \(String(describing: notification.userInfo))")
            return
        }
        
        print("✅ LocalChatView (\(serviceId)): Received prompt notification: \(prompt)")
        executePrompt(prompt)
    }
    
    /// Handle response regeneration requests
    private func handleRegenerateRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let messageId = userInfo["messageId"] as? UUID else {
            return
        }
        
        regenerateResponse(for: messageId)
    }
    
    /// Handle model selection changes
    ///
    /// Future Enhancement: Dynamic model switching during conversation
    /// This would involve:
    /// 1. Safely disposing of current InferenceEngine
    /// 2. Loading new model via ModelManager
    /// 3. Creating new InferenceEngine instance
    /// 4. Preserving conversation context where possible
    ///
    /// Current behavior: Logs selection for debugging
    private func handleModelSelection(_ model: Any) {
        print("Model selection requested: \(model)")
        
        // Add system message about model change
        let systemMessage = EnhancedChatMessage.systemMessage(
            "Model switching will be available in a future update",
            conversationId: currentConversation?.id
        )
        
        withAnimation(.spring(response: UIAnimations.springResponse, 
                            dampingFraction: UIAnimations.springDamping)) {
            messages.append(systemMessage)
        }
    }
    
    /// Handle file drop for attachments (simplified for now)
    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        // File attachment support will be added back once components are in Xcode project
        print("File drop detected - file attachment support coming soon!")
        return true
    }
    
    // MARK: - Core Functionality
    
    /// Execute a user prompt with the local LLM
    private func executePrompt(_ prompt: String) {
        guard !prompt.isEmpty else { 
            print("❌ Empty prompt received")
            return 
        }
        
        guard let engine = inferenceEngine else {
            print("❌ No inference engine available")
            let errorMessage = EnhancedChatMessage.errorMessage(
                "Model not ready for inference. Please check model installation."
            )
            withAnimation(.spring(response: UIAnimations.springResponse, 
                                dampingFraction: UIAnimations.springDamping)) {
                messages.append(errorMessage)
            }
            return
        }
        
        print("🚀 Executing prompt: \(prompt)")
        
        // Add user message
        let userMessage = EnhancedChatMessage.userText(
            prompt,
            conversationId: currentConversation?.id
        )
        
        withAnimation(.spring(response: UIAnimations.springResponse, 
                            dampingFraction: UIAnimations.springDamping)) {
            messages.append(userMessage)
        }
        
        // Start generation
        startGeneration()
        
        // Create placeholder for AI response
        let aiMessage = EnhancedChatMessage(
            isFromUser: false,
            contentType: .markdown(""),
            status: .generating
        )
        
        withAnimation(.spring(response: UIAnimations.springResponse, 
                            dampingFraction: UIAnimations.springDamping)) {
            messages.append(aiMessage)
        }
        
        let aiMessageIndex = messages.count - 1
        
        // Generate response
        Task {
            let startTime = Date()
            var tokenCount = 0
            
            do {
                let stream = await engine.generate(for: prompt)
                var responseText = ""
                
                for try await token in stream {
                    responseText += token
                    tokenCount += 1
                    
                    DispatchQueue.main.async {
                        self.messages[aiMessageIndex] = EnhancedChatMessage(
                            isFromUser: false,
                            contentType: .markdown(responseText),
                            status: .generating
                        )
                    }
                }
                
                // Mark as completed
                let processingTime = Int(Date().timeIntervalSince(startTime) * 1000)
                print("✅ Generated \(tokenCount) tokens in \(processingTime)ms")
                
                DispatchQueue.main.async {
                    self.messages[aiMessageIndex] = EnhancedChatMessage.aiMarkdown(
                        responseText,
                        modelUsed: self.model.prettyName
                    )
                    
                    self.stopGeneration()
                }
                
            } catch {
                print("❌ Inference failed: \(error)")
                
                DispatchQueue.main.async {
                    self.messages[aiMessageIndex] = EnhancedChatMessage.errorMessage(
                        "Failed to generate response: \(error.localizedDescription)"
                    )
                    
                    self.stopGeneration()
                }
            }
        }
    }
    
    /// Start the generation process with typing indicator
    private func startGeneration() {
        isGenerating = true
        currentTypingMessage = EnhancedChatMessage.typingIndicator(
            conversationId: currentConversation?.id
        )
    }
    
    /// Stop the generation process
    private func stopGeneration() {
        isGenerating = false
        currentTypingMessage = nil
    }
    
    /// Regenerate a response for a specific message
    ///
    /// Future Enhancement: Response regeneration with different parameters
    /// Implementation approach:
    /// 1. Find the message by UUID in the messages array
    /// 2. Locate the preceding user message for context
    /// 3. Call InferenceEngine.generate() with adjusted parameters (temperature, top-p)
    /// 4. Replace the existing response with new generation
    ///
    /// Current behavior: Logs the request for debugging
    private func regenerateResponse(for messageId: UUID) {
        print("Response regeneration requested for message: \(messageId)")
        // Implementation deferred to future version
    }
    
    // Scroll functionality is now inlined in the ScrollViewReader onChange handler
    
    /// Initialize a new conversation
    private func initializeConversation() {
        if currentConversation == nil {
            currentConversation = Conversation(
                title: "New Conversation",
                modelUsed: model.prettyName
            )
        }
    }
    
    /// Refresh available models list
    ///
    /// Future Enhancement: Dynamic model discovery and refresh
    /// This would integrate with ModelManager to:
    /// 1. Scan for newly downloaded models
    /// 2. Update model status and availability
    /// 3. Refresh the LocalLLMHeader model picker
    /// 4. Handle model deletion/updates
    ///
    /// Current behavior: Placeholder for future implementation
    private func refreshAvailableModels() {
        print("Model refresh requested - will integrate with ModelManager in future version")
    }
}

// MARK: - Extensions
/// File-related extensions for drag & drop support
/// Future enhancement: Will implement comprehensive file attachment handling

// MARK: - Notifications
/// Custom notifications for local service coordination:
/// - .localServiceExecutePrompt: Defined in ServiceManager.swift
/// - .regenerateLocalResponse: Used for message regeneration