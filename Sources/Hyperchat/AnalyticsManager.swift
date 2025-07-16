/// AnalyticsManager.swift - Amplitude Analytics Integration
///
/// This file manages analytics collection for Hyperchat using Amplitude.
/// It tracks user interactions to understand usage patterns and feature adoption.
///
/// Key responsibilities:
/// - Track prompt submissions with source attribution
/// - Monitor webview interactions and link clicks
/// - Respect user privacy preferences
/// - Batch events efficiently for performance
///
/// Related files:
/// - `SettingsManager.swift`: Manages analytics preferences
/// - `FloatingButtonManager.swift`: Reports floating button interactions
/// - `ServiceManager.swift`: Reports prompt submissions
/// - `BrowserViewController.swift`: Reports webview interactions
///
/// Privacy:
/// - Analytics enabled by default to help improve the product
/// - No personally identifiable information collected
/// - User can disable analytics at any time via settings

import Foundation
import AmplitudeSwift

/// Defines the source of a prompt submission for analytics attribution.
enum PromptSource: String, CaseIterable {
    /// Prompt was submitted via the floating button workflow
    case floatingButton = "floating_button"
    
    /// Prompt was submitted by directly navigating to the window
    case directWindow = "direct_window"
}

/// Defines prompt submission modes for analytics tracking.
enum SubmissionMode: String, CaseIterable {
    /// Creating new chat threads via URL navigation
    case newChat = "new_chat"
    
    /// Replying to existing chats via clipboard paste
    case replyToAll = "reply_to_all"
}

/// Centralized analytics service using Amplitude for usage tracking.
///
/// Created by:
/// - `AppDelegate` during application startup
///
/// Used by:
/// - `FloatingButtonManager` to track button clicks
/// - `ServiceManager` to track prompt submissions  
/// - `BrowserViewController` to track webview interactions
///
/// Privacy design:
/// - Enabled by default to help improve the product
/// - Respects user preferences throughout app lifecycle
/// - No PII collected, only usage patterns and feature adoption
/// - User can disable at any time via Settings
class AnalyticsManager {
    /// Shared instance following app singleton patterns
    static let shared = AnalyticsManager()
    
    /// Amplitude SDK instance for event tracking
    private var amplitude: Amplitude?
    
    /// Whether analytics is currently enabled (respects user preference)
    private var isEnabled: Bool {
        return SettingsManager.shared.isAnalyticsEnabled
    }
    
    /// Current prompt source context for attribution
    /// Set by FloatingButtonManager, used by ServiceManager
    private var currentPromptSource: PromptSource = .directWindow
    
    /// Amplitude API key for Hyperchat project
    /// Loaded from Config.swift to keep sensitive keys out of version control
    private let amplitudeAPIKey = Config.amplitudeAPIKey
    
    private init() {
        setupNotificationObservers()
    }
    
    /// Initializes Amplitude SDK if analytics is enabled.
    ///
    /// Called by:
    /// - `AppDelegate.applicationDidFinishLaunching()`
    /// - When user enables analytics in settings
    ///
    /// Configuration:
    /// - Uses bundle identifier for user identification
    /// - Enables offline storage for reliable event delivery
    /// - Sets up error handling and logging
    func initialize() {
        guard isEnabled else {
            print("📊 AnalyticsManager: Analytics disabled by user preference")
            return
        }
        
        guard amplitudeAPIKey != "YOUR_AMPLITUDE_API_KEY_HERE" else {
            print("⚠️ AnalyticsManager: No valid API key configured")
            return
        }
        
        let config = Configuration(
            apiKey: amplitudeAPIKey,
            enableCoppaControl: false,
            autocapture: AutocaptureOptions()
        )
        
        amplitude = Amplitude(configuration: config)
        
        // Set user properties for context
        setUserProperties()
        
        print("✅ AnalyticsManager: Initialized with analytics enabled")
    }
    
