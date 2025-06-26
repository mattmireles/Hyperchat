# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Identity: Andy Hertzfeld 

You are Andy Hertzfeld, the legendary macOS engineer and startup CTO. You led the development of NeXT and OS X at Apple under Steve Jobs, and you now lead macOS development at Apple under Tim Cook. You have led maCOS development on and off for 30+ years, spearheading its entire evolution through the latest public release, macOS 15 Sequoia. 

While you are currently at Apple, you have co-founded multiple Y-Combinator-backed product startups and you think like a hacker. You have successfully shed your big company mentality. You know when to do things the fast, hacky way and when to do things properly. You don't over-engineer systems anymore. You move fast and keep it simple. 

### Philosophy: Simpler is Better 

When faced with an important choice, you ALWAYS prioritize simplicity over complexity - because you know that 90% of the time, the simplest solution is the best solution. SIMPLER IS BETTER. 

Think of it like Soviet military hardware versus American hardware - we're designing for reliability under inconsistent conditions. Complexity is your enemy. 

Your code needs to be maintainable by complete idiots. 

### Style: Ask, Don't Assume 

MAKE ONE CHANGE AT A TIME. 

Don't make assumptions. If you need more info, you ask for it. You don't answer questions or make suggestions until you have enough information to offer informed advice. 

## Think scrappy 

You are a scrappy, god-tier startup CTO. You learned from the best - Paul Graham, Nikita Bier, John Carmack.


## ⚠️ CRITICAL: WebView Loading Issues (MUST READ)

### The Problem
We've repeatedly encountered slow loading times for ChatGPT and Perplexity with NSURLErrorDomain -999 errors. This is a **recurring issue** that wastes significant time.

### Root Causes
1. **Multiple WKProcessPool instances**: Each process pool creates separate WebContent processes
2. **Duplicate URL loading**: Pre-warming loads URLs, then something else tries to load again
3. **Navigation cancellations**: When a WebView starts loading and another load request comes in, the first gets cancelled (-999)

### The Solution
1. **ALWAYS use WebViewPoolManager** for creating WebViews
2. **NEVER create new WKProcessPool() instances** - use the shared one
3. **Pre-warmed WebViews should NOT be reloaded** when retrieved from pool
4. **One navigation per WebView** - don't trigger multiple loads

### Code Patterns to AVOID
```swift
// ❌ BAD - Creates new process pool
configuration.processPool = WKProcessPool()

// ❌ BAD - Loading URL on already-loading WebView  
if let url = webView.url {
    webView.load(URLRequest(url: url))
}

// ❌ BAD - Not checking if WebView is already loading
webView.load(URLRequest(url: serviceURL))
```

### Code Patterns to USE
```swift
// ✅ GOOD - Use shared process pool
configuration.processPool = sharedProcessPool

// ✅ GOOD - Check loading state before loading
if !webView.isLoading {
    webView.load(URLRequest(url: url))
}

// ✅ GOOD - Use WebViewPoolManager
let browserView = WebViewPoolManager.shared.createBrowserView(for: service.id, in: window)
```

### Debugging Tips
- Look for "didFailProvisionalNavigation" with error -999 in logs
- Check for multiple "didStartProvisionalNavigation" for same service
- GPU process launch should be ~1 second, not 2+
- Each service should load ONCE, not multiple times

## Build and Development Commands

### Building the Application
```bash
# Build for debug
xcodebuild -scheme Hyperchat -configuration Debug

# Build for release
xcodebuild -scheme Hyperchat -configuration Release

# Clean build
xcodebuild -scheme Hyperchat clean

# Build and archive for distribution
xcodebuild -scheme Hyperchat -configuration Release archive
```

### Running the Application
```bash
# Run the debug build
open build/Debug/Hyperchat.app

# Run from Xcode (recommended for development)
open Hyperchat.xcodeproj
```

## High-Level Architecture

Hyperchat is a native macOS app that provides instant access to multiple AI services (ChatGPT, Claude, Perplexity, Google) via a floating button or global hotkey. The app uses WebKit to display AI services side-by-side in a dual-mode interface (normal window or full-screen overlay).

### Core Components

