/// GradientToolbarButton.swift - Animated Gradient Toolbar Button Component
///
/// This file implements a SwiftUI button component with animated gradient effects,
/// hover states, and action-specific animations. Used throughout the app for
/// navigation controls and actions.
///
/// Key responsibilities:
/// - Displays SF Symbol icons with gradient hover effect
/// - Provides action-specific animations (rotate, bounce, replace)
/// - Shows tooltips and popovers for user feedback
/// - Manages enabled/disabled states with visual feedback
/// - Integrates with ButtonState for reactive updates
///
/// Related files:
/// - `BrowserViewController.swift`: Uses for navigation buttons
/// - `BrowserView.swift`: Hosts buttons in toolbar layout
/// - `ButtonState.swift`: Observable state for enable/disable
/// - `PromptWindowController.swift`: May use for submit button
///
/// Architecture:
/// - Pure SwiftUI view with @State for animations
/// - ObservedObject pattern for external state
/// - Conditional rendering based on hover/enabled states
/// - Animation modifiers for smooth transitions

import SwiftUI

// MARK: - Animation Constants

/// Animation durations and parameters.
private enum ButtonAnimations {
    /// Hover fade animation duration
    static let hoverDuration: TimeInterval = 0.2
    
    /// Rotation animation duration for refresh
    static let rotationDuration: TimeInterval = 0.6
    
    /// Bounce animation response time
    static let bounceResponse: Double = 0.3
    static let bounceDamping: Double = 0.5
    static let bounceOffset: CGFloat = -5
    static let bounceDelay: TimeInterval = 0.1
    
    /// Icon replacement animation duration
    static let replaceDuration: TimeInterval = 0.3
    static let replaceDelay: TimeInterval = 0.6
    
    /// Popover display duration
    static let popoverDuration: TimeInterval = 2.0
    
    /// Full rotation angle for refresh
    static let fullRotation: Double = 360
}

/// Button layout dimensions.
private enum ButtonLayout {
    /// Icon container size
    static let iconSize: CGFloat = 16
    
    /// Button frame size
    static let buttonWidth: CGFloat = 20
    static let buttonHeight: CGFloat = 20
    
    /// Vertical offset adjustments
    static let standardOffset: CGFloat = -8
    static let clipboardOffset: CGFloat = -9
    
    /// Default font sizes
    static let defaultFontSize: CGFloat = 14
    static let iconFontWeight: Font.Weight = .semibold
    
    /// Popover dimensions
    static let popoverWidth: CGFloat = 240
    static let popoverIconSize: CGFloat = 24
    static let popoverFontSize: CGFloat = 13
    static let popoverPadding: CGFloat = 8
}

/// Gradient colors for hover state.
private enum ButtonColors {
    static let gradientBlue = Color(red: 0.0, green: 0.6, blue: 1.0)
    static let gradientPink = Color(red: 1.0, green: 0.0, blue: 0.8)
    static let disabledOpacity: Double = 0.7
}

/// Animated toolbar button with gradient hover effect.
///
/// Created by:
/// - `BrowserViewController.setupToolbarButtons()` for navigation
/// - Other UI components needing animated buttons
///
/// Features:
/// - Gradient effect on hover when enabled
/// - Action-specific animations:
///   - Rotation for refresh (arrow.clockwise)
///   - Bounce for navigation (chevron.backward/forward)
///   - Icon swap for clipboard (clipboard -> clipboard.fill)
/// - Tooltip help text
/// - Success popover for copy action
///
/// The button adapts its animation based on the SF Symbol
/// name to provide contextual feedback.
struct GradientToolbarButton: View {
    /// SF Symbol name to display
    let systemName: String
    
    /// Observable state for enable/disable
    @ObservedObject var state: ButtonState
    
    /// Action closure called on tap
    let action: () -> Void
    
    /// Font size for the icon
    let fontSize: CGFloat
    
    /// Tracks mouse hover state
    @State private var isHovering = false
    
    /// Tracks button press state (unused but available)
    @State private var isPressed = false
    
    /// Current rotation angle for refresh animation
    @State private var rotationAngle: Double = 0
    
    /// Vertical offset for bounce animation
    @State private var bounceOffset: CGFloat = 0
    
    /// Wiggle animation phase (unused but available)
    @State private var wigglePhase: Double = 0
    
    /// Shows filled icon variant during copy
    @State private var showReplaceIcon = false
    
    /// Shows tooltip (unused, using help() instead)
    @State private var showCopiedTooltip = false
    
    /// Shows success popover after copy
    @State private var showCopiedPopover = false
    
