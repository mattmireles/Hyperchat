// This file is no longer used and should be removed from the Xcode project
// Keeping minimal placeholder to prevent build errors

import SwiftUI

struct ClaudeLoginView: View {
    let onComplete: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        Text("This view is deprecated")
            .onAppear {
                onComplete()
            }
    }
}

// Minimal button style to prevent build errors
struct OnboardingButtonStyle: ButtonStyle {
    let isPrimary: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(isPrimary ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}