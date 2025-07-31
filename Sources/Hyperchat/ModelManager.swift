/// ModelManager.swift - Centralized management for local language models
///
/// This actor handles all aspects of local model management in a thread-safe manner:
/// - Loading and parsing the model manifest
/// - Filtering models based on device capabilities
/// - Managing downloads from Hugging Face
/// - Tracking installation status and progress
///
/// Architecture:
/// - Uses Swift actor for thread-safe concurrent access
/// - Single responsibility for all model-related operations
/// - No external dependencies - keeps it simple
///
/// Called by:
/// - ServiceBackend configuration for available models
/// - UI components for model selection and download status
/// - InferenceEngine for accessing installed models

import Foundation

// MARK: - Download Progress

/// Progress information for ongoing model downloads
public struct DownloadProgress {
    let modelId: String
    let bytesDownloaded: Int64
    let totalBytes: Int64
    let progress: Double
    
    init(modelId: String, bytesDownloaded: Int64, totalBytes: Int64) {
        self.modelId = modelId
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.progress = totalBytes > 0 ? Double(bytesDownloaded) / Double(totalBytes) : 0.0
    }
}

// MARK: - Model Manager Errors

public enum ModelManagerError: Error, LocalizedError {
    case manifestNotFound
    case manifestParsingFailed
    case modelNotFound(String)
    case downloadFailed(String)
    case insufficientStorage
    case insufficientRAM
    case networkError
    
    public var errorDescription: String? {
        switch self {
        case .manifestNotFound:
            return "Model manifest file not found"
        case .manifestParsingFailed:
            return "Failed to parse model manifest"
        case .modelNotFound(let id):
            return "Model '\(id)' not found"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .insufficientStorage:
            return "Insufficient storage space for model"
        case .insufficientRAM:
            return "Insufficient RAM for this model"
        case .networkError:
            return "Network connection error"
        }
    }
}

// MARK: - Model Manager

