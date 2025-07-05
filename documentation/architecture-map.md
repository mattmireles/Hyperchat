# **Hyperchat Codebase Map**

**High-Level Overview**

Hyperchat is a native macOS application that provides a multi-service interface to various AIs. The user can summon a prompt window via a floating button, enter a query, and see the results across multiple services simultaneously in a unified overlay window. The architecture is event-driven, using NSNotificationCenter for communication between loosely coupled components.

**Recent Refactoring (July 2025)**

The codebase underwent a significant refactoring to break down the ServiceManager god object (previously 1600+ lines) into focused, single-responsibility components. This improved maintainability, testability, and follows proper MVC patterns.

**Core Components & Interaction Flow**

Here is the step-by-step flow of a typical user interaction:

**1. AppDelegate (The Conductor)**

- **Job:** Manages the application lifecycle. On launch, it creates and connects all the primary controller objects.
- **Interaction:**
- Initializes FloatingButtonManager, PromptWindowController, and OverlayController.
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
- **Executes Prompt**: It iterates through its list of active services and tells each one to execute the prompt. The method of execution depends on the service type:
- **URLParameterService (Google, Perplexity, etc.)**: Constructs a URL with the prompt as a query parameter (e.g., google.com/search?q=...) and tells the corresponding WKWebView to load it.
- **ClaudeService (and "Reply to All" mode)**: Navigates to the service's base URL and injects JavaScript to find the chat input, paste the prompt, and programmatically click the "submit" button.
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

**Key Architectural Patterns**

- **Notification-Based Communication**: Components are loosely coupled. Instead of direct calls, they communicate by posting and observing notifications (e.g., .showOverlay). This makes the system easier to modify.
- **Dedicated ServiceManager per Window**: Each OverlayWindow gets its own ServiceManager. This is a critical design choice for stability, isolating the web environments from each other and preventing crashes in one window from affecting others.
- **Shared WKProcessPool**: While each window has its own ServiceManager, all WKWebViews share a single WKProcessPool. This is a key memory optimization that significantly reduces the app's overall footprint.
- **Factory Pattern**: WebViewFactory centralizes all WKWebView configuration, ensuring consistency and easier maintenance.
- **MVC Separation**: BrowserViewController (controller) handles browser logic while BrowserView (view) handles pure UI layout.
- **Delegate Handoff**: ServiceManager manages initial load with sequential queue, then hands navigation control to BrowserViewController for ongoing interaction.

**Core Technologies & Practices**

- **Dependency Management**: The project uses Swift Package Manager (SPM) to manage third-party libraries like Sparkle and KeyboardShortcuts.
- **Automated Testing**: A suite of unit and UI tests runs automatically via GitHub Actions to ensure stability. The testing strategy is detailed in `Testing.md`.
- **Automated Deployment**: The release process is fully automated via the `./deploy-hyperchat.sh` script, which handles signing, notarization, and DMG creation.
- **Direct Distribution (Not Sandboxed)**: Hyperchat is distributed directly and is not sandboxed. This simplifies development and enables more powerful system-level features.
- **Automatic Updates (Sparkle)**: The Sparkle framework is integrated to provide seamless, automatic updates to users.