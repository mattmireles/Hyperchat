/// LocalLLMHeader.swift - Sophisticated Header for Local LLM Interface
///
/// This component provides an elegant header section for the local LLM chat interface,
/// featuring gradient styling, model selection, and status indicators that match
/// Apple's design language and the app's visual theme.
///
/// Features:
/// - "Local LLM" title with app-consistent gradient styling
/// - Model selection dropdown with native macOS appearance
/// - Connection status indicator with real-time updates
/// - Model information display (name, size, capabilities)
/// - Sophisticated hover effects and micro-interactions
/// - Proper accessibility support
///
/// This component is used by:
/// - `LocalChatView.swift` as the main header section
/// - Future local model management interfaces
///
/// Related files:
/// - `GradientToolbarButton.swift` - Shares gradient color scheme
/// - `MessageBubble.swift` - Consistent visual theming
/// - `ServiceManager.swift` - Model loading and management
/// - `InferenceEngine.swift` - Model status and capabilities

import SwiftUI
import Combine

// MARK: - Header Styling Constants

/// Visual styling constants for the header component
private enum HeaderStyle {
    /// Gradient colors matching the app theme
    static let gradientColors = [
        Color(red: 1.0, green: 0.0, blue: 0.8),  // Pink
        Color(red: 0.6, green: 0.2, blue: 0.8),  // Purple
        Color(red: 0.0, green: 0.6, blue: 1.0)   // Blue
    ]
    
    /// Typography settings
    static let titleFontSize: CGFloat = 28
    static let subtitleFontSize: CGFloat = 14
    static let statusFontSize: CGFloat = 12
    
    /// Layout constants
    static let headerPadding: CGFloat = 20
    static let elementSpacing: CGFloat = 12
    static let iconSize: CGFloat = 24
    static let statusIndicatorSize: CGFloat = 8
    
    /// Colors for different states
    static let connectedColor = Color.green
    static let disconnectedColor = Color.red
    static let loadingColor = Color.orange
    static let secondaryTextColor = Color.secondary.opacity(0.8)
}

// MARK: - Model Information

/// Represents information about a loaded model
struct ModelInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: String
    let sizeGB: Double
    let architecture: String
    let contextLength: Int
    let isLoaded: Bool
    let loadingProgress: Double? // 0.0 to 1.0 when loading
    
    var displayName: String {
        return name.replacingOccurrences(of: "-", with: " ").capitalized
    }
    
    var sizeDescription: String {
        return String(format: "%.1f GB", sizeGB)
    }
    
    var contextDescription: String {
        if contextLength >= 1000000 {
            return String(format: "%.1fM context", Double(contextLength) / 1000000.0)
        } else if contextLength >= 1000 {
            return String(format: "%.0fK context", Double(contextLength) / 1000.0)
        } else {
            return "\(contextLength) context"
        }
    }
}

// MARK: - Connection Status

