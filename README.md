# Hyperchat for  macOS -- All Your AIs. All At Once. 

## Table of Contents

- [High-Level Overview](#high-level-overview)
- [Local LLM Inference Support](#local-llm-inference-support)
- [Core Components & Interaction Flow](#core-components--interaction-flow)
- [Key Architectural Patterns](#key-architectural-patterns)
- [Development Infrastructure](#development-infrastructure)
- [Testing Infrastructure](#testing-infrastructure)
- [Build & Release Management](#build--release-management)
- [Documentation Structure](#documentation-structure)
- [Developer Workflow](#developer-workflow)

## High-Level Overview

Hyperchat is a native macOS application that provides a unified multi-service interface to both web-based and local AI services. Users can summon a prompt window via a floating button, enter a query, and see results across multiple services simultaneously in a unified overlay window. The application supports both web-based services (ChatGPT, Claude, Perplexity, Google) via WKWebView automation and local language models via native inference engines with llama.cpp integration.

The architecture is event-driven, using a combination of NSNotificationCenter for cross-module communication and Combine publishers for direct state updates between related components. The dual-backend architecture allows seamless integration of cloud and local AI services within the same interface.

**Local Inference**: Implemented via static library integration with llama.cpp, using Objective-C bridging headers for maximum performance and minimal complexity. This approach provides native-level performance with simple build configuration.

## Local LLM Inference Support

Hyperchat includes comprehensive support for running local language models directly on the user's machine, providing privacy, offline capability, and full control over AI interactions alongside web-based services.

### Architecture Overview

The local inference system is built around a clean separation of concerns:

- **InferenceEngine Actor**: A thread-safe Swift actor that encapsulates all local inference logic
- **Dual-Backend ServiceManager**: Intelligently routes prompts to either web services or local inference
- **Native UI Integration**: LocalChatView provides a native SwiftUI interface for local model interactions
- **Unified User Experience**: Local and web services appear seamlessly in the same horizontal layout

### Core Components

#### 1. Model Management System

**LocalModel** (`Sources/Hyperchat/LocalModel.swift`):
- **Comprehensive Metadata**: Stores technical names, pretty names, maker information, and hardware requirements
- **Device Compatibility**: Hardware requirements (RAM, storage) for device-specific filtering
- **Download Status Tracking**: Tracks model download progress and installation status
- **Hugging Face Integration**: Direct repository references for model downloading
- **Chat Template Support**: Stores model-specific chat templates and parameters

**ModelManager Actor** (`Sources/Hyperchat/ModelManager.swift`):
- **Thread-Safe Management**: Swift actor for concurrent model operations
- **Manifest-Based Catalog**: Uses `model_manifest.json` for device-specific model whitelisting
- **Device Filtering**: Automatically filters models based on system RAM and storage
- **Download Management**: Handles Hugging Face downloads with progress tracking
- **Model Lifecycle**: Complete model installation, updating, and removal workflows

**Model Manifest** (`Sources/Hyperchat/model_manifest.json`):
- **Device Tiers**: Organizes models by hardware requirements (4GB/8GB/16GB+ RAM)
- **Curated Selection**: 7 high-quality models from Meta, Microsoft, Google, and others
- **Simple Structure**: JSON catalog for easy model addition and maintenance

#### 2. InferenceEngine (`Sources/Hyperchat/InferenceEngine.swift`)

A thread-safe Swift actor that provides the local inference infrastructure:

**InferenceEngine.swift**:
- **Thread-Safe Actor**: Implements Swift's `actor` pattern for safe concurrent access to the inference engine
- **llama.cpp Integration**: Clean Swift wrapper around the llama.cpp C API with proper memory management
- **Streaming Interface**: Returns `AsyncThrowingStream<String, Error>` for real-time token generation
- **Resource Management**: Automatic cleanup of model and context resources via `deinit`
- **Error Handling**: Comprehensive error types for model loading, context creation, and inference failures

**Static Library Integration**:
- **Pre-compiled Libraries**: Uses static `libllama.a` and related libraries built via cmake
- **Objective-C Bridging**: Exposes llama.cpp C API to Swift via `Hyperchat-Bridging-Header.h`
- **System Framework Integration**: Links Accelerate, Metal, and Foundation frameworks for optimal performance

#### 2. ServiceBackend Architecture

**ServiceBackend Enum** (`ServiceConfiguration.swift`):
```swift
public enum ServiceBackend {
    case web(config: ServiceURLConfig)    // Web-based services
    case local(model: LocalModel)         // Local inference with managed model
}
```

This architectural foundation enables:
- **Type Safety**: Compile-time guarantees about service capabilities
- **Unified Configuration**: Both service types managed through the same configuration system
- **Clean Separation**: Web and local services have distinct but parallel implementation paths

#### 3. Native Chat Interface

**LocalChatView** (`Sources/Hyperchat/LocalChatView.swift`):
- **SwiftUI Native**: Pure SwiftUI implementation with no web dependencies
- **Real-Time Streaming**: Handles token streaming from InferenceEngine with live UI updates
- **Message Management**: Chat history with user/assistant message bubbles
- **Error Handling**: Graceful handling of inference failures and model loading errors
- **Accessibility**: Full VoiceOver support and keyboard navigation

**UI Integration** (`OverlayController.swift`):
- **Intelligent Switching**: Automatically displays LocalChatView for `.local` services and WKWebView for `.web` services
- **Consistent Styling**: Local chat views receive the same visual treatment (corner radius, constraints) as web services
- **Layout Parity**: Local services appear in the same horizontal stack as web services
- **Lifecycle Management**: Proper creation, retention, and cleanup of NSHostingController instances

### Usage & Configuration

#### Adding Local Models

**Via Model Management System**:
1. **Add to Manifest**: Edit `model_manifest.json` to include new model:
   ```json
   {
     "models": {
       "my-custom-model": {
         "technical_name": "username/my-model-7b-instruct",
         "pretty_name": "My Custom 7B",
         "maker": "Custom",
         "hugging_face_repo": "username/my-model-7b-instruct-GGUF",
         "model_file_name": "my-model-7b-instruct-q4_k_m.gguf",
         "description": "Custom 7B model for specialized tasks",
         "requirements": {
           "minimum_ram": 8,
           "disk_space_gb": 5,
           "recommends_gpu": true
         },
         "context_size": 4096
       }
     }
   }
   ```

2. **Create Service Configuration**: Update `ServiceManager.swift`:
   ```swift
   // ModelManager will handle model discovery and management
   let availableModels = await modelManager.getAvailableModels()
   let myModel = availableModels.first { $0.id == "my-custom-model" }
   
   AIService(
       id: "local_custom",
       name: "My Custom Model",
       iconName: "brain",
       backend: .local(model: myModel!),
       enabled: true,
       order: 99
   )
   ```

3. **Model Download**: The ModelManager handles automatic downloading from Hugging Face
4. **Model Requirements**: GGUF format models compatible with llama.cpp

#### Performance Characteristics

- **Apple Silicon Optimized**: Metal acceleration for M1/M2/M3 processors
- **Memory Efficient**: Automatic context management with configurable limits
- **Concurrent Safe**: Actor-based design prevents race conditions
- **Resource Cleanup**: Automatic memory cleanup prevents leaks

#### Model Compatibility

The inference engine supports:
- **GGUF Format**: Modern llama.cpp model format
- **Various Architectures**: Llama, Mistral, CodeLlama, and compatible models
- **Quantization Levels**: Q4, Q5, Q8, F16, and other quantization formats
- **Context Sizes**: Configurable context windows up to model limits

### Integration Flow

#### Local Service Execution Path

1. **Model Management**: ModelManager loads available models from manifest and filters by device compatibility
2. **Service Detection**: ServiceManager identifies `.local` backend with LocalModel configuration
3. **Model Validation**: System verifies model is downloaded and ready for inference
4. **UI Creation**: OverlayController creates LocalChatView with LocalModel instead of WKWebView
5. **Engine Initialization**: InferenceEngine loads model from LocalModel's path
6. **User Interaction**: Enhanced SwiftUI interface with model selection and status display
7. **Inference Execution**: Streaming token generation via AsyncThrowingStream
8. **Real-Time Display**: UI updates with each generated token and model information
9. **Message Management**: Enhanced chat history with markdown rendering and model attribution

#### Error Handling & Recovery

- **Model Loading Failures**: Clear error messages for missing or invalid models
- **Memory Issues**: Graceful handling of insufficient memory conditions
- **Inference Errors**: Retry mechanisms and user-friendly error display
- **Path Validation**: File system checks before attempting model loads

### Development & Debugging

#### Local Inference Development

```swift
// Create inference engine
let engine = try InferenceEngine(modelPath: "/path/to/model.gguf")

// Generate streaming response
let stream = await engine.generate(for: "Your prompt here")
for try await token in stream {
    print(token, terminator: "")
}
```

#### Debugging Tools

- **Console Logging**: Comprehensive logging throughout the inference pipeline
- **Error Messages**: Detailed error information for troubleshooting
- **Performance Monitoring**: Token generation speed and memory usage tracking
- **Model Validation**: File existence and format checking

### Future Enhancements

The local inference architecture is designed for extensibility:

- **Multiple Model Support**: Framework supports multiple concurrent local models
- **Advanced Sampling**: Temperature, top-p, and other sampling parameters
- **Fine-Tuning Integration**: Potential for local model fine-tuning workflows
- **Model Management**: Automatic downloading and model library management
- **Performance Optimization**: Batch processing and advanced caching strategies

### Model Management Architecture

The model management system provides a sophisticated yet simple approach to handling local LLMs:

**Three-Component Design** (per CLAUDE.md "SIMPLER IS BETTER" philosophy):
1. **LocalModel.swift**: Pure data structure for model metadata
2. **ModelManager.swift**: Single actor handling all model operations  
3. **model_manifest.json**: Simple JSON catalog with device-specific whitelisting

**Key Design Principles**:
- **Device-Aware Filtering**: Models are automatically filtered based on system RAM and storage
- **Pretty Names for Users**: Technical model names (e.g., "llama-2-7b-chat-gguf") become user-friendly names (e.g., "Llama 2 Chat 7B")
- **Maker Attribution**: Displays model creators (Meta, Microsoft, Google, etc.) with optional logos
- **Hardware Requirements**: Each model specifies minimum RAM/storage for informed selection
- **Download Progress**: Real-time tracking of Hugging Face downloads with status updates

**Model Catalog Structure**:
```json
{
  "models": {
    "llama-3.2-1b": {
      "technical_name": "meta-llama/Llama-3.2-1B-Instruct",
      "pretty_name": "Llama 3.2 1B Instruct",
      "maker": "Meta",
      "hugging_face_repo": "meta-llama/Llama-3.2-1B-Instruct-GGUF",
      "requirements": {
        "minimum_ram": 4,
        "disk_space_gb": 0.8,
        "recommends_gpu": false
      }
    }
  },
  "device_tiers": {
    "low_end": { "max_ram": 8, "recommended_models": ["smollm-1.7b", "llama-3.2-1b"] },
    "mid_range": { "max_ram": 16, "recommended_models": ["llama-3.2-3b", "phi-3.5-mini"] }
  }
}
```

**Integration with Service Architecture**:
- **ServiceBackend.local(model: LocalModel)**: Clean integration with existing dual-backend system
- **Automatic UI Enhancement**: LocalChatView displays model pretty names and status
- **Zero Configuration**: Models become available as services once downloaded
- **Thread-Safe Operations**: ModelManager actor prevents concurrent access issues

This model management system represents a significant architectural achievement, providing users with complete control over their AI interactions while maintaining the unified, seamless experience that defines Hyperchat.

## Core Components & Interaction Flow

Here is the step-by-step flow of a typical user interaction:

### 1. AppDelegate (The Conductor)

- **Job:** Manages the application lifecycle. On launch, it creates and connects all the primary controller objects.
- **Interaction:**
- Initializes FloatingButtonManager, PromptWindowController, and OverlayController.
- Initializes AnalyticsManager for usage tracking (enabled by default, user can disable).
- Acts as a central listener for key notifications, delegating tasks to the appropriate controller.
 - Manages activation policy switching between `.accessory` and `.regular` driven by window events, using `switchToRegularMode()` / `switchToAccessoryMode()`.
 - Builds and refreshes the main menu via `MenuBuilder` (see `Sources/Hyperchat/MenuBuilder.swift`) when in `.regular` mode.

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
- **Creates Service Views**: Uses `ViewProvider` to build the correct UI for each service.
  - `.local` → `NSHostingController(LocalChatView)`
  - `.web` → `BrowserViewController` wrapping the `WKWebView` provided by `ServiceManager`
  - Registers created `BrowserViewController` instances with the `ServiceManager` for navigation handoff
- **Handoff to Logic**: Crucially, it creates a new, dedicated ServiceManager for that window and then calls serviceManager.executePrompt(prompt).
 - **Activation Policy**: When the first window is created, it requests the app switch to `.regular` mode; when the last window closes, it switches back to `.accessory`.

### 5. ServiceManager (The Engine)

- **Job:** Core orchestration unit that manages both web-based and local AI services. Implements dual-backend architecture to seamlessly handle different service types.
- **Interaction:**
- **Service Setup**: 
  - **Web Services**: Uses WebViewFactory to create WKWebViews, manages sequential loading
  - **Local Services**: Currently skipped in setup phase (handled directly by OverlayController)
- **State Updates**: Publishes loading state via Combine (`@Published var areAllServicesLoaded`) and input focus events via `focusInputPublisher`
- **Backend-Aware Execution**: Routes prompts based on ServiceBackend type:
  - **`.web` Services**: Creates URLParameterService or ClaudeService implementations
  - **`.local` Services**: Handled by OverlayController with LocalChatView integration
- **Internals (Post-refactor)**:
  - `Sources/Hyperchat/Services/ServiceRegistry.swift`: Global tracking and lookups (`getAllServiceManagers()`, `findServiceId(for:)`, loading state updates)
  - `Sources/Hyperchat/Services/LoadingQueue.swift`: Sequential loading and default page logic (`loadNextServiceFromQueue`, `loadDefaultPage`)
  - `Sources/Hyperchat/Services/CrashRecovery.swift`: WebView crash handling (`webViewWebContentProcessDidTerminate`)
  - `Sources/Hyperchat/Services/PromptRouter.swift`: Small routing helpers (focus refocus timing)
  - Public API remains the same to the rest of the app
- **Prompt Execution Methods**:
  - **URLParameterService (Google, Perplexity, etc.)**: Constructs URLs with query parameters
  - **ClaudeService**: Uses JavaScriptProvider for clipboard paste automation
  - **Local Services**: Direct integration with InferenceEngine via LocalChatView
- **Delegate Handoff**: After initial load, hands navigation control to BrowserViewController

### 6. WebViewFactory (The Builder)

- **Job:** Centralized factory for creating and configuring WKWebViews with all necessary settings
- **Interaction:**
- **Creates WebViews**: Configures process pools, user agents, content scripts, and message handlers
- **Shared Configuration**: Ensures consistent WebView setup across all services
- **Memory Optimization**: Uses shared WKProcessPool for all WebViews
 
### MenuBuilder (Main Menu Construction)
### ViewProvider (The View Factory)

- **Job:** Centralizes service view creation to keep `OverlayController` lean.
- **Location:** `Sources/Hyperchat/ViewProvider.swift`
- **Interaction:** Given an `AIService` and the window's `ServiceManager`, returns either:
  - `NSHostingController(LocalChatView).view` for `.local` services
  - `BrowserViewController.view` for `.web` services using the pre-created `WKWebView` from `ServiceManager`
  - Applies consistent appearance (corner radius, constraints-ready)


- **Job:** Centralizes all AppKit menu construction.
- **Location:** `Sources/Hyperchat/MenuBuilder.swift`
- **Interaction:** AppDelegate calls `MenuBuilder.createMainMenu(appDelegate:)` when switching to `.regular` mode and refreshes AI Services via `MenuBuilder.createAIServicesMenu(_:)` upon `.servicesUpdated`.

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

### 9. LocalChatView (The Native Interface)

- **Job:** Native SwiftUI interface for local language model interactions
- **Interaction:**
- **Message Management**: Maintains chat history with user/assistant message bubbles
- **Real-Time Streaming**: Handles token streaming from InferenceEngine with live UI updates
- **Direct Integration**: Communicates directly with InferenceEngine actor for inference
- **Error Handling**: Graceful handling of model loading failures and inference errors
- **Native Experience**: Pure SwiftUI implementation with accessibility support

### 10. UI Components (The Toolkit)

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

- **Dual-Backend Architecture**: 
  - **ServiceBackend Enum**: Type-safe separation between `.web` and `.local` services
  - **Unified Configuration**: Both backend types managed through the same AIService configuration system
  - **Intelligent UI Switching**: OverlayController automatically displays WKWebView for web services and LocalChatView for local services
  - **Clean Separation**: Web automation and local inference have distinct but parallel implementation paths
- **Hybrid Communication Model**: 
  - **NSNotificationCenter**: Used for cross-module events where loose coupling is beneficial (e.g., .showOverlay, .overlayDidHide)
  - **Combine Publishers**: Used for direct state updates between tightly related components (e.g., ServiceManager to OverlayController loading states)
- **Dedicated ServiceManager per Window**: Each OverlayWindow gets its own ServiceManager. This is a critical design choice for stability, isolating the web environments from each other and preventing crashes in one window from affecting others.
- **Shared WKProcessPool**: While each window has its own ServiceManager, all WKWebViews share a single WKProcessPool. This is a key memory optimization that significantly reduces the app's overall footprint.
- **Actor-Based Concurrency**: InferenceEngine uses Swift's actor pattern for thread-safe local model access
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

- **`sync-sparkle-keys.sh`**: Sparkle update key management that synchronizes EdDSA public keys in Info.plist with private keys to prevent signature mismatches.

- **`menu-test.sh`**: Quick menu functionality testing for debugging menu bar interactions and accessibility settings.

- **`swift-test.sh`**: Swift testing utilities for targeted test execution and debugging workflows.

- **`cleanup-tests.sh`**: Cleans test artifacts and temporary files to maintain a clean development environment.

### Package Management (`Package.swift`)

The project uses Swift Package Manager with key dependencies:

- **Sparkle** (2.6.0+): Automatic update framework for macOS applications
- **AmplitudeSwift** (1.0.0+): Analytics and usage tracking
- **Test Targets**: Separate test targets for unit tests (`HyperchatTests`) and UI tests (`HyperchatUITests`)

#### Local Inference Integration

- **Static Library Integration** (`llama.cpp/build/`):
  - **Pre-compiled Libraries**: Built via cmake with `libllama.a`, `libggml*.a` and backend libraries
  - **Objective-C Bridging**: `Hyperchat-Bridging-Header.h` exposes C API to Swift
  - **InferenceEngine Actor**: Swift implementation for thread-safe local model inference (`Sources/Hyperchat/InferenceEngine.swift`)
  - **Metal Acceleration**: Optimized for Apple Silicon with GPU acceleration
  - **System Framework Integration**: Links Accelerate, Metal, and Foundation frameworks

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

- **Developer ID Signing**: Uses specific certificate identity (configured via APPLE_CERTIFICATE_IDENTITY environment variable) for direct distribution outside the Mac App Store
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

- **`README.md`** (this file): Complete system overview covering runtime architecture, development infrastructure, testing, and build processes
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

1. **New Developers**: Start with this `README.md` for system overview
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
./Scripts/menu-test.sh
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
# Full deployment pipeline (build, sign, notarize, create DMG)
./Scripts/deploy-hyperchat.sh

# Sync Sparkle keys (run automatically during build)
./Scripts/sync-sparkle-keys.sh

# Swift testing utilities
./Scripts/swift-test.sh
```

### Debugging & Development

```bash
# Clean test artifacts and derived data
./Scripts/cleanup-tests.sh

# Build for testing (without running tests)
xcodebuild build-for-testing -scheme Hyperchat -destination 'platform=macOS'

# Run app in debug mode from command line
# (Build in Xcode first, then locate in Export/ directory)
./Export/Hyperchat.app/Contents/MacOS/Hyperchat
```

### Model Management Development

```bash
# Build llama.cpp libraries (if not already built)
cd llama.cpp && cmake -B build && cmake --build build

# Test model management system
# 1. Review model_manifest.json for available models
# 2. Update manifest with desired models for your device tier
# 3. Build and run the application
xcodebuild build -scheme Hyperchat -destination 'platform=macOS'

# Test model downloading (in Swift)
let modelManager = ModelManager()
let models = await modelManager.getAvailableModels()
let model = models.first { $0.id == "desired-model-id" }
if let model = model {
    try await modelManager.downloadModel(id: model.id)
}
```

#### Model Setup
1. **Review Manifest**: Check `model_manifest.json` for pre-configured models
2. **Add Custom Models**: Edit manifest to include additional models
3. **Device Compatibility**: Ensure models match your system's RAM/storage requirements
4. **Test Download**: Use ModelManager to download and install models
5. **Service Configuration**: Models are automatically available once downloaded

#### Local Inference Debugging
- **Model Loading**: Check console for InferenceEngine initialization messages
- **Memory Usage**: Monitor memory consumption during inference
- **Performance**: Track token generation speed and inference latency
- **Error Handling**: Test with invalid model paths and formats

### Configuration Management

1. **Set up Config.swift**: Copy `Config.swift.template` to `Config.swift` and add API keys
2. **Development vs Release**: Use appropriate entitlements file for target environment
3. **Sparkle Setup**: Ensure private key exists at `~/.keys/sparkle_ed_private_key.pem`
4. **Local Models**: Configure GGUF model paths for local inference services

### Common Troubleshooting

- **Build Failures**: Check `deploy-debug.log` for detailed build output
- **Test Failures**: Review `TestResults/*.log` files and Xcode test navigator
- **WebView Issues**: Enable WebViewLogger and check console output
- **Menu Problems**: Use menu debugging scripts and check accessibility settings
- **Signing Issues**: Verify certificate identity and provisioning profiles
- **Model Management Issues**:
  - Check `model_manifest.json` syntax and model entries
  - Verify ModelManager can load manifest from bundle resources
  - Check console for model download progress and errors
  - Verify Hugging Face repository URLs are accessible
  - Monitor storage space for model downloads
- **Local Inference Issues**: 
  - Check model download completed successfully via ModelManager status
  - Verify GGUF format compatibility with llama.cpp version
  - Monitor memory usage (models can require 4-16GB RAM)
  - Check console for InferenceEngine error messages
  - Verify llama.cpp build completed successfully
  - Check bridging header includes correct llama.h path
  - Ensure LocalModel.isReady returns true before inference

### Performance Optimization

- **Clean Builds**: Remove `DerivedData/` directory for fresh compilation
- **Test Performance**: Use `--no-cleanup` flag to inspect test artifacts
- **Memory Issues**: Monitor WebView process pool usage in Activity Monitor
- **JavaScript Debugging**: Use Safari Web Inspector with WebView content

For browser automation work, start with `Documentation/Websites/browser-automation-guide.md` and then refer to the service-specific directories for detailed implementation notes.