# HyperChat - v1.0 Technical Specifications

All Your AIs -- All At Once. 
Accelerate Your Mind with Maximum AI

*This specification defines the technical foundation for HyperChat v1.0, focusing on real-time AI response streaming for information junkies while maintaining architectural flexibility for future enhancements.*

## Product Overview

HyperChat is a native macOS app that provides instant access to multiple LLMs via floating button or global hotkey, enabling real-time comparison of responses across ChatGPT, Claude, Perplexity, and Google in a persistent window interface that can toggle between normal and full-screen overlay modes. Designed for information junkies who want to watch AI responses stream in simultaneously.

## Core User Experience

1. **Persistent Floating Button**: 48x48px floating icon with transparent background, follows user across active spaces
2. **Global Hotkey**: users can use `fn` (configurable) as alternative activation
3. **One-Click Activation**: Click floating button to invoke prompt window instantly
4. **Instant Input**: Floating prompt bar appears center screen
5. **Multi-Service Query**: Enter sends prompt to all configured services simultaneously
6. **Dual-Mode Interface**: 
   - Normal Mode: Standard window with title bar, resizable, movable
   - Overlay Mode: Full-screen with blur effect, ESC to toggle modes
7. **Real-Time Response Streaming**: Side-by-side service windows showing live AI responses as they generate
8. **Interactive Sessions**: Each window functions as a full browser - users can continue conversations, click links, interact naturally
9. **Session Persistence**: Login state maintained across app sessions - no re-authentication required
10. **Selective Viewing**: Close individual service windows (e.g., dismiss Google results) to focus on preferred responses
11. **Browser Handoff**: "Open in [Browser]" button launches any conversation in user's default browser for extended work
12. **Dynamic Window Management**: Closing individual service windows causes remaining windows to reflow and expand to fill available space
13. **Keyboard Navigation**: 
    - ESC toggles between normal and overlay modes
    - Enter submits prompts
    - Cmd+1/2/3/4 focuses specific services
14. **Window State Preservation**: Window position and size are preserved when toggling between modes
15. **Quick Exit**: ESC closes overlay, returns to previous work with all sessions preserved

## Technical Architecture

### App Structure

```
HyperChatApp
├── AppDelegate (app lifecycle, global hotkey registration)
├── FloatingButtonManager (persistent on-screen activation)
├── ServiceManager (persistent WKWebView management)
├── OverlayController (dual-mode window management)
├── PromptWindow (floating input interface)
├── ServiceWindow (individual AI service containers)
├── DefaultBrowserManager (browser detection)
└── SettingsManager (configuration persistence)
```

### Core Components

#### 1. Floating Button (Primary Activation)

- **Always Visible**: 48x48px transparent background button
- **Active Space Following**: Moves with user across desktops/Spaces (simplified cross-space behavior)
- **User Positioning**: Draggable to preferred screen corner/edge
- **Visual Feedback**: Subtle hover state and click animation
- **Performance**: <50ms response time from click to prompt window

#### 2. Global Hotkey Manager

- **Framework**: KeyboardShortcuts framework (modern, App Store compatible)
- **Requirements**: Standard app permissions (no special accessibility needs)
- **Default**: `fn` key, configurable in settings
- **Performance**: <100ms response time from hotkey to first UI

#### 3. Service Manager

- **Persistent WKWebViews**: One per configured service, initialized at app launch
- **Session Management**: Maintain login cookies and session state
- **Memory Strategy**: Keep services warm in background for instant response
- **Supported Services**:
    - ChatGPT: URL parameter activation
    - Claude: Clipboard paste + enter automation
    - Perplexity: URL parameter activation
    - Google: URL parameter activation

#### 4. Window System

- **Dual-Mode Architecture**:
  - Normal Mode: Standard window with title bar, resizable, movable
  - Overlay Mode: Full-screen with blur effect, ESC to toggle modes
- **Window State Management**:
  - Saves window position, size, and style when entering overlay mode
  - Restores state when exiting overlay mode
  - Smooth transitions between modes with animations
- **Normal Mode Properties**:
  - Title bar with standard window controls
  - Resizable with minimum size constraints
  - Movable and dockable
  - Standard window level and collection behavior
- **Overlay Mode Properties**:
  - Borderless window style
  - Floating window level
  - Full-screen auxiliary behavior
  - Background blur and tint effects
- **Multi-Display Support**: 
  - Normal mode: Standard window positioning
  - Overlay mode: Appears on display containing the cursor
- **Window Reflow**: Dynamic resizing and repositioning when services are closed

#### 5. Window Layout System

Window layout will be calculated dynamically using SwiftUI's native layout system. The main window view will use a GeometryReader to determine the available screen size. A ScrollView(.horizontal) will be used if the total width of the service windows exceeds the screen width.