/// Represents the current connection status of the local LLM
enum LocalLLMStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
    
    var displayText: String {
        switch self {
        case .disconnected:
            return "Not Connected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Ready"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var statusColor: Color {
        switch self {
        case .disconnected:
            return HeaderStyle.disconnectedColor
        case .connecting:
            return HeaderStyle.loadingColor
        case .connected:
            return HeaderStyle.connectedColor
        case .error:
            return HeaderStyle.disconnectedColor
        }
    }
    
    var systemIcon: String {
        switch self {
        case .disconnected:
            return "circle"
        case .connecting:
            return "circle.dotted"
        case .connected:
            return "circle.fill"
        case .error:
            return "exclamationmark.circle"
        }
    }
}

// MARK: - Local LLM Header Component

/// Sophisticated header for the local LLM interface
struct LocalLLMHeader: View {
    // MARK: - State
    @State private var selectedModel: ModelInfo?
    @State private var availableModels: [ModelInfo] = []
    @State private var connectionStatus: LocalLLMStatus = .disconnected
    @State private var isHoveringTitle = false
    @State private var isShowingModelPicker = false
    
    // MARK: - Bindings
    let onModelSelected: (ModelInfo) -> Void
    let onRefreshModels: () -> Void
    
    // MARK: - Publishers for external updates
    @StateObject private var statusObserver = StatusObserver()
    
    init(onModelSelected: @escaping (ModelInfo) -> Void, onRefreshModels: @escaping () -> Void) {
        self.onModelSelected = onModelSelected
        self.onRefreshModels = onRefreshModels
    }
    
    var body: some View {
        VStack(spacing: HeaderStyle.elementSpacing) {
            // Main header section
            headerContent
            
            // Model selection and status
            modelSelectionSection
            
            // Divider
            headerDivider
        }
        .padding(HeaderStyle.headerPadding)
        .onAppear {
            loadAvailableModels()
            startStatusMonitoring()
        }
    }
    
    // MARK: - Header Content
    
    /// Main title and branding section
    @ViewBuilder
    private var headerContent: some View {
        HStack {
            // App icon or logo space
            Image(systemName: "brain.head.profile")
                .font(.system(size: HeaderStyle.iconSize, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: HeaderStyle.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(isHoveringTitle ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHoveringTitle)
            
            // Title with gradient effect
            Text("Local LLM")
                .font(.system(size: HeaderStyle.titleFontSize, weight: .bold, design: .default))
                .foregroundStyle(
                    LinearGradient(
                        colors: HeaderStyle.gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .scaleEffect(isHoveringTitle ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHoveringTitle)
            
            Spacer()
            
            // Status indicator
            statusIndicator
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHoveringTitle = hovering
            }
        }
    }
    
    /// Model selection and information section
    @ViewBuilder
    private var modelSelectionSection: some View {
        HStack(spacing: 16) {
            // Model selector
            modelPicker
            
            Spacer()
            
            // Model information
            if let model = selectedModel {
                modelInfoView(model)
            }
            
            // Refresh button
            refreshButton
        }
    }
    
    /// Connection status indicator
    @ViewBuilder
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: connectionStatus.systemIcon)
                .font(.system(size: HeaderStyle.statusFontSize, weight: .medium))
                .foregroundColor(connectionStatus.statusColor)
                .scaleEffect(connectionStatus == .connecting ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                          value: connectionStatus == .connecting)
            
            Text(connectionStatus.displayText)
                .font(.system(size: HeaderStyle.statusFontSize, weight: .medium))
                .foregroundColor(HeaderStyle.secondaryTextColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
    
    /// Model selection picker
    @ViewBuilder
    private var modelPicker: some View {
        Menu {
            if availableModels.isEmpty {
                Text("No models found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(availableModels) { model in
                    Button(action: {
                        selectModel(model)
                    }) {
                        HStack {
                            Text(model.displayName)
                            Spacer()
                            if model.id == selectedModel?.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Divider()
                
                Button("Browse for Model...") {
                    browseForModel()
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "brain")
                    .font(.system(size: 14, weight: .medium))
                
                Text(selectedModel?.displayName ?? "Select Model")
                    .font(.system(size: HeaderStyle.subtitleFontSize, weight: .medium))
                    .lineLimit(1)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .menuStyle(.borderlessButton)
    }
    
    /// Model information display
    @ViewBuilder
    private func modelInfoView(_ model: ModelInfo) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(model.sizeDescription)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(model.contextDescription)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.secondary.opacity(0.8))
        }
    }
    
    /// Refresh models button
    @ViewBuilder
    private var refreshButton: some View {
        Button(action: {
            refreshModels()
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .help("Refresh available models")
    }
    
    /// Header divider with gradient
    @ViewBuilder
    private var headerDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: HeaderStyle.gradientColors.map { $0.opacity(0.2) },
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
    
    // MARK: - Actions
    
    /// Load available models from the system
    private func loadAvailableModels() {
        // TODO: Integrate with actual model discovery
        // For now, create sample models
        let sampleModels = [
            ModelInfo(name: "llama-2-7b-chat", path: "/models/llama-2-7b-chat.gguf",
                     sizeGB: 3.8, architecture: "Llama", contextLength: 4096, isLoaded: false, loadingProgress: nil),
            ModelInfo(name: "mixtral-8x7b-instruct", path: "/models/mixtral-8x7b-instruct.gguf",
                     sizeGB: 26.9, architecture: "Mixtral", contextLength: 32768, isLoaded: false, loadingProgress: nil),
            ModelInfo(name: "phi-3-mini-instruct", path: "/models/phi-3-mini-instruct.gguf",
                     sizeGB: 2.2, architecture: "Phi-3", contextLength: 128000, isLoaded: false, loadingProgress: nil)
        ]
        
        availableModels = sampleModels
        
        // Auto-select the first model if none is selected
        if selectedModel == nil && !availableModels.isEmpty {
            selectedModel = availableModels.first
        }
    }
    
    /// Select a specific model
    private func selectModel(_ model: ModelInfo) {
        selectedModel = model
        connectionStatus = .connecting
        onModelSelected(model)
        
        // Simulate loading process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            connectionStatus = .connected
        }
    }
    
    /// Open file browser to select a model
    private func browseForModel() {
        let panel = NSOpenPanel()
        panel.title = "Select Model File"
        panel.allowedContentTypes = [.init(filenameExtension: "gguf")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            let customModel = ModelInfo(
                name: url.deletingPathExtension().lastPathComponent,
                path: url.path,
                sizeGB: Double(url.fileSize) / (1024 * 1024 * 1024),
                architecture: "Unknown",
                contextLength: 4096,
                isLoaded: false,
                loadingProgress: nil
            )
            
            availableModels.append(customModel)
            selectModel(customModel)
        }
    }
    
    /// Refresh the list of available models
    private func refreshModels() {
        onRefreshModels()
        loadAvailableModels()
    }
    
    /// Start monitoring connection status
    private func startStatusMonitoring() {
        // TODO: Implement actual status monitoring
        // This would typically observe notifications from InferenceEngine
    }
}

// MARK: - Status Observer

/// ObservableObject for monitoring local LLM status changes
private class StatusObserver: ObservableObject {
    @Published var status: LocalLLMStatus = .disconnected
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // TODO: Subscribe to actual status notifications
        // NotificationCenter.default.publisher(for: .localLLMStatusChanged)
        //     .sink { [weak self] notification in
        //         // Update status based on notification
        //     }
        //     .store(in: &cancellables)
    }
}

// MARK: - File Size Extension

extension URL {
    var fileSize: Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LocalLLMHeader_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            LocalLLMHeader(
                onModelSelected: { model in
                    print("Selected model: \(model.name)")
                },
                onRefreshModels: {
                    print("Refreshing models...")
                }
            )
            
            Spacer()
        }
        .frame(width: 600, height: 200)
        .background(Color(.windowBackgroundColor))
        .previewDisplayName("Local LLM Header")
    }
}
#endif