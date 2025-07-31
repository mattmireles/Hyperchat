import SwiftUI

// MARK: - Message Structure
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let isFromUser: Bool
    var text: String
}

// MARK: - Local Chat View
struct LocalChatView: View {
    // --- State ---
    @State private var messages: [ChatMessage] = []
    @State private var isGenerating: Bool = false
    
    // --- Engine ---
    private var inferenceEngine: InferenceEngine?
    
    // --- Service Info ---
    private let serviceId: String

    // --- Initializer ---
    init(modelPath: String, serviceId: String = "local_llama") {
        self.serviceId = serviceId
        do {
            self.inferenceEngine = try InferenceEngine(modelPath: modelPath)
        } catch {
            // TODO: Proper error handling UI
            print("❌ Failed to initialize InferenceEngine: \(error)")
            self.inferenceEngine = nil
        }
    }

    // --- Body ---
    var body: some View {
        VStack {
            if messages.isEmpty {
                // Show placeholder when no messages
                VStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("Local AI Ready")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Use the unified input bar below to chat")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Show messages when conversation exists
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            MessageView(message: message)
                        }
                        
                        // Show generating indicator
                        if isGenerating {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Generating...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.leading, 12)
                        }
                    }
                    .padding()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .localServiceExecutePrompt)) { notification in
            handlePromptNotification(notification)
        }
    }
    
    // --- Actions ---
    
    /// Handles prompt execution notifications from ServiceManager
    private func handlePromptNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let notificationServiceId = userInfo["serviceId"] as? String,
              let prompt = userInfo["prompt"] as? String,
              notificationServiceId == serviceId else {
            return // This notification is not for this service instance
        }
        
        executePrompt(prompt)
    }
    
    /// Executes a prompt using the local inference engine
    private func executePrompt(_ prompt: String) {
        guard !prompt.isEmpty, let engine = inferenceEngine else { return }
        
        let userMessage = ChatMessage(isFromUser: true, text: prompt)
        messages.append(userMessage)
        
        isGenerating = true

        let botMessagePlaceholder = ChatMessage(isFromUser: false, text: "")
        messages.append(botMessagePlaceholder)
        let botMessageIndex = messages.count - 1
        
        Task {
            do {
                let stream = await engine.generate(for: prompt)
                for try await token in stream {
                    DispatchQueue.main.async {
                        self.messages[botMessageIndex].text += token
                    }
                }
            } catch {
                print("❌ Inference failed: \(error)")
                DispatchQueue.main.async {
                    self.messages[botMessageIndex].text = "Error: Failed to generate response"
                }
            }
            
            DispatchQueue.main.async {
                isGenerating = false
            }
        }
    }
}

// MARK: - Message Bubble View
struct MessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
            Text(message.text)
                .padding(10)
                .background(message.isFromUser ? Color.blue : Color(NSColor.secondarySystemFill))
                .foregroundColor(message.isFromUser ? .white : .primary)
                .cornerRadius(10)

            if !message.isFromUser {
                Spacer()
            }
        }
    }
}