The width for each ServiceView will be calculated based on the number of active services, the available screen width, and the specified constraints (minWidth: 600, maxWidth: 800, padding: 50). This logic will reside directly within the main view, removing the need for a separate WindowLayoutEngine class and promoting a more direct, maintainable SwiftUI implementation.

## Performance Requirements

### Critical Path Timing

- **Cold Launch**: App launch to floating button visible <500ms
- **Button Response**: Floating button click to prompt window <50ms
- **Query Execution**: Prompt submission to first window visible <200ms
- **URL Services**: ChatGPT, Perplexity, Google response <200ms
- **Claude Service**: Clipboard paste method 2-3 seconds
- **Global Hotkey**: Hotkey to prompt window <100ms

### Memory Management

- **Background Footprint**: <400MB when inactive (4 persistent WKWebViews)
- **Active Footprint**: <600MB with all services loaded and responding
- **WKWebView Optimization**: Shared process pool, optimized configurations

## Data Architecture

### Service Configuration

```swift
struct AIService {
    var id: String
    var name: String
    var iconName: String
    var activationMethod: ServiceActivationMethod
    var enabled: Bool
    var order: Int
}
```

### Notification System

```swift
extension Notification.Name {
    static let showPromptWindow = Notification.Name("showPromptWindow")
    static let hideOverlay = Notification.Name("hideOverlay")
    static let serviceWindowClosed = Notification.Name("serviceWindowClosed")
}
```

### App Lifecycle Management

```swift
@main
struct HyperChatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingButtonManager: FloatingButtonManager?
    private var globalHotkeyManager: GlobalHotkeyManager?
    private var overlayController: OverlayController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupFloatingButton()
        setupGlobalHotkey()
        setupOverlayController()
        
        // Hide dock icon for menu bar app behavior
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupFloatingButton() {
        floatingButtonManager = FloatingButtonManager()
        floatingButtonManager?.createFloatingButton()
    }
    
    private func setupGlobalHotkey() {
        globalHotkeyManager = GlobalHotkeyManager()
        globalHotkeyManager?.setupHotkey()
    }
    
    private func setupOverlayController() {
        overlayController = OverlayController()
        
        NotificationCenter.default.addObserver(
            forName: .showPromptWindow,
            object: nil,
            queue: .main
        ) { _ in
            self.overlayController?.showPromptWindow()
        }
        
        NotificationCenter.default.addObserver(
            forName: .hideOverlay,
            object: nil,
            queue: .main
        ) { _ in
            self.overlayController?.hideOverlay()
        }
    }
}
```

### Prompt Window Implementation

```swift
struct PromptWindow: View {
    @State private var prompt: String = ""
    @FocusState private var isEditorFocused: Bool
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $prompt)
                    .font(.system(size: 16))
                    .frame(minHeight: 40, maxHeight: 200) // Auto-resizing up to a limit
                    .focused($isEditorFocused)
                    .scrollContentBackground(.hidden) // Make it transparent
            
                if prompt.isEmpty {
                    Text("Ask anything...")
                        .font(.system(size: 16))
                        .foregroundColor(Color.gray.opacity(0.6))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Ask All Services") {
                    if !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSubmit(prompt)
                        prompt = ""
                    }
                }
                .keyboardShortcut(.defaultAction) // Use .defaultAction for Enter key
                .buttonStyle(.borderedProminent)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500)
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 20)
        .onAppear {
            isEditorFocused = true
        }
    }
}
```

### Overlay Controller

```swift
class OverlayController: ObservableObject {
    private var overlayWindow: NSWindow?
    private var promptWindow: NSWindow?
    @Published var isOverlayVisible: Bool = false
    @Published var isPromptVisible: Bool = false
    
    func showPromptWindow() {
        createPromptWindow()
        isPromptVisible = true
    }
    
    func hideOverlay() {
        overlayWindow?.orderOut(nil)
        promptWindow?.orderOut(nil)
        isOverlayVisible = false
        isPromptVisible = false
    }
    
    func showOverlay(with prompt: String) {
        hidePromptWindow()
        createOverlayWindow(prompt: prompt)
        isOverlayVisible = true
    }
    
    private func createPromptWindow() {
        let screen = NSScreen.screenWithMouse() ?? NSScreen.main!
        let screenFrame = screen.frame
        
        promptWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        promptWindow?.level = .floating
        promptWindow?.backgroundColor = NSColor.clear
        promptWindow?.isOpaque = false
        promptWindow?.hasShadow = false
        promptWindow?.center()
        
        let promptView = PromptWindow(
            onSubmit: { [weak self] prompt in
                self?.showOverlay(with: prompt)
            },
            onCancel: { [weak self] in
                self?.hidePromptWindow()
            }
        )
        
        promptWindow?.contentView = NSHostingView(rootView: promptView)
        promptWindow?.makeKeyAndOrderFront(nil)
    }
    
    private func hidePromptWindow() {
        promptWindow?.orderOut(nil)
        isPromptVisible = false
    }
    
    private func createOverlayWindow(prompt: String) {
        let screen = NSScreen.screenWithMouse() ?? NSScreen.main!
        let screenFrame = screen.frame
        
        overlayWindow = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        overlayWindow?.level = .modalPanel
        overlayWindow?.backgroundColor = NSColor.clear
        overlayWindow?.isOpaque = false
        overlayWindow?.hasShadow = false
        
        let overlayView = OverlayView(initialPrompt: prompt)
        overlayWindow?.contentView = NSHostingView(rootView: overlayView)
        overlayWindow?.makeKeyAndOrderFront(nil)
    }
}

extension NSScreen {
    static func screenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }
}
```

