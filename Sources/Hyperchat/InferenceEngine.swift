/// InferenceEngine.swift - Local AI inference using llama.cpp
///
/// This actor provides a Swift wrapper around the llama.cpp C API for running
/// large language models locally on the user's machine.
/// 
/// Architecture:
/// - Uses actor isolation for thread-safe access to llama.cpp state
/// - Manages model loading and context creation
/// - Provides streaming text generation via AsyncThrowingStream
///
/// Called by:
/// - LocalChatView for local AI conversation features  
/// - Any UI component that needs on-device inference
///
/// This enables:
/// - Privacy-preserving local AI inference
/// - Offline functionality when internet is unavailable
/// - Reduced API costs by avoiding cloud services

import Foundation

/// Errors that can occur during local inference operations
public enum InferenceError: Error {
    case modelNotFound(String)
    case modelLoadFailed
    case contextCreationFailed
    case tokenizationFailed
    case decodeFailed
}

/// Actor that manages llama.cpp model and context for local AI inference.
///
/// Thread Safety:
/// - All llama.cpp operations are serialized through this actor
/// - Model and context pointers are safely managed
/// - Async generation streams maintain proper isolation
///
/// Memory Management:
/// - Automatically frees llama.cpp resources in deinit
/// - Context and model are properly cleaned up on failure
/// - Uses OpaquePointer for C interop safety
public actor InferenceEngine {
    
    // MARK: - Private Properties
    
    /// Pointer to the loaded llama.cpp model
    /// Set during init() and freed in deinit
    private var model: OpaquePointer?
    
    /// Pointer to the llama.cpp inference context
    /// Created from model and context parameters
    private var context: OpaquePointer?
    
    // MARK: - Initialization
    
    /// Initialize the inference engine with a model file.
    ///
    /// This method:
    /// - Initializes the llama.cpp backend
    /// - Loads the model from the specified file path
    /// - Creates an inference context with optimized settings
    ///
    /// - Parameter modelPath: Absolute path to the GGUF model file
    /// - Throws: InferenceError if model loading or context creation fails
    public init(modelPath: String) throws {
        // Initialize llama.cpp backend - must be called before any other llama functions
        llama_backend_init()
        
        // Load model with default parameters
        let modelParams = llama_model_default_params()
        self.model = llama_model_load_from_file(modelPath, modelParams)
        
        // Verify model loaded successfully
        guard let model = self.model else {
            if !FileManager.default.fileExists(atPath: modelPath) { 
                throw InferenceError.modelNotFound(modelPath) 
            }
            throw InferenceError.modelLoadFailed
        }
        
        // Create context with optimized parameters
        var contextParams = llama_context_default_params()
        contextParams.n_ctx = 2048  // Context window size
        contextParams.n_threads = Int32(ProcessInfo.processInfo.activeProcessorCount)
        contextParams.n_threads_batch = Int32(ProcessInfo.processInfo.activeProcessorCount)
        
        // Use updated API: llama_init_from_model instead of deprecated llama_new_context_with_model
        self.context = llama_init_from_model(model, contextParams)
        
        guard self.context != nil else { 
            throw InferenceError.contextCreationFailed 
        }
        
        print("InferenceEngine initialized successfully.")
    }
    
    // MARK: - Deinitialization
    
    /// Clean up llama.cpp resources when the actor is deallocated.
    ///
    /// This ensures:
    /// - Context memory is properly freed
    /// - Model memory is properly freed  
    /// - llama.cpp backend is shut down cleanly
    deinit {
        if let context = self.context { 
            llama_free(context) 
        }
        if let model = self.model { 
            // Use updated API: llama_model_free instead of deprecated llama_free_model
            llama_model_free(model) 
        }
        llama_backend_free()
        print("InferenceEngine deinitialized and resources freed.")
    }
    
    // MARK: - Text Generation
    
    /// Generate text from a prompt using streaming inference.
    ///
    /// This method:
    /// - Tokenizes the input prompt
    /// - Runs inference to generate new tokens
    /// - Streams generated text back token by token
    /// - Handles end-of-sequence detection
    ///
    /// - Parameter prompt: The text prompt to continue
    /// - Returns: AsyncThrowingStream that yields generated text chunks
    public func generate(for prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                // Verify we have valid model and context
                guard let context = self.context, let model = self.model else {
                    continuation.finish(throwing: InferenceError.contextCreationFailed)
                    return
                }

                // Get model vocabulary for tokenization
                let vocab = llama_model_get_vocab(model)
                let n_ctx = llama_n_ctx(context)
                
                // Tokenize the input prompt
                var tokens = [llama_token](repeating: 0, count: Int(n_ctx))
                let n_len = llama_tokenize(vocab, prompt, Int32(prompt.utf8.count), &tokens, Int32(n_ctx), true, false)

                guard n_len >= 0 else {
                    continuation.finish(throwing: InferenceError.tokenizationFailed)
                    return
                }

                // Create batch for initial context processing
                var mutableTokens = tokens 
                let batch = llama_batch_get_one(&mutableTokens, n_len)
                if llama_decode(context, batch) != 0 {
                    continuation.finish(throwing: InferenceError.decodeFailed)
                    return
                }
                
                // Initialize generation state
                var n_cur = n_len
                let sampler = llama_sampler_init_greedy()
                defer { llama_sampler_free(sampler) }
                
                let eos_token = llama_vocab_eos(vocab)

                // Generate tokens until context limit or end-of-sequence
                while n_cur < n_ctx {
                    // Sample next token
                    let new_token_id = llama_sampler_sample(sampler, context, -1)

                    // Check for end of sequence
                    if new_token_id == eos_token {
                        break
                    }
                    
                    // Convert token to text and yield to stream
                    var buffer = [CChar](repeating: 0, count: 256)
                    let piece_len = llama_token_to_piece(vocab, new_token_id, &buffer, Int32(buffer.count), 0, false)
                    
                    if piece_len > 0 {
                        continuation.yield(String(cString: buffer))
                    }
                    
                    // Accept the sampled token and prepare for next iteration
                    llama_sampler_accept(sampler, new_token_id)
                    
                    // Process the new token through the model
                    var next_token_id = new_token_id
                    let next_batch = llama_batch_get_one(&next_token_id, 1)
                    if llama_decode(context, next_batch) != 0 {
                        break
                    }
                    n_cur += 1
                }
                
                // Signal completion of generation
                continuation.finish()
            }
        }
    }
}