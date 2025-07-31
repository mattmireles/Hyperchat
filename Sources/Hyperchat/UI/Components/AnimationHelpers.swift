/// AnimationHelpers.swift - Consistent Animation Timing and Effects
///
/// This file provides standardized animation constants, easing functions, and
/// helper methods to ensure consistent micro-interactions throughout the
/// local LLM interface. All components should use these helpers for a cohesive
/// user experience that matches Apple's design language.
///
/// Key features:
/// - Standardized timing constants
/// - Consistent easing curves
/// - Specialized animation helpers for common UI patterns
/// - Performance-optimized animation configurations
/// - Accessibility-aware animations
///
/// This file is used by:
/// - All UI components for consistent animation timing
/// - `MessageBubble.swift` - Message appearance and interactions
/// - `LocalChatView.swift` - View transitions and state changes
/// - `LocalLLMHeader.swift` - Header animations and model switching
///
/// Related files:
/// - Individual component files that implement the animations
/// - Future accessibility preference handling

import SwiftUI

// MARK: - Animation Timing Constants

/// Standardized animation timing values following Apple's guidelines
public enum AnimationTiming {
    // MARK: Basic Durations
    
    /// Ultra-fast interactions (button presses, immediate feedback)
    static let ultraFast: Double = 0.1
    
    /// Fast interactions (hover effects, tool tips)
    static let fast: Double = 0.2
    
    /// Standard interactions (most UI transitions)
    static let standard: Double = 0.3
    
    /// Medium interactions (panel slides, modal presentations)
    static let medium: Double = 0.5
    
    /// Slow interactions (large state changes, complex layouts)
    static let slow: Double = 0.8
    
    /// Ultra-slow interactions (loading states, onboarding)
    static let ultraSlow: Double = 1.2
    
    // MARK: Specialized Timings
    
    /// Message appearance timing
    static let messageAppear: Double = 0.6
    
    /// Typing indicator cycle
    static let typingCycle: Double = 0.8
    
    /// Scroll to bottom animation
    static let scrollToBottom: Double = 0.7
    
    /// File drop animation
    static let fileDrop: Double = 0.4
    
    /// Model switching animation
    static let modelSwitch: Double = 0.5
    
    /// Loading state transitions
    static let loadingState: Double = 0.3
}

// MARK: - Animation Curves

/// Standardized easing curves for different interaction types
public enum AnimationCurves {
    /// Standard ease-in-out for most interactions
    public static let standard = Animation.easeInOut(duration: AnimationTiming.standard)
    
    /// Fast ease-in-out for quick feedback
    static let fast = Animation.easeInOut(duration: AnimationTiming.fast)
    
    /// Smooth ease-out for appearing elements
    static let easeOut = Animation.easeOut(duration: AnimationTiming.standard)
    
    /// Sharp ease-in for disappearing elements
    static let easeIn = Animation.easeIn(duration: AnimationTiming.fast)
    
    /// Bouncy spring for playful interactions
    static let spring = Animation.spring(
        response: 0.6,
        dampingFraction: 0.8,
        blendDuration: 0.1
    )
    
    /// Gentle spring for subtle movements
    static let gentleSpring = Animation.spring(
        response: 0.4,
        dampingFraction: 0.9,
        blendDuration: 0.1
    )
    
    /// Energetic spring for attention-grabbing effects
    static let energeticSpring = Animation.spring(
        response: 0.3,
        dampingFraction: 0.6,
        blendDuration: 0.1
    )
    
    /// Interpolating springs for smooth value changes
    static let interpolatingSpring = Animation.interactiveSpring(
        response: 0.5,
        dampingFraction: 0.8,
        blendDuration: 0.2
    )
}

// MARK: - Animation Delays

/// Standardized delay values for staggered animations
public enum AnimationDelay {
    /// No delay
    static let none: Double = 0.0
    
    /// Micro delay for immediate sequence
    static let micro: Double = 0.05
    
    /// Short delay for staggered effects
    static let short: Double = 0.1
    
    /// Medium delay for grouped animations
    static let medium: Double = 0.2
    
    /// Long delay for dramatic timing
    static let long: Double = 0.5
    
    /// Calculate staggered delay for index
    static func staggered(index: Int, baseDelay: Double = short) -> Double {
        return Double(index) * baseDelay
    }
}

// MARK: - Animation Helpers

/// Helper functions for common animation patterns
public struct AnimationHelpers {
    
    // MARK: Message Animations
    
    /// Animation for message appearance
    static func messageAppearance(delay: Double = 0) -> Animation {
        return AnimationCurves.spring.delay(delay)
    }
    
    /// Animation for message typing indicator
    static func typingIndicator(dotIndex: Int) -> Animation {
        let delay = Double(dotIndex) * 0.2
        return Animation.easeInOut(duration: AnimationTiming.typingCycle)
            .repeatForever(autoreverses: true)
            .delay(delay)
    }
    
    /// Animation for message bubble hover
    static func bubbleHover() -> Animation {
        return AnimationCurves.fast
    }
    
    // MARK: State Transitions
    
    /// Animation for loading state changes
    static func loadingStateChange() -> Animation {
        return AnimationCurves.standard
    }
    
    /// Animation for error state appearance
    static func errorState() -> Animation {
        return AnimationCurves.energeticSpring
    }
    
    /// Animation for success state
    static func successState() -> Animation {
        return AnimationCurves.gentleSpring
    }
    