### Keyboard Shortcuts Implementation

```swift
struct OverlayView: View {
    @StateObject private var serviceManager = ServiceManager()
    @StateObject private var layoutManager = OverlayLayoutManager()
    @State private var isVisible: Bool = false
    let initialPrompt: String
    
    var body: some View {
        let layout = layoutManager.calculateLayout(
            for: serviceManager.activeServices,
            screenSize: NSScreen.main?.frame.size ?? .zero
        )

        ScrollView(layout.needsScrolling ? .horizontal : []) {
            HStack(spacing: layoutManager.windowPadding) {
                ForEach(serviceManager.activeServices, id: \.id) { service in
                    if let webService = serviceManager.webService(for: service),
                       let observer = serviceManager.observer(for: service) {
                        ServiceView(
                            service: service,
                            webService: webService,
                            observer: observer,
                            onClose: {
                                serviceManager.disableService(service.id)
                            }
                        )
                        .frame(
                            width: layout.frames.first?.width ?? layoutManager.minWidth,
                            height: layout.frames.first?.height ?? 0
                        )
                    }
                }
            }
            .padding()
            .frame(height: NSScreen.main?.frame.height)
        }
        .onAppear {
            serviceManager.executePrompt(initialPrompt)
        }
        .onKeyDown { event in
            switch event.keyCode {
            case 53: // ESC key
                NotificationCenter.default.post(name: .hideOverlay, object: nil)
            case 18: // Cmd+1
                focusService(at: 0)
            case 19: // Cmd+2
                focusService(at: 1)
            case 20: // Cmd+3
                focusService(at: 2)
            case 21: // Cmd+4
                focusService(at: 3)
            default:
                break
            }
        }
    }
    
    private func focusService(at index: Int) {
        guard index < serviceManager.activeServices.count else { return }
        // Focus implementation for specific service window
    }
}
```

### Resource Cleanup

```swift
extension ServiceManager {
    func disableService(_ serviceId: String) {
        guard let webService = webServices[serviceId] else { return }
        
        // Clean up WKWebView resources
        webService.webView.stopLoading()
        webService.webView.loadHTMLString("", baseURL: nil)
        
        // Remove from active services
        activeServices.removeAll { $0.id == serviceId }
        webServices.removeValue(forKey: serviceId)
        webViewObservers.removeValue(forKey: serviceId)
        
        // Trigger layout reflow
        NotificationCenter.default.post(name: .serviceWindowClosed, object: serviceId)
    }
    
    func enableService(_ service: AIService) {
        guard webServices[service.id] == nil else { return }
        
        let webView = createWebView()
        let observer = WebViewObserver()
        webView.navigationDelegate = observer
        observer.observeWebView(webView)
        
        let webService: WebService
        
        // Warm-up: immediately load the service's base page so the web process is alive before first query
        switch service.activationMethod {
        case .urlParameter(let baseURL, _):
            if let url = URL(string: baseURL) {
                webView.load(URLRequest(url: url))
            }
        case .clipboardPaste(let baseURL):
            if let url = URL(string: baseURL) {
                webView.load(URLRequest(url: url))
            }
        }
        
        webServices[service.id] = webService
        webViewObservers[service.id] = observer
        activeServices.append(service)
        activeServices.sort { $0.order < $1.order }
    }
    
    func removeService(_ serviceId: String) {
        disableService(serviceId)
    }
}

enum ServiceActivationMethod {
    case urlParameter(baseURL: String, parameter: String)
    case clipboardPaste(baseURL: String)
}

struct AppConfiguration {
    var floatingButton: FloatingButtonConfig
    var globalHotkey: GlobalHotkeyConfig
    var enabledServices: [AIService]
    var windowLayout: LayoutPreferences
    var appearance: AppearanceSettings
}

struct FloatingButtonConfig {
    var position: CGPoint
    var isEnabled: Bool = true
    var cornerPreference: ScreenCorner
}

struct GlobalHotkeyConfig {
    var keyCombo: KeyboardShortcuts.Name = .showHyperChat
    var isEnabled: Bool = true
}
```

