# Hyperchat Architecture Map

## Table of Contents

- [High-Level Overview](#high-level-overview)
- [Core Components & Interaction Flow](#core-components--interaction-flow)
- [Key Architectural Patterns](#key-architectural-patterns)
- [Development Infrastructure](#development-infrastructure)
- [Testing Infrastructure](#testing-infrastructure)
- [Build & Release Management](#build--release-management)
- [Documentation Structure](#documentation-structure)
- [Developer Workflow](#developer-workflow)

## High-Level Overview

Hyperchat is a native macOS application that provides a multi-service interface to various AIs. The user can summon a prompt window via a floating button, enter a query, and see the results across multiple services simultaneously in a unified overlay window. The architecture is event-driven, using a combination of NSNotificationCenter for cross-module communication and Combine publishers for direct state updates between related components.

## Core Components & Interaction Flow

Here is the step-by-step flow of a typical user interaction:

### 1. AppDelegate (The Conductor)

- **Job:** Manages the application lifecycle. On launch, it creates and connects all the primary controller objects.
- **Interaction:**
- Initializes FloatingButtonManager, PromptWindowController, and OverlayController.
- Initializes AnalyticsManager for usage tracking (enabled by default, user can disable).
- Acts as a central listener for key notifications, delegating tasks to the appropriate controller.

### 2. FloatingButtonManager (The Greeter)

- **Job:** Manages the small, persistent floating button that is always on screen.
- **Interaction:**
- **On Click**: When the user clicks the floating button, it calls promptWindowController.showWindow(...) to display the input field.

### 3. PromptWindowController (The Scribe)

- **Job:** Manages the popup window where the user types their prompt.
- **Interaction:**
- **On Submit**: When the user types a prompt and hits enter, it posts a notification named .showOverlay to the system, packaging the prompt text with it. It then closes itself.

### 4. OverlayController (The Stage Manager)

- **Job:** Manages the main window(s) that host the AI services.
- **Interaction:**
- **Receives Notification**: The AppDelegate catches the .showOverlay notification from the PromptWindowController and calls overlayController.showOverlay(with: prompt).
- **Creates Window**: It creates a new OverlayWindow.
- **Creates Controllers**: For each service, it creates a BrowserViewController and registers it with the ServiceManager.
- **Handoff to Logic**: Crucially, it creates a new, dedicated ServiceManager for that window and then calls serviceManager.executePrompt(prompt).

### 5. ServiceManager (The Engine)

- **Job:** Core orchestration unit that manages AI services and executes prompts. Refactored to focus solely on service management (reduced from 1600+ to under 900 lines).
- **Interaction:**
- **Service Setup**: Uses WebViewFactory to create WKWebViews, manages sequential loading of services
- **State Updates**: Publishes loading state via Combine (`@Published var areAllServicesLoaded`) and input focus events via `focusInputPublisher`
- **Executes Prompt**: It iterates through its list of active services and tells each one to execute the prompt. The method of execution depends on the service type:
- **URLParameterService (Google, Perplexity, etc.)**: Constructs a URL with the prompt as a query parameter (e.g., google.com/search?q=...) and tells the corresponding WKWebView to load it.
- **ClaudeService (and "Reply to All" mode)**: Navigates to the service's base URL and uses JavaScriptProvider to inject scripts that find the chat input, paste the prompt, and programmatically click the "submit" button.
- **Delegate Handoff**: After initial load, hands navigation control to BrowserViewController

### 6. WebViewFactory (The Builder)

- **Job:** Centralized factory for creating and configuring WKWebViews with all necessary settings
- **Interaction:**
- **Creates WebViews**: Configures process pools, user agents, content scripts, and message handlers
- **Shared Configuration**: Ensures consistent WebView setup across all services
- **Memory Optimization**: Uses shared WKProcessPool for all WebViews

### 7. BrowserViewController (The Navigator)

- **Job:** MVC controller that manages browser logic, navigation, and user interactions
- **Interaction:**
- **Navigation Management**: Takes over as WKNavigationDelegate after initial service load
- **UI Updates**: Manages URL display, back/forward buttons, and loading states
- **User Actions**: Handles reload, URL entry, and clipboard operations

### 8. BrowserView (The Canvas)

- **Job:** Pure view component that layouts browser UI elements
- **Interaction:**
- **Layout Only**: Manages visual arrangement of WebView, toolbar, and URL field
- **No Logic**: Delegates all actions to BrowserViewController

### 9. UI Components (The Toolkit)

- **ButtonState**: Observable state model for toolbar buttons
- **GradientToolbarButton**: SwiftUI component for animated toolbar buttons

### 10. JavaScriptProvider (The Script Library)

- **Job:** Centralized repository for all JavaScript code used throughout the application
- **Interaction:**
- **Script Generation**: Provides static methods that return JavaScript strings for various operations
- **Clean Separation**: Isolates 300+ lines of JavaScript from ServiceManager into organized, reusable methods
- **Key Scripts**: Paste automation, Claude-specific interactions, window hibernation pause/resume

### 11. AnalyticsManager (The Data Collector)

- **Job:** Centralized analytics service using Amplitude for usage tracking and product improvement
- **Interaction:**
- **Event Tracking**: Collects usage data on prompt submissions, button clicks, and webview interactions
- **Privacy-Focused**: No PII collected, only usage patterns and feature adoption metrics
- **Source Attribution**: Tracks whether prompts come from floating button vs direct window access
- **Service Usage**: Monitors which AI services users interact with most frequently
- **Configuration**: Loads API keys from Config.swift (excluded from version control)

## Key Architectural Patterns

- **Hybrid Communication Model**: 
  - **NSNotificationCenter**: Used for cross-module events where loose coupling is beneficial (e.g., .showOverlay, .overlayDidHide)
  - **Combine Publishers**: Used for direct state updates between tightly related components (e.g., ServiceManager to OverlayController loading states)
- **Dedicated ServiceManager per Window**: Each OverlayWindow gets its own ServiceManager. This is a critical design choice for stability, isolating the web environments from each other and preventing crashes in one window from affecting others.
- **Shared WKProcessPool**: While each window has its own ServiceManager, all WKWebViews share a single WKProcessPool. This is a key memory optimization that significantly reduces the app's overall footprint.
- **Factory Pattern**: WebViewFactory centralizes all WKWebView configuration, ensuring consistency and easier maintenance.
- **MVC Separation**: BrowserViewController (controller) handles browser logic while BrowserView (view) handles pure UI layout.
- **Delegate Handoff**: ServiceManager manages initial load with sequential queue, then hands navigation control to BrowserViewController for ongoing interaction.
- **JavaScript Isolation**: All JavaScript code is centralized in JavaScriptProvider, making it easier to maintain and test complex browser automation scripts.

## Development Infrastructure

The project includes comprehensive automation and tooling for development, testing, and deployment:

### Scripts Directory (`Scripts/`)

The automation scripts handle the entire development lifecycle:

- **`deploy-hyperchat.sh`**: Complete deployment pipeline that builds, signs, notarizes, and creates DMG packages for distribution. Handles version bumping, Apple notarization workflow, and Sparkle update generation.

- **`run-tests.sh`**: Comprehensive test runner that executes both unit and UI tests, generates reports, and provides cleanup options. Supports selective test execution and HTML report generation.

- **`configure-release-build.sh`**: Release build automation that manages version bumping, archive creation, and export configuration for App Store and direct distribution.

- **`sync-sparkle-keys.sh`**: Sparkle update key management that synchronizes EdDSA public keys in Info.plist with private keys to prevent signature mismatches.

- **Testing Scripts**: Various utilities including `quick-menu-test.sh`, `test-clean.sh`, `test-settings.sh` for targeted testing and debugging workflows.

- **`cleanup-tests.sh`**: Cleans test artifacts and temporary files to maintain a clean development environment.

### Package Management (`Package.swift`)

The project uses Swift Package Manager with key dependencies:

- **Sparkle** (2.6.0+): Automatic update framework for macOS applications
- **AmplitudeSwift** (1.0.0+): Analytics and usage tracking
- **Test Targets**: Separate test targets for unit tests (`HyperchatTests`) and UI tests (`HyperchatUITests`)

### Build System Integration

- **Xcode Project**: Traditional Xcode project structure with SPM integration
- **Build Configurations**: Separate debug and release configurations with different entitlements
- **Code Signing**: Automated signing with Developer ID for direct distribution
- **Notarization**: Integrated Apple notarization workflow for security compliance

## Testing Infrastructure

The project maintains comprehensive test coverage with a dual test structure and automated CI workflows:

### Test Organization

- **Dual Test Structure**: Tests exist in both legacy (`HyperchatTests/`, `HyperchatUITests/`) and modern (`Tests/HyperchatTests/`, `Tests/HyperchatUITests/`) directory structures for backward compatibility and migration flexibility.

- **Test Types**:
  - **Unit Tests** (`HyperchatTests`): Core business logic testing including service configuration, AI service management, and component integration
  - **UI Tests** (`HyperchatUITests`): End-to-end user interaction testing including window management, prompt submission, and cross-service functionality
  - **Menu Tests** (`MenuUnitTests`, `MenuUITests`): Specialized testing for menu bar interactions and settings

### Key Test Components

- **`ServiceConfigurationTests`**: Validates AI service URL generation, parameter encoding, and configuration management
- **`AIServiceTests`**: Tests service activation, ordering, icon management, and default configurations  
- **`ServiceManagerTests`**: Core orchestration testing including service loading, WebView lifecycle, state management, and service reordering
- **`WebViewMocks`**: Mock objects that simulate WKWebView behavior without actual web content, enabling fast and reliable unit testing
- **`MenuUnitTests`**: Tests menu bar integration, settings synchronization, and user preferences

### Test Execution Workflows

- **Local Development**: `Scripts/run-tests.sh` provides comprehensive test execution with reporting, cleanup options, and HTML output generation
- **Continuous Integration**: Automated test execution on GitHub Actions for all pull requests and main branch commits
- **Selective Testing**: Support for running specific test suites, classes, or individual test methods
- **Test Artifacts**: Automatic generation of test reports, coverage data, and failure diagnostics

### Testing Best Practices

- **Mock-First Testing**: Heavy use of mock objects to isolate business logic from WebKit dependencies
- **Accessibility Integration**: UI tests leverage accessibility identifiers for reliable element targeting
- **Parallel Test Execution**: Tests designed to run in parallel without state conflicts
- **Coverage Reporting**: Integrated code coverage tracking with detailed reports in Xcode and CI

## Build & Release Management

The project uses a sophisticated build and release pipeline designed for both development and production distribution:

### Build Artifacts & Structure

- **`DerivedData/`**: Xcode build artifacts including compiled binaries, module caches, and intermediate build files. Contains Swift module compilation cache for faster incremental builds.

- **`Export/`**: Distribution-ready builds including signed applications and DMG packages. Houses final release artifacts ready for distribution.

- **`Hyperchat.xcarchive/`**: Xcode archive bundles containing signed applications with debug symbols (dSYMs) for crash analysis and debugging.

### Code Signing & Distribution

- **Developer ID Signing**: Uses specific certificate identity (***REMOVED-CERTIFICATE***) for direct distribution outside the Mac App Store
- **Entitlements Management**: Separate entitlement files for debug (`Hyperchat.entitlements`) and release (`Hyperchat.Release.entitlements`) builds
- **Notarization Pipeline**: Automated submission to Apple's notary service with ticket stapling for security compliance

### Release Automation Workflow

1. **Version Management**: Automatic build number incrementation and version tagging
2. **Archive Creation**: Xcode archive generation with release configuration and optimizations
3. **Export & Signing**: Application export from archive with Developer ID signing
4. **Notarization**: Automated submission to Apple notary service with status monitoring
5. **DMG Creation**: Packaging into distributable disk images with custom layouts
6. **Sparkle Integration**: Generation of update manifests and signature files for automatic updates
7. **Distribution**: Upload to servers and update feed publication

### Configuration Management

- **`Info.plist`**: Application metadata, bundle identifiers, version information, and system capabilities
- **`Config.swift.template`**: Template for sensitive configuration including API keys and service endpoints
- **Environment-Specific Builds**: Different configurations for development, staging, and production environments
- **Asset Management**: Icon sets, fonts (Orbitron-Bold.ttf), and other bundled resources

### Continuous Deployment

- **GitHub Actions Integration**: Automated build and release workflows triggered by version tags
- **Artifact Generation**: Automatic creation of release packages, debug symbols, and distribution manifests
- **Quality Gates**: Build and test execution before release artifact generation
- **Release Notes Integration**: Automatic generation from RELEASE_NOTES.html for update notifications

## Documentation Structure

The project maintains comprehensive documentation organized by purpose and audience:

### Core Documentation (`Documentation/`)

- **`architecture-map.md`** (this file): Complete system overview covering runtime architecture, development infrastructure, testing, and build processes
- **`Testing.md`**: Detailed testing guide with execution instructions, test organization, and best practices
- **`README_LOGGING.md`**: Logging configuration, debug output management, and troubleshooting workflows
- **`Hyperchat-product-spec.md`**: Product requirements, feature specifications, and design decisions

### Development Guides (`Documentation/Guides/`)

Practical guides for specific development challenges:

- **`deploy-outside-the-app-store.md`**: Complete deployment process for direct distribution, notarization, and DMG creation
- **`SPM-Development.md`**: Swift Package Manager integration, dependency management, and build configuration
- **`Sparkle-guide.md`**: Automatic update system integration and configuration
- **`macos-window-management.md`**: Window management patterns and space awareness
- **`dual-mode-macos-apps.md`**: Architecture patterns for LSUIElement applications
- **`WKWebView-Overlay-Alignment-Debug.md`**: WebView debugging and layout troubleshooting
- **Additional specialized guides** for menu debugging, accessory switching, and macOS development patterns

### Browser Automation Documentation (`Documentation/Websites/`)

Service-specific automation guides and implementation notes:

- **`browser-automation-guide.md`**: General patterns, timing considerations, and JavaScript injection strategies
- **`ChatGPT/ChatGPT-notes.md`**: OpenAI-specific automation patterns and DOM interaction strategies
- **`Claude/`**: 
  - `claude-notes.md`: Claude.ai automation patterns and React component interaction
  - `ProseMirror-React-Nextjs-automation-guide.md`: Detailed guide for Claude's ProseMirror editor integration
  - `claude-raw-source-code.html`: Reference implementation for complex automation scenarios
- **`Google/Google-notes.md`**: Google Search automation and result parsing
- **`Perplexity/Perplexity-notes.md`**: Perplexity-specific automation patterns and content div interactions

### Development Notes (`Documentation/Notes/`)

Historical context and debugging documentation:

- **Debugging Logs**: `Debugging-EXC_BAD_ACCESS-WKWebView-Crashes.md`, `webview-loading-issues.md`
- **Architecture Evolution**: `LSUIElement-Architecture-Fix-Log.md`, `Space-Aware-Floating-Button.md`
- **Feature Implementation**: `AI-services-menu-dropdown-sync.md`, `WebViewLogger-Usage.md`
- **Service Integration**: Notes on Sparkle updates, analytics integration, and service-specific challenges

### Documentation Philosophy

The documentation follows an **LLM-First approach** where every comment and document is written to provide maximum context for AI-assisted development. This includes:

- **Explicit Cross-References**: Clear connections between related files and components
- **Context-Rich Comments**: Detailed explanations of why decisions were made, not just what they do
- **Comprehensive Examples**: Real implementation examples with detailed explanations
- **Historical Context**: Documentation of failed approaches and lessons learned

### Getting Started Workflow

1. **New Developers**: Start with this `architecture-map.md` for system overview
2. **Browser Automation**: Begin with `Documentation/Websites/browser-automation-guide.md`
3. **Testing**: Use `Documentation/Testing.md` for test execution and development
4. **Deployment**: Follow `Documentation/Guides/deploy-outside-the-app-store.md` for release processes

## Developer Workflow

Common development tasks and their execution methods:

### Daily Development

```bash
# Run all tests
./Scripts/run-tests.sh

# Run specific test suite
./Scripts/run-tests.sh --no-cleanup  # Keep artifacts for inspection
xcodebuild test -scheme Hyperchat -only-testing:HyperchatTests

# Clean build artifacts
./Scripts/cleanup-tests.sh

# Quick menu functionality test
./Scripts/quick-menu-test.sh
```

### Testing & Quality Assurance

```bash
# Run unit tests only
xcodebuild test -scheme Hyperchat -only-testing:HyperchatTests

# Run UI tests only  
xcodebuild test -scheme Hyperchat -only-testing:HyperchatUITests

# Generate test coverage report
# Run tests with Cmd+U in Xcode, then check Report Navigator

# Run specific test class
xcodebuild test -scheme Hyperchat -only-testing:HyperchatTests/ServiceConfigurationTests
```

### Build & Release Process

```bash
# Configure release build with version bumping
./Scripts/configure-release-build.sh "1.2.3"

# Full deployment pipeline (build, sign, notarize, create DMG)
./Scripts/deploy-hyperchat.sh

# Sync Sparkle keys (run automatically during build)
./Scripts/sync-sparkle-keys.sh

# Test settings and configuration
./Scripts/test-settings.sh
```

### Debugging & Development

```bash
# Clean test artifacts and derived data
./Scripts/test-clean.sh

# Build for testing (without running tests)
xcodebuild build-for-testing -scheme Hyperchat -destination 'platform=macOS'

# Run app in debug mode from command line
# (Build in Xcode first, then locate in Export/ directory)
./Export/Hyperchat.app/Contents/MacOS/Hyperchat
```

### Configuration Management

1. **Set up Config.swift**: Copy `Config.swift.template` to `Config.swift` and add API keys
2. **Development vs Release**: Use appropriate entitlements file for target environment
3. **Sparkle Setup**: Ensure private key exists at `~/.keys/sparkle_ed_private_key.pem`

### Common Troubleshooting

- **Build Failures**: Check `deploy-debug.log` for detailed build output
- **Test Failures**: Review `TestResults/*.log` files and Xcode test navigator
- **WebView Issues**: Enable WebViewLogger and check console output
- **Menu Problems**: Use menu debugging scripts and check accessibility settings
- **Signing Issues**: Verify certificate identity and provisioning profiles

### Performance Optimization

- **Clean Builds**: Remove `DerivedData/` directory for fresh compilation
- **Test Performance**: Use `--no-cleanup` flag to inspect test artifacts
- **Memory Issues**: Monitor WebView process pool usage in Activity Monitor
- **JavaScript Debugging**: Use Safari Web Inspector with WebView content

For browser automation work, start with `Documentation/Websites/browser-automation-guide.md` and then refer to the service-specific directories for detailed implementation notes.