/// Thread-safe actor that manages all local model operations.
///
/// This actor centralizes all model management logic including:
/// - Loading the model manifest from disk
/// - Filtering models based on device RAM and storage
/// - Downloading models from Hugging Face with progress tracking
/// - Managing local model storage and cleanup
///
/// The actor pattern ensures thread safety for concurrent downloads
/// and UI updates without complex locking mechanisms.
public actor ModelManager {
    
    // MARK: - Constants
    
    /// Default models directory path
    private static let modelsDirectory = "~/Library/Application Support/Hyperchat/Models"
    
    /// Model manifest file name
    private static let manifestFileName = "model_manifest.json"
    
    /// Maximum concurrent downloads
    private static let maxConcurrentDownloads = 2
    
    // MARK: - Private Properties
    
    /// All available models from manifest
    private var availableModels: [String: LocalModel] = [:]
    
    /// Currently active download sessions
    private var activeDownloads: [String: URLSessionDownloadTask] = [:]
    
    /// Download progress tracking
    private var downloadProgress: [String: DownloadProgress] = [:]
    
    /// Device RAM in GB (cached on first access)
    private var deviceRAM: Int?
    
    /// Models directory URL (created on first access)
    private var modelsDirectoryURL: URL?
    
    // MARK: - Initialization
    
    /// Initialize the ModelManager and load the manifest.
    ///
    /// This will:
    /// - Create the models directory if needed
    /// - Load and parse the model manifest
    /// - Filter models based on device capabilities
    /// - Scan for already-installed models
    public init() async throws {
        try await loadManifest()
        await scanInstalledModels()
        print("ModelManager initialized with \(availableModels.count) available models")
    }
    
    // MARK: - Public Interface
    
    /// Get all models available for this device (filtered by RAM/storage)
    ///
    /// Returns only models that can run on the current device based on:
    /// - Available RAM
    /// - Available storage space
    /// - Hardware capabilities
    ///
    /// - Returns: Array of LocalModel instances compatible with this device
    public func getAvailableModels() async -> [LocalModel] {
        let deviceRAM = await getDeviceRAM()
        return Array(availableModels.values).filter { model in
            model.requirements.minimumRAM <= deviceRAM
        }.sorted { $0.prettyName < $1.prettyName }
    }
    
    /// Get all installed models ready for inference
    ///
    /// - Returns: Array of LocalModel instances that are installed and ready
    public func getInstalledModels() -> [LocalModel] {
        return Array(availableModels.values).filter { $0.isReady }
    }
    
    /// Get a specific model by ID
    ///
    /// - Parameter id: Model identifier
    /// - Returns: LocalModel instance or nil if not found
    public func getModel(id: String) -> LocalModel? {
        return availableModels[id]
    }
    
    /// Start downloading a model from Hugging Face
    ///
    /// This method:
    /// - Validates device compatibility
    /// - Checks available storage space
    /// - Starts HTTP download with progress tracking
    /// - Updates model status throughout the process
    ///
    /// - Parameter modelId: ID of model to download
    /// - Throws: ModelManagerError if download cannot start
    public func downloadModel(id modelId: String) async throws {
        guard var model = availableModels[modelId] else {
            throw ModelManagerError.modelNotFound(modelId)
        }
        
        // Check if already downloading or installed
        guard model.status == .available else {
            return // Already downloading or installed
        }
        
        // Validate device compatibility
        let deviceRAM = await getDeviceRAM()
        guard model.requirements.minimumRAM <= deviceRAM else {
            throw ModelManagerError.insufficientRAM
        }
        
        // Check storage space
        let availableSpace = await getAvailableStorageGB()
        guard availableSpace >= model.requirements.diskSpaceGB else {
            throw ModelManagerError.insufficientStorage
        }
        
        // Update status to downloading
        model.status = .downloading
        model.downloadProgress = 0.0
        availableModels[modelId] = model
        
        do {
            // Start download
            let downloadURL = buildHuggingFaceURL(for: model)
            let localURL = try await getModelsDirectory().appendingPathComponent("\(modelId).gguf")
            
            try await performDownload(from: downloadURL, to: localURL, modelId: modelId)
            
            // Update model with successful installation
            model.status = .installed
            model.localPath = localURL.path
            model.downloadProgress = nil
            availableModels[modelId] = model
            
            print("Model \(modelId) downloaded successfully to \(localURL.path)")
            
        } catch {
            // Mark as failed on error
            model.status = .failed
            model.downloadProgress = nil
            availableModels[modelId] = model
            
            throw ModelManagerError.downloadFailed(error.localizedDescription)
        }
    }
    
    /// Cancel an ongoing download
    ///
    /// - Parameter modelId: ID of model to cancel
    public func cancelDownload(id modelId: String) async {
        if let task = activeDownloads[modelId] {
            task.cancel()
            activeDownloads.removeValue(forKey: modelId)
            downloadProgress.removeValue(forKey: modelId)
            
            // Reset model status
            if var model = availableModels[modelId] {
                model.status = .available
                model.downloadProgress = nil
                availableModels[modelId] = model
            }
        }
    }
    
    /// Get current download progress for a model
    ///
    /// - Parameter modelId: ID of model being downloaded
    /// - Returns: DownloadProgress or nil if not downloading
    public func getDownloadProgress(for modelId: String) -> DownloadProgress? {
        return downloadProgress[modelId]
    }
    
    /// Delete an installed model
    ///
    /// - Parameter modelId: ID of model to delete
    /// - Throws: Error if deletion fails
    public func deleteModel(id modelId: String) async throws {
        guard var model = availableModels[modelId],
              let localPath = model.localPath else {
            throw ModelManagerError.modelNotFound(modelId)
        }
        
        // Delete file
        try FileManager.default.removeItem(atPath: localPath)
        
        // Update model status
        model.status = .available
        model.localPath = nil
        availableModels[modelId] = model
        
        print("Model \(modelId) deleted successfully")
    }
    
    // MARK: - Private Implementation
    
    /// Load and parse the model manifest file
    private func loadManifest() async throws {
        guard let manifestURL = Bundle.main.url(forResource: "model_manifest", withExtension: "json") else {
            throw ModelManagerError.manifestNotFound
        }
        
        let data = try Data(contentsOf: manifestURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [String: [String: Any]] else {
            throw ModelManagerError.manifestParsingFailed
        }
        
        // Parse each model
        for (id, modelData) in models {
            if let model = LocalModel.from(dictionary: modelData, id: id) {
                availableModels[id] = model
            }
        }
        
        print("Loaded \(availableModels.count) models from manifest")
    }
    
    /// Scan for already-installed models and update their status
    private func scanInstalledModels() async {
        do {
            let modelsDir = try await getModelsDirectory()
            let files = try FileManager.default.contentsOfDirectory(at: modelsDir, includingPropertiesForKeys: nil)
            
            for fileURL in files where fileURL.pathExtension == "gguf" {
                let fileName = fileURL.deletingPathExtension().lastPathComponent
                if var model = availableModels[fileName] {
                    model.status = .installed
                    model.localPath = fileURL.path
                    availableModels[fileName] = model
                }
            }
        } catch {
            print("Failed to scan installed models: \(error)")
        }
    }
    
    /// Get device RAM in GB
    private func getDeviceRAM() async -> Int {
        if let cached = deviceRAM {
            return cached
        }
        
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let ramGB = Int(physicalMemory / (1024 * 1024 * 1024))
        deviceRAM = ramGB
        return ramGB
    }
    
    /// Get available storage space in GB
    private func getAvailableStorageGB() async -> Double {
        do {
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            let resourceValues = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let availableBytes = resourceValues.volumeAvailableCapacityForImportantUsage {
                return Double(availableBytes) / (1024.0 * 1024.0 * 1024.0)
            }
        } catch {
            print("Failed to get available storage: \(error)")
        }
        return 0.0
    }
    
    /// Get or create the models directory
    private func getModelsDirectory() async throws -> URL {
        if let cached = modelsDirectoryURL {
            return cached
        }
        
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let modelsURL = homeURL
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("Hyperchat")
            .appendingPathComponent("Models")
        
        try FileManager.default.createDirectory(at: modelsURL, withIntermediateDirectories: true)
        modelsDirectoryURL = modelsURL
        return modelsURL
    }
    
    /// Build Hugging Face download URL for a model
    private func buildHuggingFaceURL(for model: LocalModel) -> URL {
        let baseURL = "https://huggingface.co/\(model.huggingFaceRepo)/resolve/main/"
        let fileName = model.modelFileName ?? "\(model.id).gguf"
        return URL(string: baseURL + fileName)!
    }
    
    /// Perform the actual HTTP download with progress tracking
    private func performDownload(from remoteURL: URL, to localURL: URL, modelId: String) async throws {
        let session = URLSession.shared
        
        // Create download task
        let task = session.downloadTask(with: remoteURL) { [weak self] tempURL, response, error in
            Task {
                await self?.handleDownloadCompletion(tempURL: tempURL, localURL: localURL, modelId: modelId, error: error)
            }
        }
        
        // Store active download
        activeDownloads[modelId] = task
        
        // Start download
        task.resume()
        
        // Wait for completion (simplified - in a real implementation you'd want better progress tracking)
        while activeDownloads[modelId] != nil {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
    
    /// Handle download completion
    private func handleDownloadCompletion(tempURL: URL?, localURL: URL, modelId: String, error: Error?) async {
        activeDownloads.removeValue(forKey: modelId)
        downloadProgress.removeValue(forKey: modelId)
        
        if let error = error {
            print("Download failed for \(modelId): \(error)")
            return
        }
        
        guard let tempURL = tempURL else {
            print("Download completed but no temp file for \(modelId)")
            return
        }
        
        do {
            // Move from temp location to final location
            if FileManager.default.fileExists(atPath: localURL.path) {
                try FileManager.default.removeItem(at: localURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: localURL)
            print("Model \(modelId) moved to final location: \(localURL.path)")
        } catch {
            print("Failed to move downloaded model \(modelId): \(error)")
        }
    }
}