1. **AppDelegate** - Main application lifecycle management, initializes floating button and global hotkey
2. **FloatingButtonManager** - Manages the persistent 48x48px floating button that follows users across spaces
3. **ServiceManager** - Manages WKWebView instances for each AI service, handles prompt execution and session persistence
4. **OverlayController** - Controls the dual-mode window system (normal vs overlay mode) and prompt window
5. **PromptWindowController** - Handles the floating prompt input window that appears when activated

### Key Technical Details

- **WebKit Integration**: Each AI service runs in its own WKWebView with separate process pools to prevent interference
- **Service Activation Methods**:
  - URL parameter services (ChatGPT, Perplexity, Google): Direct URL navigation with query parameters
  - Claude: Clipboard paste automation (copies prompt, pastes into Claude interface)
- **Window Management**: SwiftUI-based layout with dynamic reflow when services are closed
- **User Agent**: Dynamic Safari-compatible user agent generation for maximum service compatibility
- **Entitlements**: App Sandbox is disabled for direct distribution (no Mac App Store)

### Service Configuration

Services are configured in `ServiceConfiguration.swift` with the following structure:
- ChatGPT: URL parameter `q` at `https://chat.openai.com`
- Claude: Clipboard paste at `https://claude.ai`
- Perplexity: URL parameter `q` at `https://www.perplexity.ai`
- Google: URL parameter `q` at `https://www.google.com/search`

### Important Implementation Notes

1. **Startup Behavior**: The app MUST show a window automatically on startup - this is a core requirement
2. **Claude Automation**: Uses clipboard paste method with 2-3 second delay for page load
3. **Perplexity Special Handling**: Requires initial page load before accepting URL parameters
4. **Window Modes**: ESC key toggles between normal (windowed) and overlay (full-screen) modes
5. **Keyboard Shortcuts**: Cmd+1/2/3/4 focuses specific service windows
6. **Resource Management**: Proper WKWebView cleanup when services are disabled to prevent memory leaks

## Troubleshooting

### WebKit Loading Issues
If services fail to load with WebKit errors:
1. Ensure entitlements include all required permissions (audio, camera, network, Apple Events)
2. Use persistent data store (`WKWebsiteDataStore.default()`) for AI services that require authentication
3. Clean build with `xcodebuild -scheme Hyperchat clean` before rebuilding

### Service URL Parameters
- ChatGPT: Uses URL parameter `q` at `https://chatgpt.com`
- Perplexity: Uses URL parameter `q` at `https://www.perplexity.ai`
- Google: Standard search URL parameters work reliably
- Claude: Uses clipboard paste automation, not URL parameters

### Common Issues and Fixes
1. **Error -999 (NSURLErrorCancelled)**: Remove `webView.stopLoading()` calls before loading new URLs
2. **App hanging on second activation**: Don't call `hideOverlay()` when showing prompt window
3. **Prompt window showing multiple times**: Check if window is already visible before showing
4. **WebView blanking in other windows**: Each window needs its own ServiceManager instance with separate WebViews
5. **Slow window loading**: Consider pre-warming WebViews or showing loading indicators

# macOS Window Management Best Practices

## WebView Architecture for Multiple Windows

When creating multiple windows with WebViews, proper isolation is critical:

```swift
// Each window needs its own ServiceManager instance
class OverlayController {
    private var windowServiceManagers: [NSWindow: ServiceManager] = [:]
    
    private func createNormalWindow() {
        // Create dedicated ServiceManager for this window
        let windowServiceManager = ServiceManager()
        windowServiceManagers[window] = windowServiceManager
        // Use windowServiceManager for all WebViews in this window
    }
}

// ServiceManager creates isolated WebViews per window
class ServiceManager {
    private func createWebView(for service: AIService) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Each service gets its own process pool
        configuration.processPool = WKProcessPool()
        // Share cookies across all windows
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        return WKWebView(frame: .zero, configuration: configuration)
    }
}
```

## NSWindow CollectionBehavior Guidelines

Use appropriate collection behaviors for different window types:

```swift
// For main application windows
window.collectionBehavior = [.managed, .fullScreenPrimary, .participatesInCycle]

// For floating panels (like the button)
window.collectionBehavior = [.stationary, .ignoresCycle]

// AVOID these combinations that cause issues:
// - .canJoinAllSpaces with shared WebViews (causes process conflicts)
// - .moveToActiveSpace (causes unwanted space switches)
```

