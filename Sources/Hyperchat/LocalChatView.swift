/// LocalChatView.swift - WebView-Based Local LLM Chat Interface
///
/// This file provides a WebView-based chat interface for local LLM interactions.
/// It replaces the previous complex SwiftUI implementation with a simpler approach
/// using HTML/CSS/JS loaded into a WKWebView, following the "simpler is better" philosophy.
///
/// Key features:
/// - Single HTML file with embedded CSS and JavaScript
/// - Replicates original UI design (gradients, glass morphism, animations)
/// - Real-time streaming from InferenceEngine via JavaScript bridge
/// - Markdown rendering with syntax highlighting
/// - Clean bidirectional Swift-JavaScript communication
///
/// Architecture:
/// - WKWebView hosts local HTML file from app bundle
/// - WKScriptMessageHandler enables JavaScript → Swift communication
/// - evaluateJavaScript enables Swift → JavaScript communication
/// - InferenceEngine integration for local model inference
///
/// Related files:
/// - `local_chat.html` - Complete HTML/CSS/JS interface
/// - `InferenceEngine.swift` - Local AI inference and streaming
/// - `ServiceManager.swift` - Service orchestration and prompt routing

import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

/// WebView-based local LLM chat interface
struct LocalChatView: View {
    // MARK: - Properties
    private let model: LocalModel
    private let serviceId: String
    private let inferenceEngine: InferenceEngine?
    
    // MARK: - State
    @StateObject private var webViewCoordinator = WebViewCoordinator()
    
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
    
    // MARK: - Body
    
    var body: some View {
        WebViewContainer(
            coordinator: webViewCoordinator,
            inferenceEngine: inferenceEngine,
            serviceId: serviceId
        )
        .onReceive(NotificationCenter.default.publisher(for: .localServiceExecutePrompt)) { notification in
            handlePromptNotification(notification)
        }
        .onAppear {
            webViewCoordinator.setupInferenceEngine(inferenceEngine)
        }
    }
    
    // MARK: - Event Handlers
    
    /// Handle prompt execution from the unified input bar
    private func handlePromptNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let notificationServiceId = userInfo["serviceId"] as? String,
              let prompt = userInfo["prompt"] as? String,
              notificationServiceId == serviceId else {
            print("🔍 LocalChatView (\(serviceId)): Ignoring notification for different service")
            return
        }
        
        print("✅ LocalChatView (\(serviceId)): Received prompt notification: \(prompt)")
        webViewCoordinator.executePrompt(prompt)
    }
}

// MARK: - WebView Container

/// SwiftUI wrapper for WKWebView with message handling
struct WebViewContainer: NSViewRepresentable {
    let coordinator: WebViewCoordinator
    let inferenceEngine: InferenceEngine?
    let serviceId: String
    
    func makeNSView(context: Context) -> WKWebView {
        return coordinator.createWebView()
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No updates needed
    }
}

// MARK: - WebView Coordinator

/// Coordinator class to handle WebView setup and message passing
class WebViewCoordinator: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {
    private var webView: WKWebView?
    private var inferenceEngine: InferenceEngine?
    
    // MARK: - WebView Setup
    
    func createWebView() -> WKWebView {
        // Configure WebView
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = WKUserContentController()
        
        // Add message handler for JavaScript → Swift communication
        configuration.userContentController.add(self, name: "localLLM")
        
        // Create WebView
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        
        // Load local HTML file
        loadLocalHTML()
        
        return webView
    }
    
    func setupInferenceEngine(_ engine: InferenceEngine?) {
        self.inferenceEngine = engine
    }
    
    // MARK: - HTML Loading
    
    private func loadLocalHTML() {
        guard let webView = webView else { return }
        
        // Get path to local HTML file from bundle
        guard let htmlPath = Bundle.main.path(forResource: "local_chat", ofType: "html"),
              let htmlURL = URL(string: "file://\(htmlPath)") else {
            print("❌ Could not find local_chat.html in app bundle")
            loadFallbackHTML()
            return
        }
        
        // Load HTML file
        let request = URLRequest(url: htmlURL)
        webView.load(request)
        
        print("✅ Loading local chat HTML from bundle: \(htmlPath)")
    }
    
