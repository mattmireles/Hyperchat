# **Hyperchat Codebase Map**

**High-Level Overview**

Hyperchat is a native macOS application that provides a multi-service interface to various AIs. The user can summon a prompt window via a floating button, enter a query, and see the results across multiple services simultaneously in a unified overlay window. The architecture is event-driven, using a combination of NSNotificationCenter for cross-module communication and Combine publishers for direct state updates between related components.

**Core Components & Interaction Flow**

Here is the step-by-step flow of a typical user interaction:

**1. AppDelegate (The Conductor)**

- **Job:** Manages the application lifecycle. On launch, it creates and connects all the primary controller objects.
- **Interaction:**
- Initializes FloatingButtonManager, PromptWindowController, and OverlayController.
- Initializes AnalyticsManager for usage tracking (enabled by default, user can disable).
- Acts as a central listener for key notifications, delegating tasks to the appropriate controller.

**2. FloatingButtonManager (The Greeter)**

- **Job:** Manages the small, persistent floating button that is always on screen.
- **Interaction:**
- **On Click**: When the user clicks the floating button, it calls promptWindowController.showWindow(...) to display the input field.

**3. PromptWindowController (The Scribe)**

- **Job:** Manages the popup window where the user types their prompt.
- **Interaction:**
- **On Submit**: When the user types a prompt and hits enter, it posts a notification named .showOverlay to the system, packaging the prompt text with it. It then closes itself.

**4. OverlayController (The Stage Manager)**

- **Job:** Manages the main window(s) that host the AI services.
- **Interaction:**
- **Receives Notification**: The AppDelegate catches the .showOverlay notification from the PromptWindowController and calls overlayController.showOverlay(with: prompt).
- **Creates Window**: It creates a new OverlayWindow.
- **Creates Controllers**: For each service, it creates a BrowserViewController and registers it with the ServiceManager.
- **Handoff to Logic**: Crucially, it creates a new, dedicated ServiceManager for that window and then calls serviceManager.executePrompt(prompt).

**5. ServiceManager (The Engine)**

- **Job:** Core orchestration unit that manages AI services and executes prompts. Refactored to focus solely on service management (reduced from 1600+ to under 900 lines).
- **Interaction:**
- **Service Setup**: Uses WebViewFactory to create WKWebViews, manages sequential loading of services
- **State Updates**: Publishes loading state via Combine (`@Published var areAllServicesLoaded`) and input focus events via `focusInputPublisher`
- **Executes Prompt**: It iterates through its list of active services and tells each one to execute the prompt. The method of execution depends on the service type:
- **URLParameterService (Google, Perplexity, etc.)**: Constructs a URL with the prompt as a query parameter (e.g., google.com/search?q=...) and tells the corresponding WKWebView to load it.
- **ClaudeService (and "Reply to All" mode)**: Navigates to the service's base URL and uses JavaScriptProvider to inject scripts that find the chat input, paste the prompt, and programmatically click the "submit" button.
- **Delegate Handoff**: After initial load, hands navigation control to BrowserViewController

**6. WebViewFactory (The Builder)**

- **Job:** Centralized factory for creating and configuring WKWebViews with all necessary settings
- **Interaction:**
- **Creates WebViews**: Configures process pools, user agents, content scripts, and message handlers
- **Shared Configuration**: Ensures consistent WebView setup across all services
- **Memory Optimization**: Uses shared WKProcessPool for all WebViews

**7. BrowserViewController (The Navigator)**

- **Job:** MVC controller that manages browser logic, navigation, and user interactions
- **Interaction:**
- **Navigation Management**: Takes over as WKNavigationDelegate after initial service load
- **UI Updates**: Manages URL display, back/forward buttons, and loading states
- **User Actions**: Handles reload, URL entry, and clipboard operations

**8. BrowserView (The Canvas)**

- **Job:** Pure view component that layouts browser UI elements
- **Interaction:**
- **Layout Only**: Manages visual arrangement of WebView, toolbar, and URL field
- **No Logic**: Delegates all actions to BrowserViewController

**9. UI Components (The Toolkit)**

- **ButtonState**: Observable state model for toolbar buttons
- **GradientToolbarButton**: SwiftUI component for animated toolbar buttons

**10. JavaScriptProvider (The Script Library)**

- **Job:** Centralized repository for all JavaScript code used throughout the application
- **Interaction:**
- **Script Generation**: Provides static methods that return JavaScript strings for various operations
- **Clean Separation**: Isolates 300+ lines of JavaScript from ServiceManager into organized, reusable methods
- **Key Scripts**: Paste automation, Claude-specific interactions, window hibernation pause/resume

**11. AnalyticsManager (The Data Collector)**

- **Job:** Centralized analytics service using Amplitude for usage tracking and product improvement
- **Interaction:**
- **Event Tracking**: Collects usage data on prompt submissions, button clicks, and webview interactions
- **Privacy-Focused**: No PII collected, only usage patterns and feature adoption metrics
- **Source Attribution**: Tracks whether prompts come from floating button vs direct window access
- **Service Usage**: Monitors which AI services users interact with most frequently
- **Configuration**: Loads API keys from Config.swift (excluded from version control)

**Key Architectural Patterns**

- **Hybrid Communication Model**: 
  - **NSNotificationCenter**: Used for cross-module events where loose coupling is beneficial (e.g., .showOverlay, .overlayDidHide)
  - **Combine Publishers**: Used for direct state updates between tightly related components (e.g., ServiceManager to OverlayController loading states)
- **Dedicated ServiceManager per Window**: Each OverlayWindow gets its own ServiceManager. This is a critical design choice for stability, isolating the web environments from each other and preventing crashes in one window from affecting others.
- **Shared WKProcessPool**: While each window has its own ServiceManager, all WKWebViews share a single WKProcessPool. This is a key memory optimization that significantly reduces the app's overall footprint.
- **Factory Pattern**: WebViewFactory centralizes all WKWebView configuration, ensuring consistency and easier maintenance.
- **MVC Separation**: BrowserViewController (controller) handles browser logic while BrowserView (view) handles pure UI layout.
- **Delegate Handoff**: ServiceManager manages initial load with sequential queue, then hands navigation control to BrowserViewController for ongoing interaction.
- **JavaScript Isolation**: All JavaScript code is centralized in JavaScriptProvider, making it easier to maintain and test complex browser automation scripts.

**Documentation Structure**

The project documentation is organized as follows:

- **Documentation/**: Core project documentation.
  - `architecture-map.md` (this file) - System overview and component relationships.
  - `Testing.md` - Testing strategy and automated test suite details.
  - `README_LOGGING.md` - Logging configuration and usage.
  - `Hyperchat-product-spec.md` - Product requirements and specifications.

- **Documentation/Guides/**: How-to guides for specific technical challenges.
  - `deploy-outside-the-app-store.md` - Deployment and release process documentation.
  - `SPM-Development.md` - Swift Package Manager configuration.
  - ... and other guides for macOS development patterns.

- **Documentation/Websites/**: Browser automation guides and service-specific notes.
  - `browser-automation-guide.md` - General browser automation patterns and best practices.
  - `ChatGPT/`, `Claude/`, `Google/`, `Perplexity/` - Service-specific notes.

- **Documentation/Notes/**: A collection of development notes, logs from debugging sessions, and thoughts on specific features or architectural decisions.

For browser automation work, start with `Documentation/Websites/browser-automation-guide.md` and then refer to the service-specific directories for detailed implementation notes.