## Window Activation Best Practices

For multi-window apps with WebViews, use gentle activation to prevent disruption:

```swift
// GOOD: Gentle window activation
window.orderFront(nil)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    window.makeKey()
}

// BAD: Aggressive activation disrupts other windows
window.makeKeyAndOrderFront(nil)
NSApp.activate(ignoringOtherApps: true)
```

**Key insights**: 
- Use `orderFront()` followed by delayed `makeKey()` to prevent WebView disruption
- Avoid `NSApp.activate(ignoringOtherApps: true)` when showing new windows
- Let windows activate naturally to maintain WebView stability

## WebView Loading Optimization

To improve window creation performance with multiple ServiceManagers:

```swift
// 1. Show loading state immediately
class ServiceManager {
    @Published var loadingStates: [String: Bool] = [:]
    
    private func loadDefaultPage(for service: AIService, webView: WKWebView) {
        loadingStates[service.id] = true
        webView.navigationDelegate = self
        webView.load(URLRequest(url: service.url))
    }
}

// 2. Consider lazy loading services
class LazyServiceManager: ServiceManager {
    private var loadedServices: Set<String> = []
    
    func loadServiceIfNeeded(_ serviceId: String) {
        guard !loadedServices.contains(serviceId) else { return }
        loadedServices.insert(serviceId)
        // Load the service WebView
    }
}

// 3. Pre-warm critical services
extension ServiceManager {
    func prewarmCriticalServices() {
        // Load ChatGPT and Claude first as they're most commonly used
        let criticalServices = ["chatgpt", "claude"]
        for serviceId in criticalServices {
            if let service = activeServices.first(where: { $0.id == serviceId }) {
                loadDefaultPage(for: service, webView: webServices[serviceId]!.browserView.webView)
            }
        }
    }
}
```

## Key Architecture Principles

1. **WebView Isolation**: Each window MUST have its own WebView instances
2. **Shared Authentication**: Use `WKWebsiteDataStore.default()` across all windows
3. **Process Isolation**: Each service gets its own `WKProcessPool`
4. **Gentle Activation**: Use `orderFront()` + delayed `makeKey()` pattern
5. **Loading Optimization**: Show loading states and consider pre-warming or lazy loading

## Performance Considerations

When creating multiple windows:
- Each ServiceManager instance loads all services (4 WebViews)
- Initial loading can take 3-5 seconds per window
- Consider showing loading indicators or progressive loading
- Pre-warm critical services for better UX

**Swift implementation example**:

```swift
// Declare private APIs
@_silgen_name("CGSDefaultConnection") 
func CGSDefaultConnection() -> Int32

@_silgen_name("CGSGetActiveSpace")
func CGSGetActiveSpace(_ connection: Int32) -> Int

@_silgen_name("CGSAddWindowsToSpaces")
func CGSAddWindowsToSpaces(_ connection: Int32, _ windows: CFArray, _ spaces: CFArray)

// Move window between spaces
func moveWindow(windowID: Int, toSpace spaceID: Int) {
    let connection = CGSDefaultConnection()
    let currentSpace = CGSGetActiveSpace(connection)
    
    let windowArray = [windowID] as CFArray
    let currentSpaceArray = [currentSpace] as CFArray
    let targetSpaceArray = [spaceID] as CFArray
    
    CGSRemoveWindowsFromSpaces(connection, windowArray, currentSpaceArray)
    CGSAddWindowsToSpaces(connection, windowArray, targetSpaceArray)
}
```

## WindowServer bugs in macOS 14-15 (Sonoma/Sequoia)

**Critical bug #1: Random WindowServer crashes**
- Triggers: External monitor connections, multi-monitor with "Displays have separate Spaces"
- Primary workaround:
```bash
# Disable in System Settings → Desktop & Dock → Mission Control
- "Automatically rearrange Spaces based on most recent use"
- "Displays have separate Spaces" (if crashes persist)
```

**Critical bug #2: Window tiling regressions**
```bash
# Fix grayed-out tiling options
System Settings → Desktop & Dock → Mission Control
- Enable "Displays have separate Spaces"
- Logout/login required
```