    // MARK: Scroll Animations
    
    /// Animation for smooth scrolling to bottom
    static func scrollToBottom() -> Animation {
        return Animation.easeInOut(duration: AnimationTiming.scrollToBottom)
    }
    
    /// Animation for scroll position changes
    static func scrollPosition() -> Animation {
        return AnimationCurves.interpolatingSpring
    }
    
    // MARK: File Operations
    
    /// Animation for file drop overlay
    static func fileDrop() -> Animation {
        return AnimationCurves.spring
    }
    
    /// Animation for file attachment appearance
    static func fileAttachment() -> Animation {
        return AnimationCurves.gentleSpring
    }
    
    /// Animation for upload progress
    static func uploadProgress() -> Animation {
        return Animation.linear(duration: 0.1)
    }
    
    // MARK: Header Animations
    
    /// Animation for model selection changes
    static func modelSelection() -> Animation {
        return AnimationCurves.standard
    }
    
    /// Animation for connection status changes
    static func connectionStatus() -> Animation {
        return AnimationCurves.fast
    }
    
    /// Animation for header hover effects
    static func headerHover() -> Animation {
        return AnimationCurves.fast
    }
    
    // MARK: Specialized Effects
    
    /// Creates a shimmer effect animation
    static func shimmer(duration: Double = 2.0) -> Animation {
        return Animation.linear(duration: duration)
            .repeatForever(autoreverses: false)
    }
    
    /// Creates a pulse effect animation
    static func pulse(duration: Double = 1.0) -> Animation {
        return Animation.easeInOut(duration: duration)
            .repeatForever(autoreverses: true)
    }
    
    /// Creates a wiggle effect animation
    static func wiggle(intensity: Double = 2.0) -> Animation {
        return Animation.easeInOut(duration: 0.1)
            .repeatCount(6, autoreverses: true)
    }
    
    /// Creates a bounce effect animation
    static func bounce(height: CGFloat = 10) -> Animation {
        return AnimationCurves.energeticSpring
    }
    
    // MARK: Context-Sensitive Animations
    
    /// Get appropriate animation based on system settings
    static func contextual(
        standard: Animation = AnimationCurves.standard,
        reduced: Animation = Animation.linear(duration: 0.1)
    ) -> Animation {
        // Check for reduced motion accessibility setting
        return AccessibilityPreferences.reduceMotion ? reduced : standard
    }
    
    /// Animation that respects user's motion preferences
    static func accessible(_ animation: Animation) -> Animation {
        return AccessibilityPreferences.reduceMotion 
            ? Animation.linear(duration: 0.1)
            : animation
    }
}

// MARK: - Accessibility Preferences

/// Helper for checking accessibility preferences
private struct AccessibilityPreferences {
    static var reduceMotion: Bool {
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    
    static var increaseContrast: Bool {
        return NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }
    
    static var differentiateWithoutColor: Bool {
        return NSWorkspace.shared.accessibilityDisplayShouldDifferentiateWithoutColor
    }
}

// MARK: - Animation Modifiers

/// Custom view modifiers for consistent animations
public extension View {
    
    /// Apply a gentle scale animation on hover
    func gentleScaleOnHover(scale: CGFloat = 1.05) -> some View {
        self.scaleEffect(scale)
            .animation(AnimationHelpers.bubbleHover(), value: scale)
    }
    
    /// Apply a message appearance animation
    func messageAppearance(delay: Double = 0) -> some View {
        self.transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(AnimationHelpers.messageAppearance(delay: delay), value: UUID())
    }
    
    /// Apply contextual animation that respects accessibility
    func contextualAnimation<V: Equatable>(
        _ animation: Animation = AnimationCurves.standard,
        value: V
    ) -> some View {
        self.animation(AnimationHelpers.accessible(animation), value: value)
    }
    
    /// Apply a shimmer loading effect
    func shimmerEffect(isLoading: Bool) -> some View {
        self.overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: isLoading ? 300 : -300)
                .animation(
                    isLoading ? AnimationHelpers.shimmer() : .none,
                    value: isLoading
                )
        )
        .clipped()
    }
}

// MARK: - Performance Optimizations

/// Animation performance helpers
public struct AnimationPerformance {
    
    /// Optimize animations for large lists
    static func optimizeForLists<V: Equatable>(value: V) -> Animation? {
        // Return nil to disable implicit animations in large lists
        return nil
    }
    
    /// Check if device can handle complex animations
    static var canHandleComplexAnimations: Bool {
        // Simple heuristic - could be more sophisticated
        return ProcessInfo.processInfo.processorCount > 2
    }
    
    /// Get appropriate animation complexity based on system performance
    static func adaptiveAnimation(
        simple: Animation = Animation.linear(duration: 0.2),
        complex: Animation = AnimationCurves.spring
    ) -> Animation {
        return canHandleComplexAnimations ? complex : simple
    }
}

// MARK: - Debug Helpers

#if DEBUG
/// Debug helpers for animation development
public struct AnimationDebug {
    
    /// Add visual debugging to animations
    static func visualizeAnimation<V: View>(_ view: V, label: String) -> some View {
        view.overlay(
            Text(label)
                .font(.caption2)
                .padding(2)
                .background(Color.red.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(2),
            alignment: .topLeading
        )
    }
    
    /// Log animation timing for performance analysis
    static func logTiming(_ label: String, duration: Double) {
        print("🎬 Animation '\(label)': \(duration)s")
    }
}
#endif