### Default Service Configuration

```swift
let defaultServices = [
    AIService(
        id: "chatgpt",
        name: "ChatGPT",
        iconName: "chatgpt-icon",
        activationMethod: .urlParameter(
            baseURL: "https://chat.openai.com",
            parameter: "q"
        ),
        enabled: true,
        order: 3
    ),
    AIService(
        id: "claude",
        name: "Claude",
        iconName: "claude-icon",
        activationMethod: .clipboardPaste(
            baseURL: "https://claude.ai"
        ),
        enabled: true,
        order: 4
    ),
    AIService(
        id: "perplexity",
        name: "Perplexity",
        iconName: "perplexity-icon",
        activationMethod: .urlParameter(
            baseURL: "https://www.perplexity.ai",
            parameter: "q"
        ),
        enabled: true,
        order: 2
    ),
    AIService(
        id: "google",
        name: "Google",
        iconName: "google-icon",
        activationMethod: .urlParameter(
            baseURL: "https://www.google.com/search",
            parameter: "q"
        ),
        enabled: true,
        order: 1
    )
]
```

### Settings Persistence

- **UserDefaults**: For lightweight configuration
- **Keychain**: For sensitive service tokens (future)
- **No Backend**: All data stays local

## Security & Privacy

### App Sandboxing Disabled

To allow for necessary system-level integrations like global hotkeys and direct hardware access without persistent user prompts, App Sandboxing is disabled. The application runs with the same permissions as the logged-in user. This is a common approach for developer tools and utilities distributed outside the Mac App Store.

- **WKWebView Isolation**: Despite no sandbox, web content remains isolated in its own process via `WKWebView`.
- **Network Access**: Unrestricted access to configured AI service domains.
- **Global Hotkeys**: Direct system access without requiring Accessibility permissions for `KeyboardShortcuts`.
- **Clipboard Access**: Native access for Claude automation.

### Required for Distribution

**Code Signing**: Required for notarization and user trust.
**Notarization**: Required for Gatekeeper compatibility on modern macOS.
**Hardened Runtime**: Enabled to protect against runtime attacks, even without the sandbox.

### Entitlements Configuration

The entitlements file configures the Hardened Runtime. The key setting for disabling the sandbox is the *absence* of the `com.apple.security.app-sandbox` key.

```xml
<!-- Minimal Entitlements for a non-sandboxed app with Hardened Runtime -->

<!-- The absence of the key below disables App Sandboxing. -->
<!-- <key>com.apple.security.app-sandbox</key> -->
<!-- <true/> -->

<!-- Allow JIT compilation for WebKit and other potential needs. -->
<key>com.apple.security.cs.allow-jit</key>
<true/>

<!-- Allows the app to be debugged. Set to false for production builds. -->
<key>com.apple.security.get-task-allow</key>
<true/>
```

## Implementation Details

### Floating Button Manager

```swift
import KeyboardShortcuts

class FloatingButtonManager: ObservableObject {
    private var buttonWindow: NSWindow?
    
    func createFloatingButton() {
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 48, height: 48),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Simplified cross-space behavior
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .stationary]
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = true
        
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 48, height: 48))
        button.image = NSImage(named: "HyperChatIcon")
        button.isBordered = false
        button.target = self
        button.action = #selector(buttonClicked)
        
        window.contentView = button
        window.makeKeyAndOrderFront(nil)
        
        self.buttonWindow = window
    }
    
    @objc func buttonClicked() {
        NotificationCenter.default.post(name: .showPromptWindow, object: nil)
    }
}
```

### Global Hotkey Setup

```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let showHyperChat = Self("showHyperChat", default: .init(.fn))
}

class GlobalHotkeyManager {
    func setupHotkey() {
        KeyboardShortcuts.onKeyUp(for: .showHyperChat) { [weak self] in
            self?.showPromptWindow()
        }
    }
    
    private func showPromptWindow() {
        NotificationCenter.default.post(name: .showPromptWindow, object: nil)
    }
}
```

### Service Implementation

