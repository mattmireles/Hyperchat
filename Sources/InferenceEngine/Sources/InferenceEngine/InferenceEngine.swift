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
    
    /// Generates a response for a given prompt, streaming back tokens as they are produced.
    ///
    /// This function performs the following steps:
    /// 1. Tokenizes the user's prompt.
    /// 2. Enters a generation loop that repeatedly:
    ///    a. Evaluates the current context with `llama_decode`.
    ///    b. Samples the next token using the modern sampler API.
    ///    c. Converts the token ID back to a piece of text.
    ///    d. Yields the text to the async stream.
    /// 3. Continues until an end-of-sequence token is generated or the context is full.
    ///
    /// - Parameter prompt: The user's input string.
    /// - Returns: An `AsyncThrowingStream` that yields `String` tokens.
    public func generate(for prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream<String, Error> { continuation in
            Task {
                guard let context = self.context, let model = self.model else {
                    continuation.finish(throwing: InferenceError.contextCreationFailed)
                    return
                }

                // --- 1. Tokenize the Prompt ---
                let vocab = llama_model_get_vocab(model)
                let n_ctx = llama_n_ctx(context)
                
                // Allocate buffer for tokens
                let max_tokens = min(n_ctx, 512) // Reasonable max for prompt
                var tokens = Array<llama_token>(repeating: 0, count: Int(max_tokens))
                
                let n_len = llama_tokenize(
                    vocab,
                    prompt,
                    Int32(prompt.utf8.count),
                    &tokens,
                    Int32(max_tokens),
                    true,  // Add beginning of sentence token
                    false) // Special tokens are not parsed

                guard n_len < n_ctx else {
                    // TODO: Handle prompts that are too long
                    continuation.finish()
                    return
                }

                // --- 2. Decode the Initial Prompt ---
                let batch = llama_batch_get_one(&tokens, n_len)
                if llama_decode(context, batch) != 0 {
                    continuation.finish(throwing: NSError(domain: "InferenceError", code: 2, userInfo: [NSLocalizedDescriptionKey: "llama_decode failed"]))
                    return
                }
                
                var n_cur = n_len
                
                // --- 3. Create Greedy Sampler ---
                let sampler = llama_sampler_init_greedy()
                guard sampler != nil else {
                    continuation.finish(throwing: NSError(domain: "InferenceError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create sampler"]))
                    return
                }
                
                // --- 4. Get EOS Token for Checking ---
                let eos_token = llama_vocab_eos(vocab)
                
                // --- 5. Generation Loop ---
                while n_cur < n_ctx {
                    // --- a. Sample the Next Token ---
                    let new_token_id = llama_sampler_sample(sampler, context, n_len - 1)

                    // --- b. Check for End of Sequence ---
                    if new_token_id == eos_token {
                        continuation.finish()
                        break
                    }

                    // --- c. Yield the Generated Token ---
                    var buffer = Array<CChar>(repeating: 0, count: 256) // Buffer for token text
                    let length = llama_token_to_piece(vocab, new_token_id, &buffer, Int32(buffer.count), 0, false)
                    if length > 0 {
                        let str = String(cString: buffer)
                        continuation.yield(str)
                    }
                    
                    // --- d. Prepare for Next Iteration ---
                    var single_token = [new_token_id]
                    let batch = llama_batch_get_one(&single_token, 1)
                    if llama_decode(context, batch) != 0 {
                        continuation.finish()
                        break
                    }
                    
                    // --- e. Accept the token for the sampler ---
                    llama_sampler_accept(sampler, new_token_id)
                    
                    n_cur += 1
                }

                // --- 6. Cleanup ---
                llama_sampler_free(sampler)
                continuation.finish()
            }
        }
    }
}