    private func loadFallbackHTML() {
        guard let webView = webView else { return }
        
        // Fallback HTML for development/testing
        let fallbackHTML = """
        <html>
        <head><title>Local Chat</title></head>
        <body style="font-family: -apple-system; padding: 20px; background: #f5f5f7;">
            <h1>Local Chat Interface</h1>
            <p>HTML file not found. Please ensure local_chat.html is included in the app bundle.</p>
            <form id="test-form">
                <input type="text" id="test-input" placeholder="Test message..." style="width: 100%; padding: 10px; margin: 10px 0;">
                <button type="submit">Send Test</button>
            </form>
            <script>
                document.getElementById('test-form').addEventListener('submit', function(e) {
                    e.preventDefault();
                    const input = document.getElementById('test-input');
                    const message = input.value.trim();
                    if (message && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.localLLM) {
                        window.webkit.messageHandlers.localLLM.postMessage({
                            action: 'submit_prompt',
                            prompt: message
                        });
                        input.value = '';
                    }
                });
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(fallbackHTML, baseURL: nil)
        print("⚠️ Loaded fallback HTML - local_chat.html not found")
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ WebView finished loading local chat interface")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView navigation failed: \(error.localizedDescription)")
    }
    
    // MARK: - Message Handling
    
    /// Handle messages from JavaScript
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else {
            print("❌ Invalid message format from JavaScript")
            return
        }
        
        print("📥 Received JavaScript message: \(action)")
        
        switch action {
        case "submit_prompt":
            if let prompt = body["prompt"] as? String {
                handlePromptFromJavaScript(prompt)
            }
        case "add_model_from_file":
            handleAddModelFromFile()
        case "find_all_models_advanced":
            handleFindAllModelsAdvanced()
        case "load_model_from_path":
            if let path = body["path"] as? String {
                loadModelFromPath(path)
            }
        default:
            print("⚠️ Unknown action from JavaScript: \(action)")
        }
    }
    
    /// Execute prompt via external notification (from input bar)
    func executePrompt(_ prompt: String) {
        handlePromptFromJavaScript(prompt)
    }
    
    /// Handle prompt submission and generate response
    private func handlePromptFromJavaScript(_ prompt: String) {
        guard !prompt.isEmpty else {
            print("❌ Empty prompt received")
            return
        }
        
        guard let engine = inferenceEngine else {
            print("❌ No inference engine available")
            sendErrorToJavaScript("Model not ready for inference. Please check model installation.")
            return
        }
        
        print("🚀 Executing prompt: \(prompt)")
        
        // Start assistant message in JavaScript
        evaluateJavaScript("startAssistantMessage();")
        
        // Generate response using InferenceEngine
        Task {
            let startTime = Date()
            var tokenCount = 0
            
            do {
                let stream = await engine.generate(for: prompt)
                
                for try await token in stream {
                    tokenCount += 1
                    
                    // Escape token for JavaScript and send
                    let escapedToken = token.replacingOccurrences(of: "'", with: "\\'")
                                          .replacingOccurrences(of: "\\", with: "\\\\")
                                          .replacingOccurrences(of: "\n", with: "\\n")
                                          .replacingOccurrences(of: "\r", with: "\\r")
                    
                    DispatchQueue.main.async {
                        self.evaluateJavaScript("appendTokenToLastMessage('\(escapedToken)');")
                    }
                }
                
                // Mark as completed
                let processingTime = Int(Date().timeIntervalSince(startTime) * 1000)
                print("✅ Generated \(tokenCount) tokens in \(processingTime)ms")
                
                DispatchQueue.main.async {
                    self.evaluateJavaScript("finishAssistantMessage();")
                }
                
            } catch {
                print("❌ Inference failed: \(error)")
                
                DispatchQueue.main.async {
                    self.sendErrorToJavaScript("Failed to generate response: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - JavaScript Communication
    
    /// Send JavaScript command to WebView
    private func evaluateJavaScript(_ script: String) {
        webView?.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("❌ JavaScript execution error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Send error message to JavaScript
    private func sendErrorToJavaScript(_ errorMessage: String) {
        let escapedError = errorMessage.replacingOccurrences(of: "'", with: "\\'")
                                     .replacingOccurrences(of: "\\", with: "\\\\")
        evaluateJavaScript("showErrorMessage('\(escapedError)');")
    }
    
    // MARK: - Model Finder Actions
    
    /// Handle "Add Model from File..." button - shows native file picker
    private func handleAddModelFromFile() {
        print("🔍 Opening native file picker for model selection")
        
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = false
            openPanel.canChooseFiles = true
            openPanel.allowedContentTypes = [UTType(filenameExtension: "gguf") ?? UTType.data]
            openPanel.title = "Select GGUF Model File"
            openPanel.message = "Choose a GGUF model file to load"
            
            let response = openPanel.runModal()
            
            if response == .OK, let selectedURL = openPanel.url {
                print("✅ User selected model file: \(selectedURL.path)")
                self.handleSelectedModelFile(selectedURL)
            } else {
                print("❌ User cancelled file selection")
                self.resetAddModelButton()
            }
        }
    }
    
    /// Handle "Find all models... (advanced)" button - scans file system
    private func handleFindAllModelsAdvanced() {
        print("🔍 Starting advanced model scan of home directory")
        
        Task.detached {
            let startTime = Date()
            var foundModels: [String] = []
            
            do {
                let homeURL = FileManager.default.homeDirectoryForCurrentUser
                print("📂 Scanning directory: \(homeURL.path)")
                
                let resourceKeys: [URLResourceKey] = [.nameKey, .isDirectoryKey, .fileSizeKey]
                guard let enumerator = FileManager.default.enumerator(
                    at: homeURL,
                    includingPropertiesForKeys: resourceKeys,
                    options: [.skipsPackageDescendants]
                ) else {
                    throw NSError(domain: "ModelScan", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create file enumerator"])
                }
                
                for case let url as URL in enumerator {
                    // Check if file has .gguf extension
                    if url.pathExtension.lowercased() == "gguf" {
                        foundModels.append(url.path)
                        print("🎯 Found model: \(url.lastPathComponent)")
                    }
                }
                
                let scanTime = Date().timeIntervalSince(startTime)
                print("✅ Scan completed in \(String(format: "%.2f", scanTime))s, found \(foundModels.count) models")
                
                DispatchQueue.main.async {
                    self.handleFoundModels(foundModels, scanTime: scanTime)
                }
                
            } catch {
                print("❌ Model scan failed: \(error)")
                DispatchQueue.main.async {
                    self.sendErrorToJavaScript("Model scan failed: \(error.localizedDescription)")
                    self.resetFindAllButton()
                }
            }
        }
    }
    
    /// Handle selected model file from file picker
    private func handleSelectedModelFile(_ url: URL) {
        let modelPath = url.path
        let modelName = url.lastPathComponent
        
        let message = """
        📁 Selected model file:
        
        **Name:** \(modelName)
        **Path:** `\(modelPath)`
        
        File picker completed instantly! ✨
        """
        
        evaluateJavaScript("showSystemMessage('\(message.replacingOccurrences(of: "'", with: "\\'"))');")
        resetAddModelButton()
    }
    
    /// Handle results from advanced model scan - send to JavaScript via callback
    private func handleFoundModels(_ modelPaths: [String], scanTime: TimeInterval) {
        do {
            // Serialize model paths to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: modelPaths, options: [])
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw NSError(domain: "JSONSerialization", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON data to string"])
            }
            
            // Call JavaScript completion callback with results and timing
            let javascript = "handleFoundModels(\(jsonString), \(String(format: "%.1f", scanTime)));"
            evaluateJavaScript(javascript)
            
            print("✅ Sent \(modelPaths.count) model paths to JavaScript after \(String(format: "%.1f", scanTime))s scan")
            
        } catch {
            print("❌ Failed to serialize model paths: \(error)")
            // Fallback to error callback
            evaluateJavaScript("handleSearchError('Failed to process search results: \(error.localizedDescription)');")
        }
    }
    
    /// Reset "Add Model from File..." button to original state
    private func resetAddModelButton() {
        evaluateJavaScript("""
            const button = document.getElementById('add-model-file-button');
            if (button) {
                button.disabled = false;
                button.textContent = 'Add Model from File...';
            }
        """)
    }
    
    /// Reset "Find all models... (advanced)" button to original state
    private func resetFindAllButton() {
        evaluateJavaScript("""
            const button = document.getElementById('find-all-models-button');
            if (button) {
                button.disabled = false;
                button.textContent = 'Find all models... (advanced)';
            }
        """)
    }
    
    // MARK: - Model Loading
    
    /// Load a new model from the specified file path
    private func loadModelFromPath(_ path: String) {
        print("🔄 Attempting to load model from path: \(path)")
        
        let modelName = URL(fileURLWithPath: path).lastPathComponent
        
        // Validate file exists
        guard FileManager.default.fileExists(atPath: path) else {
            print("❌ Model file not found at path: \(path)")
            let errorMessage = "Model file not found: \(modelName)"
            sendSystemMessageToJavaScript(errorMessage, type: "error")
            return
        }
        
        // Attempt to create new InferenceEngine
        do {
            let newEngine = try InferenceEngine(modelPath: path)
            
            // Replace the existing engine
            self.inferenceEngine = newEngine
            
            print("✅ Successfully loaded model: \(modelName)")
            let successMessage = "✅ Model loaded successfully: \(modelName)"
            sendSystemMessageToJavaScript(successMessage, type: "success")
            
        } catch {
            print("❌ Failed to load model \(modelName): \(error)")
            let errorMessage = "❌ Failed to load model: \(error.localizedDescription)"
            sendSystemMessageToJavaScript(errorMessage, type: "error")
        }
    }
    
    /// Send a system message to JavaScript with optional type styling
    private func sendSystemMessageToJavaScript(_ message: String, type: String = "info") {
        let escapedMessage = message.replacingOccurrences(of: "'", with: "\\'")
                                   .replacingOccurrences(of: "\\", with: "\\\\")
                                   .replacingOccurrences(of: "\n", with: "\\n")
                                   .replacingOccurrences(of: "\r", with: "\\r")
        
        let borderColor: String
        let backgroundColor: String
        let textColor: String
        
        switch type {
        case "success":
            borderColor = "#00cc44"
            backgroundColor = "rgba(0, 204, 68, 0.1)"
            textColor = "#00cc44"
        case "error":
            borderColor = "#ff4444"
            backgroundColor = "rgba(255, 68, 68, 0.1)"
            textColor = "#ff4444"
        default: // "info"
            borderColor = "#0099ff"
            backgroundColor = "rgba(0, 153, 255, 0.1)"
            textColor = "#0099ff"
        }
        
        let javascript = """
            const messageDiv = document.createElement('div');
            messageDiv.className = 'message assistant';
            messageDiv.innerHTML = `
                <div class="message-bubble" style="border-color: \(borderColor); background: \(backgroundColor);">
                    <div class="message-content" style="color: \(textColor);">
                        \(escapedMessage)
                    </div>
                </div>
            `;
            
            const chatHistory = document.getElementById('chat-history');
            messageDiv.onclick = function() {
                this.style.opacity = '0.5';
                setTimeout(() => this.remove(), 200);
            };
            chatHistory.appendChild(messageDiv);
            
            // Update message count and scroll
            messageCount++;
            updateEmptyState();
            scrollToBottom();
        """
        
        evaluateJavaScript(javascript)
    }
}