    init(systemName: String, state: ButtonState, fontSize: CGFloat = ButtonLayout.defaultFontSize, action: @escaping () -> Void) {
        self.systemName = systemName
        self.state = state
        self.fontSize = fontSize
        self.action = action
    }
    
    /// Provides tooltip text based on icon.
    ///
    /// Maps SF Symbol names to user-friendly descriptions
    /// shown on hover via the help() modifier.
    private var tooltipText: String {
        switch systemName {
        case "chevron.backward":
            return "Back"
        case "chevron.forward":
            return "Forward"
        case "arrow.clockwise":
            return "Refresh"
        case "clipboard":
            return "Copy URL to Clipboard"
        default:
            return ""
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {  // Add this wrapper
            Button(action: {
                // Trigger animations based on icon type
                switch systemName {
                case "arrow.clockwise":
                    // Rotate animation
                    withAnimation(.easeInOut(duration: ButtonAnimations.rotationDuration)) {
                        rotationAngle += ButtonAnimations.fullRotation
                    }
                case "chevron.backward", "chevron.forward":
                    // Bounce animation
                    withAnimation(.spring(response: ButtonAnimations.bounceResponse, dampingFraction: ButtonAnimations.bounceDamping)) {
                        bounceOffset = ButtonAnimations.bounceOffset
                    }
                    withAnimation(.spring(response: ButtonAnimations.bounceResponse, dampingFraction: ButtonAnimations.bounceDamping).delay(ButtonAnimations.bounceDelay)) {
                        bounceOffset = 0
                    }
                case "clipboard":
                    // Replace animation
                    withAnimation(.easeInOut(duration: ButtonAnimations.replaceDuration)) {
                        showReplaceIcon = true
                    }
                    withAnimation(.easeInOut(duration: ButtonAnimations.replaceDuration).delay(ButtonAnimations.replaceDelay)) {
                        showReplaceIcon = false
                    }
                    // Show copied popover
                    showCopiedPopover = true
                    // Hide popover after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + ButtonAnimations.popoverDuration) {
                        showCopiedPopover = false
                    }
                default:
                    break
                }
                action()
            }) {
                ZStack {
                    if state.isEnabled && isHovering {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ButtonColors.gradientBlue,
                                ButtonColors.gradientPink
                            ]),
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                        .mask(
                            Image(systemName: currentIconName)
                                .font(.system(size: fontSize, weight: ButtonLayout.iconFontWeight))
                                .rotationEffect(.degrees(systemName == "arrow.clockwise" ? rotationAngle : 0))
                                .offset(y: systemName == "chevron.backward" || systemName == "chevron.forward" ? bounceOffset : 0)
                        )
                    } else {
                        Image(systemName: currentIconName)
                            .font(.system(size: fontSize, weight: .semibold))
                            .foregroundColor(state.isEnabled ? .secondary.opacity(ButtonColors.disabledOpacity) : .secondary.opacity(ButtonColors.disabledOpacity))
                            .rotationEffect(.degrees(systemName == "arrow.clockwise" ? rotationAngle : 0))
                            .offset(y: systemName == "chevron.backward" || systemName == "chevron.forward" ? bounceOffset : 0)
                    }
                }
                .frame(width: ButtonLayout.iconSize, height: ButtonLayout.iconSize)
            }
            .buttonStyle(.plain)
            .disabled(!state.isEnabled)
            .offset(y: systemName == "clipboard" ? ButtonLayout.clipboardOffset : ButtonLayout.standardOffset)  // Vertical positioning adjustment
            .onHover { hovering in
                withAnimation(.easeInOut(duration: ButtonAnimations.hoverDuration)) {
                    isHovering = hovering
                }
            }
            .help(tooltipText)
            .popover(isPresented: $showCopiedPopover, arrowEdge: .bottom) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: ButtonLayout.popoverIconSize))
                        .foregroundColor(.green)
                    Text("Copied Current URL to Clipboard")
                        .font(.system(size: ButtonLayout.popoverFontSize, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding()
                .frame(width: ButtonLayout.popoverWidth)
            }
        }
        .frame(width: ButtonLayout.buttonWidth, height: ButtonLayout.buttonHeight, alignment: .center)  // Explicit alignment
    }
    
    /// Returns the current icon name based on animation state.
    ///
    /// For clipboard button:
    /// - Shows "clipboard" normally
    /// - Switches to "clipboard.fill" during copy animation
    ///
    /// This provides visual feedback that copy succeeded.
    private var currentIconName: String {
        if systemName == "clipboard" && showReplaceIcon {
            return "clipboard.fill"
        }
        return systemName
    }
}