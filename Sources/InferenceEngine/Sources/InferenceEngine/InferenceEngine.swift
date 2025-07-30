import Foundation
import CMistral // Still using this module name for our C-wrapper

// MARK: - Error Handling
public enum InferenceError: Error {
    case modelNotFound(String)
    case modelLoadFailed
    case contextCreationFailed
}

// MARK: - Inference Engine Actor
public actor InferenceEngine {
    
    // Pointers to the model and its context, managed by this actor
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    
    /// Initializes and loads a model from the given file path.
    ///
    /// This initializer performs the following steps:
    /// 1. Initializes the llama.cpp backend.
    /// 2. Sets up default model and context parameters.
    /// 3. Loads the specified GGUF model file.
    /// 4. Creates a context for inference with the loaded model.
    ///
    /// - Parameter modelPath: The file system path to the GGUF model file.
    /// - Throws: `InferenceError` if the model cannot be found, loaded, or if the context cannot be created.
    public init(modelPath: String) throws {
        // --- 1. Backend Initialization ---
        // Sets up the appropriate backend (e.g., Metal for Apple Silicon)
        llama_backend_init()
        
        // --- 2. Model Parameters ---
        // We use the default parameters for the model
        var modelParams = llama_model_default_params()
        
        // --- 3. Load the Model ---
        self.model = llama_load_model_from_file(modelPath, modelParams)
        guard let model = self.model else {
            // It's possible the model path was wrong.
            if !FileManager.default.fileExists(atPath: modelPath) {
                throw InferenceError.modelNotFound(modelPath)
            }
            throw InferenceError.modelLoadFailed
        }
        
        // --- 4. Context Parameters ---
        // We use the default parameters for the context
        var contextParams = llama_context_default_params()
        // TODO: These should be configurable in the future
        contextParams.n_ctx = 2048 // The maximum number of tokens in a sequence
        contextParams.n_threads = Int32(ProcessInfo.processInfo.activeProcessorCount)
        contextParams.n_threads_batch = Int32(ProcessInfo.processInfo.activeProcessorCount)

        // --- 5. Create the Context ---
        self.context = llama_new_context_with_model(model, contextParams)
        guard self.context != nil else {
            throw InferenceError.contextCreationFailed
        }
        
        print("InferenceEngine initialized successfully.")
    }
    
    /// Cleans up and releases all resources used by the engine.
    ///
    /// This deinitializer is CRITICAL for preventing memory leaks. It ensures that
    /// the model and context are freed from memory when the InferenceEngine instance
    /// is deallocated.
    deinit {
        if let context = self.context {
            llama_free(context)
        }
        if let model = self.model {
            llama_free_model(model)
        }
        llama_backend_free()
        print("InferenceEngine deinitialized and resources freed.")
    }
}