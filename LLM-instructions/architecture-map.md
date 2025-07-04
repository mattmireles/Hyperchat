# **Hyperchat Codebase Map**

**High-Level Overview**

Hyperchat is a native macOS application that provides a multi-service interface to various AIs. The user can summon a prompt window via a floating button, enter a query, and see the results across multiple services simultaneously in a unified overlay window. The architecture is event-driven, using NSNotificationCenter for communication between loosely coupled components.

**Core Components & Interaction Flow**

Here is the step-by-step flow of a typical user interaction:

**1. AppDelegate (The Conductor)**

- **Job:** Manages the application lifecycle. On launch, it creates and connects all the primary controller objects.
- **Interaction:**
- Initializes FloatingButtonManager, PromptWindowController, and OverlayController.
- Acts as a central listener for key notifications, delegating tasks to the appropriate controller.

**2. FloatingButtonManager (The Greeter)**

- **Job:** Manages the small, persistent floating button that is always on screen.
- **Interaction:**
- **On Click**: When the user clicks the floating button, it calls promptWindowController.showWindow(...) to display the input field.

**3. PromptWindowController (The Scribe)**

- **Job:** Manages the popup window where the user types their prompt.
- **Interaction:**
- **On Submit**: When the user types a prompt and hits enter, it posts a notification named .showOverlay to the system, packaging the prompt text with it. It then closes itself.

**4. OverlayController (The Stage Manager)**

- **Job:** Manages the main window(s) that host the AI services.
- **Interaction:**
- **Receives Notification**: The AppDelegate catches the .showOverlay notification from the PromptWindowController and calls overlayController.showOverlay(with: prompt).
- **Creates Window**: It creates a new OverlayWindow.
- **Handoff to Logic**: Crucially, it creates a new, dedicated ServiceManager for that window and then calls serviceManager.executePrompt(prompt).

**5. ServiceManager (The Engine)**

- **Job:** This is the core logic unit. It creates and manages the WKWebView for each AI service and executes the prompt.
- **Interaction:**
- **Executes Prompt**: It iterates through its list of active services and tells each one to execute the prompt. The method of execution depends on the service type:
- **URLParameterService (Google, Perplexity, etc.)**: Constructs a URL with the prompt as a query parameter (e.g., google.com/search?q=...) and tells the corresponding WKWebView to load it.
- **ClaudeService (and "Reply to All" mode)**: Navigates to the service's base URL and injects JavaScript to find the chat input, paste the prompt, and programmatically click the "submit" button.

**Key Architectural Patterns**

- **Notification-Based Communication**: Components are loosely coupled. Instead of direct calls, they communicate by posting and observing notifications (e.g., .showOverlay). This makes the system easier to modify.
- **Dedicated ServiceManager per Window**: Each OverlayWindow gets its own ServiceManager. This is a critical design choice for stability, isolating the web environments from each other and preventing crashes in one window from affecting others.
- **Shared WKProcessPool**: While each window has its own ServiceManager, all WKWebViews share a single WKProcessPool. This is a key memory optimization that significantly reduces the app's overall footprint.