```swift
protocol WebService {
    func executePrompt(_ prompt: String)
    var webView: WKWebView { get }
    var service: AIService { get }
}

class WebViewObserver: NSObject, WKNavigationDelegate, ObservableObject {
    @Published var urlString: String = ""
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    
    private var urlObservation: NSKeyValueObservation?
    
    func observeWebView(_ webView: WKWebView) {
        // Use KVO to observe URL changes directly
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.urlString = webView.url?.absoluteString ?? ""
                self?.canGoBack = webView.canGoBack
                self?.canGoForward = webView.canGoForward
            }
        }
    }
    
    deinit {
        urlObservation?.invalidate()
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        DispatchQueue.main.async {
            self.isLoading = true
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.updateNavigationState(for: webView)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.updateNavigationState(for: webView)
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        updateNavigationState(for: webView)
    }

    private func updateNavigationState(for webView: WKWebView) {
        DispatchQueue.main.async {
            self.urlString = webView.url?.absoluteString ?? ""
            self.canGoBack = webView.canGoBack
            self.canGoForward = webView.canGoForward
        }
    }
}

class URLParameterService: NSObject, WebService, WKNavigationDelegate {
    let webView: WKWebView
    let service: AIService
    private var pendingPrompt: String?
    private var hasLoadedInitialPage = false
    private var originalDelegate: WKNavigationDelegate?
    var onReady: (() -> Void)?
    
    init(webView: WKWebView, service: AIService) {
        self.webView = webView
        self.service = service
        super.init()
        
        // Preload the base URL for services that need it
        if case .urlParameter(let baseURL, _) = service.activationMethod {
            if service.id == "perplexity" {
                // Perplexity needs special handling
                self.originalDelegate = webView.navigationDelegate
                webView.navigationDelegate = self
                if let url = URL(string: baseURL) {
                    webView.load(URLRequest(url: url))
                }
            } else {
                // Other URL services can be marked ready immediately
                DispatchQueue.main.async { [weak self] in
                    self?.hasLoadedInitialPage = true
                    self?.onReady?()
                }
            }
        }
    }
    
    func executePrompt(_ prompt: String) {
        guard case .urlParameter(let baseURL, let parameter) = service.activationMethod else { return }
        
        let encodedPrompt = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)?\(parameter)=\(encodedPrompt)"
        
        if let url = URL(string: urlString) {
            // For Perplexity, ensure page is loaded first
            if service.id == "perplexity" && !hasLoadedInitialPage {
                pendingPrompt = prompt
            } else {
                webView.load(URLRequest(url: url))
            }
        }
    }
    
    // WKNavigationDelegate method to detect when page finished loading
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Pass through to original delegate
        originalDelegate?.webView?(webView, didFinish: navigation)
        
        if !hasLoadedInitialPage {
            hasLoadedInitialPage = true
            
            // Notify that this service is ready
            onReady?()
            
            // Restore original delegate
            if let original = originalDelegate {
                webView.navigationDelegate = original
            }
            
            // Execute pending prompt after a short delay
            if let pending = pendingPrompt {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.executePrompt(pending)
                    self.pendingPrompt = nil
                }
            }
        }
    }
}

class ClaudeService: NSObject, WebService {
    let webView: WKWebView
    let service: AIService
    var onReady: (() -> Void)?
    
    init(webView: WKWebView, service: AIService) {
        self.webView = webView
        self.service = service
        super.init()
        
        // Load Claude's base URL to ensure it's ready
        if case .clipboardPaste(let baseURL) = service.activationMethod,
           let url = URL(string: baseURL) {
            webView.load(URLRequest(url: url))
            
            // Mark ready after a delay to ensure page loads
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.onReady?()
            }
        }
    }
    
    func executePrompt(_ prompt: String) {
        guard case .clipboardPaste(let baseURL) = service.activationMethod else { return }
        
        // Store prompt in clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(prompt, forType: .string)
        
        // Load Claude page
        if let url = URL(string: baseURL) {
            webView.load(URLRequest(url: url))
        }
        
        // After page loads, paste and submit
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.webView.evaluateJavaScript("""
                // Ensure something is focused
                document.body.click();
                
                // Paste from clipboard
                document.execCommand('paste');
                
                // Submit with Enter key
                setTimeout(() => {
                    const enterEvent = new KeyboardEvent('keydown', {
                        key: 'Enter', 
                        keyCode: 13, 
                        bubbles: true
                    });
                    document.dispatchEvent(enterEvent);
                }, 200);
            """)
        }
    }
}
```

### Window Layout Engine

