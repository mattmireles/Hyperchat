/// LocalModel.swift - Local language model data structure
///
/// This file defines the core data structure for local language models,
/// including metadata for display, download management, and inference configuration.
///
/// Key responsibilities:
/// - Store model identification (technical name, pretty name, maker)
/// - Track download and installation status
/// - Provide chat template and inference parameters
/// - Support device compatibility filtering
///
/// Used by:
/// - `ModelManager.swift`: Manages collections of LocalModel instances
/// - `ServiceBackend.local`: Uses LocalModel instead of raw file paths
/// - `LocalChatView`: Displays model pretty names and maker info
/// - `InferenceEngine`: Accesses model file paths and parameters

import Foundation

// MARK: - Model Download Status

/// Tracks the current state of a model's download and installation.
///
/// State transitions:
/// - `available`: Model exists in manifest but not downloaded
/// - `downloading`: Currently downloading from Hugging Face
/// - `installed`: Downloaded and ready for inference
/// - `failed`: Download or installation failed
public enum ModelDownloadStatus: String, Codable {
    /// Model is available for download but not yet downloaded
    case available
    
    /// Model is currently being downloaded
    case downloading
    
    /// Model is downloaded and ready for inference
    case installed
    
    /// Download or installation failed
    case failed
}

// MARK: - Device Requirements

/// Defines minimum hardware requirements for a model.
///
/// Used by ModelManager to filter models based on device capabilities.
/// RAM requirements are estimates and may vary based on quantization.
public struct ModelRequirements: Codable {
    /// Minimum RAM required in GB
    let minimumRAM: Int
    
    /// Estimated disk space required in GB
    let diskSpaceGB: Double
    
    /// Whether GPU acceleration is recommended
    let recommendsGPU: Bool
    
    init(minimumRAM: Int, diskSpaceGB: Double, recommendsGPU: Bool = true) {
        self.minimumRAM = minimumRAM
        self.diskSpaceGB = diskSpaceGB
        self.recommendsGPU = recommendsGPU
    }
}

// MARK: - Local Model

/// Represents a local language model with complete metadata and status information.
///
/// This struct contains all information needed to:
/// - Display the model in the UI with proper branding
/// - Download the model from Hugging Face
/// - Configure the InferenceEngine for optimal performance
/// - Filter models based on device capabilities
///
/// Example usage:
/// ```swift
/// let model = LocalModel(
///     id: "microsoft-dialogpt-medium",
///     technicalName: "microsoft/DialoGPT-medium",
///     prettyName: "Microsoft DialoGPT Medium",
///     maker: "Microsoft",
///     huggingFaceRepo: "microsoft/DialoGPT-medium"
/// )
/// ```
public struct LocalModel: Codable, Identifiable {
    
    // MARK: - Identification
    
    /// Unique identifier for this model (used for file storage and caching)
    public let id: String
    
    /// Technical name from Hugging Face (e.g., "microsoft/DialoGPT-medium")
    public let technicalName: String
    
    /// User-friendly display name (e.g., "Microsoft DialoGPT Medium")
    public let prettyName: String
    
    /// Model creator/organization (e.g., "Microsoft", "Meta", "Anthropic")
    public let maker: String
    
    /// Optional logo/icon identifier for the maker
    public let makerLogo: String?
    
    // MARK: - Download Configuration
    
    /// Hugging Face repository identifier (e.g., "microsoft/DialoGPT-medium")
    public let huggingFaceRepo: String
    
    /// Specific model file to download (defaults to largest GGUF file if nil)
    public let modelFileName: String?
    
    /// Current download and installation status
    public var status: ModelDownloadStatus
    
    /// Local file path once downloaded (nil if not yet downloaded)
    public var localPath: String?
    
    /// Download progress (0.0 to 1.0, nil if not downloading)
    public var downloadProgress: Double?
    
    // MARK: - Hardware Requirements
    
    /// Minimum hardware requirements for this model
    public let requirements: ModelRequirements
    
    // MARK: - Inference Configuration
    
    /// Chat template for formatting prompts (Jinja2 format)
    /// If nil, ModelManager will attempt to fetch from Hugging Face
    public let chatTemplate: String?
    
    /// Recommended context window size
    public let contextSize: Int
    
    /// Model description for users
    public let description: String
    
    // MARK: - Initialization
    
    /// Initialize a LocalModel with required fields.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for file storage
    ///   - technicalName: Hugging Face technical name
    ///   - prettyName: User-friendly display name
    ///   - maker: Model creator/organization
    ///   - huggingFaceRepo: Hugging Face repository
    ///   - requirements: Hardware requirements
    ///   - description: User-facing description
    ///   - makerLogo: Optional logo identifier
    ///   - modelFileName: Specific file to download (optional)
    ///   - chatTemplate: Chat template string (optional)
    ///   - contextSize: Context window size (default 2048)
    public init(
        id: String,
        technicalName: String,
        prettyName: String,
        maker: String,
        huggingFaceRepo: String,
        requirements: ModelRequirements,
        description: String,
        makerLogo: String? = nil,
        modelFileName: String? = nil,
        chatTemplate: String? = nil,
        contextSize: Int = 2048
    ) {
        self.id = id
        self.technicalName = technicalName
        self.prettyName = prettyName
        self.maker = maker
        self.makerLogo = makerLogo
        self.huggingFaceRepo = huggingFaceRepo
        self.modelFileName = modelFileName
        self.status = .available
        self.localPath = nil
        self.downloadProgress = nil
        self.requirements = requirements
        self.chatTemplate = chatTemplate
        self.contextSize = contextSize
        self.description = description
    }
    
    // MARK: - Computed Properties
    
    /// Whether this model is ready for inference
    public var isReady: Bool {
        return status == .installed && localPath != nil
    }
    
    /// Whether this model is currently being downloaded
    public var isDownloading: Bool {
        return status == .downloading
    }
    
    /// Display name combining maker and pretty name
    public var fullDisplayName: String {
        return "\(maker) \(prettyName)"
    }
    
    /// Estimated download size in MB (based on requirements)
    public var estimatedSizeMB: Int {
        return Int(requirements.diskSpaceGB * 1024)
    }
}

// MARK: - Extensions

extension LocalModel {
    /// Create a LocalModel from a JSON dictionary (for manifest parsing)
    static func from(dictionary: [String: Any], id: String) -> LocalModel? {
        guard let technicalName = dictionary["technical_name"] as? String,
              let prettyName = dictionary["pretty_name"] as? String,
              let maker = dictionary["maker"] as? String,
              let huggingFaceRepo = dictionary["hugging_face_repo"] as? String,
              let description = dictionary["description"] as? String,
              let requirementsDict = dictionary["requirements"] as? [String: Any],
              let minimumRAM = requirementsDict["minimum_ram"] as? Int,
              let diskSpaceGB = requirementsDict["disk_space_gb"] as? Double else {
            return nil
        }
        
        let recommendsGPU = requirementsDict["recommends_gpu"] as? Bool ?? true
        let requirements = ModelRequirements(
            minimumRAM: minimumRAM,
            diskSpaceGB: diskSpaceGB,
            recommendsGPU: recommendsGPU
        )
        
        return LocalModel(
            id: id,
            technicalName: technicalName,
            prettyName: prettyName,
            maker: maker,
            huggingFaceRepo: huggingFaceRepo,
            requirements: requirements,
            description: description,
            makerLogo: dictionary["maker_logo"] as? String,
            modelFileName: dictionary["model_file_name"] as? String,
            chatTemplate: dictionary["chat_template"] as? String,
            contextSize: dictionary["context_size"] as? Int ?? 2048
        )
    }
}