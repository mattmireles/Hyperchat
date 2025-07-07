import SwiftUI

struct GradientToolbarButton: View {
    let systemName: String
    @ObservedObject var state: ButtonState
    let action: () -> Void
    let fontSize: CGFloat
    @State private var isHovering = false
    @State private var isPressed = false
    @State private var rotationAngle: Double = 0
    @State private var bounceOffset: CGFloat = 0
    @State private var wigglePhase: Double = 0
    @State private var showReplaceIcon = false
    @State private var showCopiedTooltip = false
    @State private var showCopiedPopover = false
    
    init(systemName: String, state: ButtonState, fontSize: CGFloat = 14, action: @escaping () -> Void) {
        self.systemName = systemName
        self.state = state
        self.fontSize = fontSize
        self.action = action
    }
    
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
                    withAnimation(.easeInOut(duration: 0.6)) {
                        rotationAngle += 360
                    }
                case "chevron.backward", "chevron.forward":
                    // Bounce animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        bounceOffset = -5
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1)) {
                        bounceOffset = 0
                    }
                case "clipboard":
                    // Replace animation
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showReplaceIcon = true
                    }
                    withAnimation(.easeInOut(duration: 0.3).delay(0.6)) {
                        showReplaceIcon = false
                    }
                    // Show copied popover
                    showCopiedPopover = true
                    // Hide popover after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
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
                            gradient: Gradient(stops: [
                                .init(color: Color(red: 1.0, green: 0.0, blue: 0.8), location: 0.0),        // Pink
                                .init(color: Color(red: 1.0, green: 0.0, blue: 0.8), location: 0.4),        // Pink
                                .init(color: Color(red: 0.6, green: 0.2, blue: 0.8), location: 0.6),        // Purple
                                .init(color: Color(red: 0.0, green: 0.6, blue: 1.0), location: 0.85),       // Blue
                                .init(color: Color(red: 0.0, green: 0.6, blue: 1.0), location: 1.0)         // Blue
                            ]),
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                        .mask(
                            Image(systemName: currentIconName)
                                .font(.system(size: fontSize, weight: .semibold))
                                .rotationEffect(.degrees(systemName == "arrow.clockwise" ? rotationAngle : 0))
                                .offset(y: systemName == "chevron.backward" || systemName == "chevron.forward" ? bounceOffset : 0)
                        )
                    } else {
                        Image(systemName: currentIconName)
                            .font(.system(size: fontSize, weight: .semibold))
                            .foregroundColor(state.isEnabled ? .secondary.opacity(0.7) : .secondary.opacity(0.7))
                            .rotationEffect(.degrees(systemName == "arrow.clockwise" ? rotationAngle : 0))
                            .offset(y: systemName == "chevron.backward" || systemName == "chevron.forward" ? bounceOffset : 0)
                    }
                }
                .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .disabled(!state.isEnabled)
            .offset(y: systemName == "clipboard" ? -9 : -8)  // Offset 3px lower (was -12/-11, now -9/-8)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
            .help(tooltipText)
            .popover(isPresented: $showCopiedPopover, arrowEdge: .bottom) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                    Text("Copied Current URL to Clipboard")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding()
                .frame(width: 240)
            }
        }
        .frame(width: 20, height: 20, alignment: .center)  // Explicit alignment
    }
    
    private var currentIconName: String {
        if systemName == "clipboard" && showReplaceIcon {
            return "clipboard.fill"
        }
        return systemName
    }
}