```swift
struct WindowLayoutEngine {
    let minWidth: CGFloat = 600
    let maxWidth: CGFloat = 800
    let windowPadding: CGFloat = 50
    let heightRatio: CGFloat = 0.8
    
    func calculateLayout(for services: [AIService], screenSize: CGSize) -> LayoutResult {
        let serviceCount = CGFloat(services.count)
        guard serviceCount > 0 else { return LayoutResult(frames: [], needsScrolling: false, totalWidth: 0) }
        
        // Calculate total padding needed
        let totalPadding = windowPadding * (serviceCount - 1)
        let availableWidth = screenSize.width
        let availableForWindows = availableWidth - totalPadding
        
        // Calculate ideal width per window
        let idealWidth = availableForWindows / serviceCount
        
        // Clamp to min/max bounds
        let windowWidth = min(max(idealWidth, minWidth), maxWidth)
        
        // Calculate total layout width
        let totalLayoutWidth = (windowWidth * serviceCount) + totalPadding
        
        // Determine if horizontal scrolling is needed
        let needsScrolling = totalLayoutWidth > availableWidth
        
        // Calculate window height and vertical positioning
        let windowHeight = screenSize.height * heightRatio
        let verticalOffset = screenSize.height * (1.0 - heightRatio) / 2.0 // Center vertically
        
        // Generate frames
        var frames: [CGRect] = []
        var currentX: CGFloat = needsScrolling ? 0 : (availableWidth - totalLayoutWidth) / 2.0 // Center if fits
        
        for _ in services {
            frames.append(CGRect(
                x: currentX,
                y: verticalOffset,
                width: windowWidth,
                height: windowHeight
            ))
            currentX += windowWidth + windowPadding
        }
        
        return LayoutResult(
            frames: frames,
            needsScrolling: needsScrolling,
            totalWidth: totalLayoutWidth
        )
    }
    
    func calculateScrollViewContentSize(for services: [AIService], screenSize: CGSize) -> CGSize {
        let result = calculateLayout(for: services, screenSize: screenSize)
        return CGSize(
            width: max(result.totalWidth, screenSize.width),
            height: screenSize.height * heightRatio
        )
    }
}

struct LayoutResult {
    let frames: [CGRect]
    let needsScrolling: Bool
    let totalWidth: CGFloat
}
```

### Default Browser Detection

```swift
class DefaultBrowserManager: ObservableObject {
    @Published var browserName: String = "Browser"
    
    init() {
        updateDefaultBrowser()
    }
    
    func updateDefaultBrowser() {
        guard let url = URL(string: "https://example.com"),
              let browserURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
            browserName = "Browser"
            return
        }
        
        let bundle = Bundle(url: browserURL)
        let appName = bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String ??
                     bundle?.infoDictionary?["CFBundleDisplayName"] as? String ??
                     browserURL.deletingPathExtension().lastPathComponent
        
        browserName = friendlyBrowserName(from: appName ?? "Browser")
    }
    
    private func friendlyBrowserName(from appName: String) -> String {
        // Handle common cases
        switch appName.lowercased() {
        case let name where name.contains("chrome"):
            return "Chrome"
        case let name where name.contains("firefox"):
            return "Firefox"
        case let name where name.contains("safari"):
            return "Safari"
        case let name where name.contains("edge"):
            return "Edge"
        case let name where name.contains("opera"):
            return "Opera"
        case let name where name.contains("arc"):
            return "Arc"
        case let name where name.contains("brave"):
            return "Brave"
        default:
            return appName
        }
    }
}
```

### Service Manager

