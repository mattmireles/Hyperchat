import SwiftUI
import InferenceEngine

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
    @State private var inputText: String = ""
    @State private var isGenerating: Bool = false
    
    // --- Engine ---
    private var inferenceEngine: InferenceEngine?

    // --- Initializer ---
    init(modelPath: String) {
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
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        MessageView(message: message)
                    }
                }
                .padding()
            }

            HStack {
                TextField("Type your message...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isGenerating)

                Button(action: sendMessage) {
                    if isGenerating {
                        ProgressView()
                    } else {
                        Text("Send")
                    }
                }
                .disabled(inputText.isEmpty || isGenerating)
            }
            .padding()
        }
    }
    
    // --- Actions ---
    private func sendMessage() {
        guard !inputText.isEmpty, let engine = inferenceEngine else { return }
        
        let userMessage = ChatMessage(isFromUser: true, text: inputText)
        messages.append(userMessage)
        
        let prompt = inputText
        inputText = ""
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