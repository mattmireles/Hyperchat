# Hyperchat - Product Specifications

All Your AIs -- All At Once.  
Accelerate Your Mind with Maximum AI

*This document defines the high-level product specifications for Hyperchat. For implementation details and technical guidance, refer to CLAUDE.md.*

## Product Overview

Hyperchat is a native macOS app that provides instant access to multiple AI services (ChatGPT, Claude, Perplexity, Google) via a floating button or global hotkey. Users can submit prompts to all services simultaneously and view responses side-by-side.

## Core User Experience

1. **Activation Methods**
   - Persistent 48x48px floating button that follows user across spaces
   - Global hotkey (default: `fn` key, configurable)

2. **Prompt Input**
   - Floating prompt window appears on activation
   - Auto-resizing text field with Shift+Enter for newlines
   - Enter submits to all services simultaneously

3. **Response Viewing**
   - Multiple windows supported across different monitors/spaces
   - Side-by-side service windows with live response streaming
   - Full browser functionality within each service window
   - Window hibernation when not in focus (resource optimization)

4. **Interaction Features**
   - Each service window includes browser navigation controls
   - Close individual services to focus on preferred responses
   - "Open in Browser" launches conversations in default browser
   - Dynamic reflow when services are closed

5. **Keyboard Shortcuts**
   - ESC: Close overlay
   - Enter: Submit prompt (Shift+Enter for newline)
   - Cmd+1/2/3/4: Focus specific service
   - Cmd+N: Focus unified input

## Supported AI Services

1. **ChatGPT** - URL parameter activation
2. **Claude** - Clipboard paste automation
3. **Perplexity** - URL parameter activation  
4. **Google** - URL parameter activation

## Key Features

### Window Management
- Multiple independent windows across monitors
- Per-window resource isolation
- Automatic hibernation of unfocused windows
- Visual continuity via screenshot overlays

### Performance
- Sub-50ms response to user actions
- Optimized WebView loading strategies
- Resource-efficient multi-window support
- Intelligent pre-warming and lazy loading

### User Preferences
- Draggable floating button position
- Configurable global hotkey
- Service enable/disable controls
- Window layout preferences

### Window Layout
- Window width: 600-800px (min/max)
- Window padding: 50px between services
- Window height: 80% of screen height
- Vertical centering with breathing room

### Settings Panel
- **Floating Button**: Position preference, enable/disable
- **Global Hotkey**: Key combination picker
- **Service Management**: Enable/disable services, reorder services
- **Claude Configuration**: Timing adjustment for paste delay
- **Appearance**: Theme selection (dark/light/system)
- **Keyboard Shortcuts**: Display current shortcuts
- **About**: Version, credits, privacy policy

## Technical Requirements

### Platform
- macOS 14.0 (Sonoma) minimum
- Universal binary (Intel + Apple Silicon)
- Direct distribution (not sandboxed)

### Frameworks
- SwiftUI for UI
- WebKit for service integration
- AppKit for window management
- KeyboardShortcuts for global hotkeys

## Distribution

- Code signed and notarized
- Automatic updates via Sparkle
- Direct download distribution

## Future Considerations

- Additional AI service integrations
- Enhanced automation capabilities
- Cross-platform expansion
- Local model support

---

*For implementation details, architecture decisions, and development guidelines, see [CLAUDE.md](CLAUDE.md)*