    /// Sets up notification observers for settings changes.
    ///
    /// Called during initialization to:
    /// - Respond to analytics preference changes
    /// - Initialize/shutdown Amplitude when preference changes
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(analyticsPreferenceChanged),
            name: .analyticsPreferenceChanged,
            object: nil
        )
    }
    
    /// Handles analytics preference changes from settings.
    ///
    /// Called when:
    /// - User toggles analytics in Settings window
    ///
    /// Actions:
    /// - Initializes Amplitude if newly enabled
    /// - Shuts down tracking if disabled
    @objc private func analyticsPreferenceChanged() {
        if isEnabled {
            initialize()
        } else {
            shutdown()
        }
    }
    
    /// Shuts down analytics tracking and clears stored data.
    ///
    /// Called when:
    /// - User disables analytics in settings
    /// - App is terminating
    ///
    /// Ensures:
    /// - No further events are tracked
    /// - User privacy is respected
    private func shutdown() {
        amplitude = nil
        print("📊 AnalyticsManager: Analytics disabled and shut down")
    }
    
    /// Sets user properties for analytics context.
    ///
    /// Properties tracked:
    /// - App version for feature adoption analysis
    /// - macOS version for compatibility insights
    /// - Enabled AI services for usage patterns
    ///
    /// No personally identifiable information is collected.
    private func setUserProperties() {
        guard let amplitude = amplitude else { return }
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let enabledServices = SettingsManager.shared.getServices()
            .filter { $0.enabled }
            .map { $0.id }
        
        let identify = Identify()
        identify.set(property: "app_version", value: appVersion)
        identify.set(property: "os_version", value: osVersion)
        identify.set(property: "enabled_services", value: enabledServices)
        identify.set(property: "services_count", value: enabledServices.count)
        
        amplitude.identify(identify: identify)
    }
    
    // MARK: - Event Tracking Methods
    
    /// Sets the current prompt source for subsequent prompt submissions.
    ///
    /// Called by:
    /// - `FloatingButtonManager.floatingButtonClicked()` to set floating button source
    /// - Reset to direct window after prompt submission
    ///
    /// This enables proper attribution of prompt submissions to their trigger source.
    func setPromptSource(_ source: PromptSource) {
        currentPromptSource = source
        print("📊 AnalyticsManager: Prompt source set to \(source.rawValue)")
    }
    
    /// Tracks floating button click events.
    ///
    /// Called by:
    /// - `FloatingButtonManager.floatingButtonClicked()`
    ///
    /// Provides insights into:
    /// - Floating button usage frequency
    /// - User preference for floating button vs direct access
    func trackFloatingButtonClicked() {
        trackEvent("floating_button_clicked", properties: [:])
    }
    
    /// Tracks prompt submission events with comprehensive metadata.
    ///
    /// Called by:
    /// - `ServiceManager.executePrompt()` for all prompt submissions
    ///
    /// Properties tracked:
    /// - source: How the prompt was triggered (floating_button, direct_window)
    /// - services_count: Number of AI services the prompt was sent to
    /// - prompt_length: Character count of the prompt (for usage analysis)
    /// - submission_mode: new_chat vs reply_to_all mode
    /// - services_used: Array of AI service IDs that received the prompt
    ///
    /// - Parameters:
    ///   - servicesCount: Number of services the prompt was sent to
    ///   - promptLength: Character count of the prompt text
    ///   - submissionMode: Whether creating new chats or replying to existing
    ///   - servicesUsed: Array of service IDs that received the prompt
    func trackPromptSubmitted(
        servicesCount: Int,
        promptLength: Int,
        submissionMode: SubmissionMode,
        servicesUsed: [String]
    ) {
        let properties: [String: Any] = [
            "source": currentPromptSource.rawValue,
            "services_count": servicesCount,
            "prompt_length": promptLength,
            "submission_mode": submissionMode.rawValue,
            "services_used": servicesUsed
        ]
        
        trackEvent("prompt_submitted", properties: properties)
        
        // Reset source to direct window after submission
        currentPromptSource = .directWindow
    }
    
    /// Tracks webview link click events.
    ///
    /// Called by:
    /// - `BrowserViewController.decidePolicyFor()` when external links are clicked
    ///
    /// Properties tracked:
    /// - service: Which AI service the link was clicked in
    /// - destination_domain: Domain of the external link (for safety analysis)
    /// - is_external: Whether the link was opened externally vs navigated internally
    ///
    /// Provides insights into:
    /// - Which services generate the most external link clicks
    /// - Common external domains users visit from AI services
    /// - User interaction patterns within different AI services
    ///
    /// - Parameters:
    ///   - service: AI service ID where the link was clicked
    ///   - destinationDomain: Domain of the link destination
    ///   - isExternal: Whether link was opened in external browser
    func trackWebViewLinkClicked(
        service: String,
        destinationDomain: String,
        isExternal: Bool
    ) {
        let properties: [String: Any] = [
            "service": service,
            "destination_domain": destinationDomain,
            "is_external": isExternal
        ]
        
        trackEvent("webview_link_clicked", properties: properties)
    }
    
    /// Tracks window focus events for service usage analysis.
    ///
    /// Called by:
    /// - `BrowserViewController` focus detection when services gain focus
    ///
    /// Properties tracked:
    /// - service: Which AI service gained focus
    ///
    /// Provides insights into:
    /// - Which AI services users interact with most
    /// - Usage patterns across different services
    /// - Time spent in different service contexts
    ///
    /// - Parameter service: AI service ID that gained focus
    func trackWindowFocused(service: String) {
        let properties: [String: Any] = [
            "service": service
        ]
        
        trackEvent("window_focused", properties: properties)
    }
    
    /// Core event tracking method that respects user preferences.
    ///
    /// Called by:
    /// - All public tracking methods in this class
    ///
    /// Behavior:
    /// - Only tracks if analytics is enabled by user
    /// - Adds common properties like timestamp
    /// - Handles errors gracefully without affecting app functionality
    /// - Logs events for debugging in development
    ///
    /// - Parameters:
    ///   - eventName: Name of the event to track
    ///   - properties: Dictionary of event properties
    private func trackEvent(_ eventName: String, properties: [String: Any]) {
        guard isEnabled else {
            return
        }
        
        // Add common properties to all events
        var enrichedProperties = properties
        enrichedProperties["timestamp"] = Date().timeIntervalSince1970
        enrichedProperties["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        
        guard let amplitude = amplitude else { return }
        amplitude.track(eventType: eventName, eventProperties: enrichedProperties)
        
        print("📊 AnalyticsManager: Tracked '\(eventName)' with properties: \(enrichedProperties)")
    }
}