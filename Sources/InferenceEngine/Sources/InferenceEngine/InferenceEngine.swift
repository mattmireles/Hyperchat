import Foundation
import CMistral // Our C-wrapper module

// MARK: - Error Handling
public enum InferenceError: Error {
    case modelNotFound(String)
    case modelLoadFailed
    case contextCreationFailed
}

// MARK: - Inference Engine Actor
public actor InferenceEngine {
    
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    
    public init(modelPath: String) throws {
        llama_backend_init()
        
        var modelParams = llama_model_default_params()
        
        self.model = llama_load_model_from_file(modelPath, modelParams)
        guard let model = self.model else {
            if !FileManager.default.fileExists(atPath: modelPath) {
                throw InferenceError.modelNotFound(modelPath)
            }
            throw InferenceError.modelLoadFailed
        }
        
        var contextParams = llama_context_default_params()
        contextParams.n_ctx = 2048
        contextParams.n_threads = Int32(ProcessInfo.processInfo.activeProcessorCount)
        contextParams.n_threads_batch = Int32(ProcessInfo.processInfo.activeProcessorCount)

        self.context = llama_new_context_with_model(model, contextParams)
        guard self.context != nil else {
            throw InferenceError.contextCreationFailed
        }
        
        print("InferenceEngine initialized successfully.")
    }
    
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

    public func generate(for prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream<String, Error> { continuation in
            Task {
                guard let context = self.context, let model = self.model else {
                    continuation.finish(throwing: InferenceError.contextCreationFailed)
                    return
                }

                let tokens = llama_tokenize(model, prompt, Int32(prompt.utf8.count), true, false)
                let n_len = Int32(tokens.count)

                guard n_len < llama_n_ctx(context) else {
                    continuation.finish(throwing: NSError(domain: "InferenceError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Prompt is too long"]))
                    return
                }

                if llama_decode(context, llama_batch_get_one(tokens, n_len, 0, 0)) != 0 {
                    continuation.finish(throwing: NSError(domain: "InferenceError", code: 2, userInfo: [NSLocalizedDescriptionKey: "llama_decode failed"]))
                    return
                }
                
                var n_cur = n_len
                
                while n_cur < llama_n_ctx(context) {
                    var candidates = llama_token_data_array(data: nil, size: llama_n_vocab(model), sorted: false)
                    let logits = llama_get_logits_ith(context, Int32(n_len) - 1)
                    
                    for token_id in 0..<llama_n_vocab(model) {
                        candidates.data[Int(token_id)] = llama_token_data(id: token_id, logit: logits[Int(token_id)], p: 0.0)
                    }

                    let new_token_id = llama_sample_token_greedy(context, &candidates)

                    if new_token_id == llama_token_eos(model) {
                        continuation.finish()
                        break
                    }

                    let piece = llama_token_to_piece(context, new_token_id)
                    if let cStr = piece {
                        let str = String(cString: cStr)
                        continuation.yield(str)
                    }
                    
                    var batch = llama_batch_get_one([new_token_id], 1, n_cur, 0)
                    if llama_decode(context, batch) != 0 {
                        continuation.finish()
                        break
                    }
                    
                    n_cur += 1
                }

                continuation.finish()
            }
        }
    }
}