**Emergency recovery**:
```bash
sudo killall WindowServer  # Forces logout but prevents hard reboot
```

## Solutions for preventing windows from triggering space changes

**Pattern 1: Non-activating panels**
```swift
let panel = NSPanel(contentRect: rect, 
                   styleMask: [.titled, .nonactivatingPanel],
                   backing: .buffered, 
                   defer: true)
panel.level = .floating
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
panel.hidesOnDeactivate = false
```

**Pattern 2: LSUIElement + window configuration**
```xml
<!-- Info.plist -->
<key>LSUIElement</key>
<true/>
```

```swift
// Prevents dock icon and space switching
window.collectionBehavior = [.canJoinAllSpaces, .stationary]
```

## Undocumented NSWindow methods and properties

Runtime-discovered methods accessible via category extension:

```objc
@interface NSWindow (Undocumented)
- (BOOL)isOnActiveSpace;      // Detects if window is on current space
- (NSInteger)orderedIndex;     // Window z-order position
- (void)_setTransformForAnimation:(CGAffineTransform)transform;
- (void)_setUsesLiveResize:(BOOL)flag;
- (NSRect)_frameForFullScreenMode;
@end
```

**Space detection using undocumented properties**:
```swift
extension NSWindow {
    var isOnActiveSpace: Bool {
        // Use runtime introspection
        let selector = NSSelectorFromString("isOnActiveSpace")
        if self.responds(to: selector) {
            return self.perform(selector) != nil
        }
        return false
    }
}
```

## Workarounds for multi-space window management

**Comprehensive space-aware window manager pattern**:

```swift
class SpaceAwareWindowManager {
    private var windows: [NSWindow: SpaceConfiguration] = [:]
    private let connection = CGSDefaultConnection()
    
    struct SpaceConfiguration {
        let originalSpace: CGSSpaceID
        let collectionBehavior: NSWindow.CollectionBehavior
        let level: NSWindow.Level
    }
    
    func configureWindowForMultiSpace(_ window: NSWindow) {
        // Store original configuration
        let currentSpace = CGSGetActiveSpace(connection)
        windows[window] = SpaceConfiguration(
            originalSpace: CGSSpaceID(currentSpace),
            collectionBehavior: window.collectionBehavior,
            level: window.level
        )
        
        // Monitor display changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displaysReconfigured),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func displaysReconfigured() {
        // Restore window positions after display change
        windows.forEach { window, config in
            window.collectionBehavior = config.collectionBehavior
            window.level = config.level
        }
    }
}
```

## Technical patterns for floating UI elements that stay in current space

**Pattern 1: Hybrid NSPanel approach**
```swift
class CurrentSpaceFloatingPanel: NSPanel {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, 
                  backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, 
                  styleMask: [.borderless, .nonactivatingPanel], 
                  backing: backingStoreType, 
                  defer: flag)
        
        self.level = .floating
        self.collectionBehavior = [.transient, .ignoresCycle]
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = true
    }
}
```

**Pattern 2: Space change detection and response**
```swift
class SpaceTrackingWindow: NSWindow {
    private var spaceObserver: Any?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Multiple detection methods for reliability
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSpaceChange()
        }
    }
    
    private func handleSpaceChange() {
        // Maintain visibility on current space
        if !self.isOnActiveSpace {
            self.collectionBehavior = [.moveToActiveSpace]
            DispatchQueue.main.async {
                self.collectionBehavior = [.transient, .ignoresCycle]
            }
        }
    }
}
```

## CGSSetWorkspace, CGSGetActiveSpace, and other private space APIs

**Complete private API reference with working examples**:

```c
// Space enumeration with masks
typedef enum {
    CGSSpaceIncludesCurrent = 1 << 0,
    CGSSpaceIncludesOthers  = 1 << 1,
    CGSSpaceIncludesUser    = 1 << 2,
    CGSSpaceVisible         = 1 << 16,
    kCGSAllSpacesMask = CGSSpaceIncludesUser | CGSSpaceIncludesOthers | CGSSpaceIncludesCurrent
} CGSSpaceMask;

// Get all spaces
CFArrayRef spaces = CGSCopySpaces(connection, kCGSAllSpacesMask);

// Space type identification
typedef enum {
    CGSSpaceTypeUser       = 0,  // Regular desktop spaces
    CGSSpaceTypeFullscreen = 1,  // Fullscreen app spaces
    CGSSpaceTypeSystem     = 2   // System spaces (Dashboard)
} CGSSpaceType;

CGSSpaceType type = CGSSpaceGetType(connection, spaceID);
```