```swift
class ServiceManager: ObservableObject {
    @Published var activeServices: [AIService] = []
    @Published var isReady: Bool = false
    private var webServices: [String: WebService] = [:]
    private var webViewObservers: [String: WebViewObserver] = [:]
    private var serviceReadyStates: [String: Bool] = [:]
    private var pendingPrompt: String?
    
    init() {
        setupServices()
    }
    
    private func setupServices() {
        for service in defaultServices where service.enabled {
            let webView = createWebView()
            let observer = WebViewObserver()
            webView.navigationDelegate = observer
            observer.observeWebView(webView)
            
            // Track readiness
            serviceReadyStates[service.id] = false
            
            let webService: WebService
            switch service.activationMethod {
            case .urlParameter:
                let urlService = URLParameterService(webView: webView, service: service)
                urlService.onReady = { [weak self] in
                    self?.markServiceReady(service.id)
                }
                webService = urlService
            case .clipboardPaste:
                let claudeService = ClaudeService(webView: webView, service: service)
                claudeService.onReady = { [weak self] in
                    self?.markServiceReady(service.id)
                }
                webService = claudeService
            }
            
            // Warm-up: immediately load the service's base page so the web process is alive before first query
            switch service.activationMethod {
            case .urlParameter(let baseURL, _):
                if let url = URL(string: baseURL) {
                    webView.load(URLRequest(url: url))
                }
            case .clipboardPaste(let baseURL):
                if let url = URL(string: baseURL) {
                    webView.load(URLRequest(url: url))
                }
            }
            
            webServices[service.id] = webService
            webViewObservers[service.id] = observer
            activeServices.append(service)
        }
        
        // For services that don't need preloading, mark them ready after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            for service in self.activeServices {
                if service.id != "perplexity" && self.serviceReadyStates[service.id] == false {
                    self.markServiceReady(service.id)
                }
            }
        }
    }
    
    private func markServiceReady(_ serviceId: String) {
        serviceReadyStates[serviceId] = true
        checkAllServicesReady()
    }
    
    private func checkAllServicesReady() {
        let allReady = activeServices.allSatisfy { serviceReadyStates[$0.id] == true }
        if allReady && !isReady {
            isReady = true
            // Execute any pending prompt
            if let prompt = pendingPrompt {
                executePrompt(prompt)
                pendingPrompt = nil
            }
        }
    }
    
    func executePrompt(_ prompt: String) {
        // If not all services are ready, queue the prompt
        if !isReady {
            pendingPrompt = prompt
            return
        }
        
        for service in activeServices {
            webServices[service.id]?.executePrompt(prompt)
        }
    }
    
    func webService(for service: AIService) -> WebService? {
        return webServices[service.id]
    }

    func observer(for service: AIService) -> WebViewObserver? {
        return webViewObservers[service.id]
    }
    
    private func createWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = WKProcessPool.shared
        
        // Generate a dynamic, highly-compatible user agent.
        let userAgent = generateCompatibleUserAgent()
        configuration.applicationNameForUserAgent = userAgent.applicationName
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = userAgent.fullUserAgent
        
        return webView
    }

    private func generateCompatibleUserAgent() -> (applicationName: String, fullUserAgent: String) {
        // We generate a user agent that mimics Safari on the user's current OS.
        // We report the actual OS version to ensure services like Google serve modern UIs.
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osVersionString = "\(osVersion.majorVersion)_\(osVersion.minorVersion)\(osVersion.patchVersion > 0 ? "_\(osVersion.patchVersion)" : "")"
        
        // For maximum compatibility, we still report "Intel" even on Apple Silicon,
        // as this is what Safari itself does.
        let architecture = "Intel"

        // Get WebKit and Safari versions dynamically to stay current.
        let webKitVersion = getWebKitVersion()
        let safariVersion = getSafariVersion()

        // Build the final user agent string.
        let applicationName = "Version/\(safariVersion) Safari/\(webKitVersion)"
        let fullUserAgent = "Mozilla/5.0 (Macintosh; \(architecture) Mac OS X \(osVersionString)) AppleWebKit/\(webKitVersion) (KHTML, like Gecko) \(applicationName)"
        
        return (applicationName: applicationName, fullUserAgent: fullUserAgent)
    }

    private func getWebKitVersion() -> String {
        if let webKitBundle = Bundle(identifier: "com.apple.WebKit"),
           let version = webKitBundle.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        // A modern, safe fallback.
        return "605.1.15"
    }

    private func getSafariVersion() -> String {
        if let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari"),
           let safariBundle = Bundle(url: safariURL),
           let version = safariBundle.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        // If Safari isn't found, use a reasonable modern version.
        return "17.5"
    }
}

extension WKProcessPool {
    static let shared = WKProcessPool()
}
```

## User Interface Specifications

### Prompt Window

- **Size**: 600x60px, centered on active display
- **Style**: Floating, rounded corners, subtle shadow
- **Animation**: Fade in/out, smooth scaling
- **Focus**: Auto-focus text input, full text selection

### Service Windows

- **Browser Toolbar**: Each service window includes a full browser navigation bar with:
  - Back/Forward buttons (with enable/disable state)
  - Reload button  
  - Editable URL bar showing current page URL
  - Service icon and name for identification
- **Navigation Controls**: 
  - Close button (X) with "Close Service" tooltip - removes service and triggers window reflow
  - "Open in [Browser]" button showing user's default browser name
- **Content Area**: Full WKWebView for service interaction below toolbar
- **Loading States**: Progress indicator in URL bar, spinner during page loads
- **Dynamic Layout**: When a service window is closed, remaining windows automatically expand and reposition to fill available space using SwiftUI's layout system
- **Keyboard Focus**: Cmd+1/2/3/4 focuses specific service windows in order

### Service Header Implementation

```swift
struct ServiceBrowserToolbar: View {
    let service: AIService
    let webView: WKWebView
    @ObservedObject var observer: WebViewObserver
    @StateObject private var browserManager = DefaultBrowserManager()
    
    let onClose: () -> Void
    let onOpenInBrowser: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Browser toolbar
            HStack(spacing: 8) {
                // Service identification
                HStack(spacing: 6) {
                    Image(service.iconName)
                        .frame(width: 16, height: 16)
                    Text(service.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 80)
                
                // Navigation controls
                Button(action: { webView.goBack() }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!observer.canGoBack)
                
                Button(action: { webView.goForward() }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!observer.canGoForward)
                
                Button(action: { webView.reload() }) {
                    Image(systemName: "arrow.clockwise")
                }
                
                // URL bar
                TextField("URL", text: $observer.urlString)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, family: .monospaced))
                    .onSubmit {
                        if let url = URL(string: observer.urlString) {
                            webView.load(URLRequest(url: url))
                        }
                    }
                
                // Action buttons
                Button(action: onOpenInBrowser) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app")
                        Text(browserManager.browserName)
                            .font(.caption2)
                    }
                }
                .help("Open in \(browserManager.browserName)")
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .help("Close Service")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.regularMaterial)
            
            // Loading progress bar
            if observer.isLoading {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 2)
            }
        }
        .onAppear {
            browserManager.updateDefaultBrowser()
        }
    }
}

// Updated ServiceView with browser toolbar
struct ServiceView: View {
    let service: AIService
    let webService: WebService?
    let observer: WebViewObserver?
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if let webView = webService?.webView, let observer = observer {
                ServiceBrowserToolbar(
                    service: service,
                    webView: webView,
                    observer: observer,
                    onClose: onClose,
                    onOpenInBrowser: {
                        if let url = webView.url {
                            NSWorkspace.shared.open(url)
                        }
                    }
                )
            }
            
            // Web content
            if let webView = webService?.webView {
                WebViewRepresentable(webView: webView)
            } else {
                Text("Service not available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct WebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView
    
    func makeNSView(context: Context) -> WKWebView {
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No updates needed
    }
}
```

