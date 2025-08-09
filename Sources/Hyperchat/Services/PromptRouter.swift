// PromptRouter.swift - Route prompts to appropriate services and methods

import Foundation

// Note: Keeping this file as a thin facade in case we later fully remove the original method
// in ServiceManager. For now, do not duplicate executePrompt to avoid redeclarations.
// We expose helpers here when needed in future phases.

extension ServiceManager {
    /// Helper to focus input after a delay (shared by routing paths)
    func focusInputAfterDelay() {
        if LoggingSettings.shared.debugPrompts {
            WebViewLogger.shared.log("🔄 focusInputAfterDelay scheduled", for: "system", type: .info)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + ServiceTimings.promptRefocusDelay) { [weak self] in
            self?.focusInputPublisher.send()
        }
    }
}