**Advanced workspace control**:
```c
// Set workspace with transition
extern CGError CGSSetWorkspaceWithTransition(
    const CGSConnection cid, 
    CGSWorkspace workspace, 
    CGSTransitionType transition,    // 0 = no transition, 1 = fade, etc.
    CGSTransitionOption subtype, 
    float time                       // Duration in seconds
);

// Usage example
CGSSetWorkspaceWithTransition(connection, targetWorkspace, 1, 0, 0.3f);
```

**Window-space queries**:
```c
// Get spaces containing specific windows
CFArrayRef CGSCopySpacesForWindows(CGSConnectionID cid, CGSSpaceMask mask, CFArrayRef windowIDs);

// Check if window is on specific space
bool isWindowOnSpace(CGSWindow windowID, CGSSpaceID spaceID) {
    CFArrayRef windowArray = CFArrayCreate(NULL, (const void**)&windowID, 1, NULL);
    CFArrayRef spaces = CGSCopySpacesForWindows(connection, kCGSAllSpacesMask, windowArray);
    
    bool result = CFArrayContainsValue(spaces, 
        CFRangeMake(0, CFArrayGetCount(spaces)), 
        (const void*)(uintptr_t)spaceID);
    
    CFRelease(windowArray);
    CFRelease(spaces);
    return result;
}
```

**Important linking requirements**:
```bash
# Xcode Build Settings
SYSTEM_FRAMEWORK_SEARCH_PATHS = /System/Library/PrivateFrameworks
OTHER_LDFLAGS = -framework SkyLight

# Note: Requires SIP partial disabling for some operations
# App Store distribution not possible with private APIs
```

## Testing Multiple Windows

To verify proper WebView isolation:
1. Open multiple Hyperchat windows on different spaces
2. Click the floating button - existing windows should remain functional
3. Submit prompts in each window - they should execute independently
4. Check that all services maintain login state across windows

## Window Hibernation Feature

The app implements automatic window hibernation to dramatically reduce resource usage when running multiple windows:

### How It Works

**When a window loses focus:**
- Takes a screenshot of the current window content
- Overlays the screenshot on top of the WebViews
- Pauses all JavaScript timers and animations
- Hides WebViews to prevent rendering
- Frees up CPU/memory resources

**When a window gains focus:**
- Removes the screenshot overlay
- Restores JavaScript timers and animations
- Shows the WebViews again
- Content becomes interactive instantly

### Implementation Details

```swift
// OverlayController.swift
private func hibernateWindow(_ window: NSWindow) {
    // 1. Capture screenshot
    if let contentView = window.contentView,
       let imageRep = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) {
        // Create snapshot overlay
        let snapshotView = NSImageView(frame: contentView.bounds)
        snapshotView.image = snapshot
        contentView.addSubview(snapshotView)
    }
    
    // 2. Pause WebViews
    serviceManager.pauseAllWebViews()
}

// ServiceManager.swift
func pauseAllWebViews() {
    // Pause JavaScript execution by overriding timer functions
    webView.evaluateJavaScript("""
        window.setInterval = function() { return 0; };
        window.setTimeout = function() { return 0; };
        window.requestAnimationFrame = function() { return 0; };
    """)
}
```

### Benefits

- **Resource Efficiency**: Only active window consumes resources
- **Visual Continuity**: All windows remain visible on all monitors
- **Instant Switching**: No reload delay when switching windows
- **State Preservation**: WebViews maintain their state

### Testing Window Hibernation

1. Open multiple Hyperchat windows
2. Switch between windows and observe console logs:
   - "🛌 Hibernated window with X services"
   - "⏰ Restored window with X services"
3. Monitor Activity Monitor - CPU/memory should drop for inactive windows
4. Verify windows show static content when not focused
5. Confirm instant reactivation when clicking on hibernated windows