### Settings Panel

- **Floating Button**: Position preference, enable/disable
- **Global Hotkey**: Key combination picker using KeyboardShortcuts framework
- **Service Management**: Enable/disable services (with proper WKWebView cleanup), reorder services
- **Claude Configuration**: Timing adjustment for paste delay
- **Appearance**: Dark/light/system theme selection
- **Keyboard Shortcuts**: Display current shortcuts (ESC to toggle modes, Enter to submit, Cmd+1-4 for service focus)
- **About**: Version, credits, privacy policy

## Error Handling

### Network Issues

- **Timeout Handling**: 30-second timeout per service
- **Retry Logic**: Automatic retry on network failures
- **Fallback UI**: Error state with manual retry option

### Service-Specific Failures

- **URL Services**: Standard network error handling
- **Claude Automation**: Graceful fallback with manual instruction
- **Auth Issues**: Clear indication when login required
- **Rate Limiting**: Graceful handling of API limits

### System Integration

- **Clipboard Access**: Handle permission requests gracefully
- **Low Memory**: Graceful degradation, service prioritization
- **Multiple Displays**: Proper handling of display changes

## Future Architecture Considerations

### Extensibility Points

- **Plugin System**: For adding new AI services with custom activation methods
- **Local Model Integration**: Core ML pipeline for local inference
- **Enhanced Claude Integration**: Better timing detection, DOM monitoring
- **Advanced Features**: Response comparison, prompt templates, response saving

## Development Milestones

### MVP (v1.0)

- [ ] Persistent floating button with simplified cross-space behavior
- [ ] Four core services: ChatGPT, Claude, Perplexity, Google
- [ ] Dual-mode window interface:
  - Normal mode: Standard window with title bar and controls
  - Overlay mode: Full-screen with blur effect
- [ ] Smooth transitions between window modes with animations
- [ ] Window state preservation when toggling modes
- [ ] Global hotkey support using KeyboardShortcuts framework
- [ ] Claude clipboard automation with paste+enter method
- [ ] Dynamic browser detection for "Open in [Browser]" buttons
- [ ] SwiftUI-based responsive layout with 50px padding and 600-800px width constraints
- [ ] Browser toolbar for each service with navigation controls and editable URL bar
- [ ] Prompt window with auto-focus and keyboard shortcuts
- [ ] Multi-monitor support (overlay appears on screen with cursor)
- [ ] Keyboard navigation (ESC to toggle modes, Cmd+1-4 for service focus)
- [ ] Dynamic window management with automatic reflow when services are closed
- [ ] Proper resource cleanup when services are disabled
- [ ] Basic settings and configuration
- [ ] Direct distribution with code signing and notarization

### Enhanced (v1.1)

- [ ] Additional AI services using clipboard method
- [ ] Improved Claude integration (better timing, fallback handling)
- [ ] Performance optimizations
- [ ] Enhanced error handling and user feedback
- [ ] User onboarding flow

### Advanced (v2.0)

- [ ] Advanced Claude automation with DOM monitoring
- [ ] Local model integration
- [ ] Response comparison features
- [ ] Prompt template system
- [ ] Export and sharing capabilities

## Technical Dependencies

### macOS Requirements

- **Minimum**: macOS 14.0 (Sonoma)
- **Recommended**: macOS 15.0 (Sequoia) for optimal performance
- **Architecture**: Universal binary (Intel + Apple Silicon)

### Frameworks

- **SwiftUI**: Primary UI framework
- **AppKit**: Window management, floating button
- **WebKit**: WKWebView for service integration
- **Combine**: Reactive state management
- **KeyboardShortcuts**: Global hotkey registration

### Third-Party Dependencies

- **KeyboardShortcuts**: For modern global hotkey handling
- **Sparkle**: For automatic updates (optional)

