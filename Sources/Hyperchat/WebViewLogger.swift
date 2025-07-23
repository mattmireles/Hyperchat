/// WebViewLogger.swift - Comprehensive WebView Debugging and Analytics System
///
/// This file implements a multi-layered logging system for debugging WebView behavior,
/// tracking user interactions, and monitoring network activity. It provides configurable
/// logging with file persistence and console output.
///
/// Key responsibilities:
/// - Injects JavaScript monitoring scripts into WebViews
/// - Captures console.log/warn/error messages from web pages
/// - Monitors network requests (fetch/XHR) with analytics filtering
/// - Tracks DOM mutations in batches for performance
/// - Records user interactions (clicks, form submits, etc.)
/// - Persists logs to dated files per service
/// - Provides configurable logging levels via settings
///
/// Related files:
/// - `WebViewFactory.swift`: Injects logging scripts during WebView creation
/// - `BrowserViewController.swift`: Uses navigation logging methods
/// - `ServiceManager.swift`: May enable/disable logging for specific operations
/// - `SettingsWindowController.swift`: Provides UI for logging configuration
///
/// Architecture:
/// - Singleton pattern for global access (WebViewLogger.shared)
/// - Concurrent queue for thread-safe file operations
/// - Per-service log files organized by date
/// - Message handlers cleanup to prevent memory leaks
/// - Configurable filtering of analytics domains

import Foundation
import WebKit
import os.log
import SwiftUI

// MARK: - Logging Settings

/// Timing constants for logging behavior.
private enum LoggingTimings {
    /// Delay between DOM mutation batches to reduce noise
    static let domMutationBatchDelay: TimeInterval = 1.0
    
    /// Debounce delay for input events to avoid spam
    static let inputEventDebounce: TimeInterval = 1.0
}

/// Batch processing limits to prevent memory issues.
private enum LoggingLimits {
    /// Maximum mutations to process per batch
    static let maxMutationsPerBatch: Int = 10
    
    /// Maximum queue size before truncation
    static let maxMutationQueueSize: Int = 1000
    
    /// Queue size after truncation
    static let truncatedQueueSize: Int = 500
    
    /// Maximum characters to log from element text
    static let maxElementTextLength: Int = 100
}

/// Persistent settings for logging configuration.
///
/// Used by:
/// - `SettingsWindowController`: Provides UI for configuration
/// - `WebViewLogger`: Checks flags before logging
///
/// Settings are stored in UserDefaults directly to avoid SwiftUI initialization dependencies.
/// Maintains ObservableObject for SwiftUI compatibility.
class LoggingSettings: ObservableObject {
    static let shared = LoggingSettings()
    
    private let defaults = UserDefaults.standard
    
    var networkRequests: Bool {
        get { defaults.object(forKey: "logging.networkRequests") as? Bool ?? false }
        set { 
            defaults.set(newValue, forKey: "logging.networkRequests")
            objectWillChange.send()
        }
    }
    
    var userInteractions: Bool {
        get { defaults.object(forKey: "logging.userInteractions") as? Bool ?? false }
        set { 
            defaults.set(newValue, forKey: "logging.userInteractions")
            objectWillChange.send()
        }
    }
    
    var consoleMessages: Bool {
        get { defaults.object(forKey: "logging.consoleMessages") as? Bool ?? true }
        set { 
            defaults.set(newValue, forKey: "logging.consoleMessages")
            objectWillChange.send()
        }
    }
    
    var domChanges: Bool {
        get { defaults.object(forKey: "logging.domChanges") as? Bool ?? false }
        set { 
            defaults.set(newValue, forKey: "logging.domChanges")
            objectWillChange.send()
        }
    }
    
    var navigation: Bool {
        get { defaults.object(forKey: "logging.navigation") as? Bool ?? true }
        set { 
            defaults.set(newValue, forKey: "logging.navigation")
            objectWillChange.send()
        }
    }
    
    var debugPrompts: Bool {
        get { defaults.object(forKey: "logging.debugPrompts") as? Bool ?? true }
        set { 
            defaults.set(newValue, forKey: "logging.debugPrompts")
            objectWillChange.send()
        }
    }
    
    var analyticsFilter: Bool {
        get { defaults.object(forKey: "logging.analyticsFilter") as? Bool ?? true }
        set { 
            defaults.set(newValue, forKey: "logging.analyticsFilter")
            objectWillChange.send()
        }
    }
    
    // Convenience methods for preset configurations
    func setMinimalLogging() {
        networkRequests = false
        userInteractions = false
        consoleMessages = true
        domChanges = false
        navigation = true
        debugPrompts = false
        analyticsFilter = true
        objectWillChange.send()
    }
    
    func setDebugReplyToAll() {
        networkRequests = false
        userInteractions = false
        consoleMessages = true
        domChanges = false
        navigation = true
        debugPrompts = true
        analyticsFilter = true
        objectWillChange.send()
    }
    
    func setVerboseLogging() {
        networkRequests = true
        userInteractions = true
        consoleMessages = true
        domChanges = true
        navigation = true
        debugPrompts = true
        analyticsFilter = false
        objectWillChange.send()
    }
}

// MARK: - Analytics Domains

/// Analytics and tracking domains to filter out when analyticsFilter is enabled.
///
/// These domains generate high-volume, low-value logging that clutters
/// debug output. When analyticsFilter is true, all requests/responses
/// to these domains are silently dropped from logs.
///
/// Maintained as a static list for performance (avoiding regex).
private let analyticsDomains = [
    "googletagmanager.com",
    "google-analytics.com", 
    "datadoghq.com",
    "browser-intake-datadoghq.com",
    "amazon-adsystem.com",
    "doubleclick.net",
    "facebook.com",
    "play.google.com/log",
    "accounts.google.com/gsi/log",
    "reddit.com",
    "redditstatic.com",
    "singular.net",
    "eppo.cloud",
    "ipv4.podscribe.com",
    "ab.chatgpt.com"
]

/// Main logging coordinator for all WebView-related events.
///
/// Lifecycle:
/// 1. Created as singleton on first access
/// 2. Sets up log directory structure in ~/Library/Logs/Hyperchat/
/// 3. Creates per-service subdirectories as needed
/// 4. Opens file handles lazily on first write
/// 5. Closes file handles via closeLogFile() when service destroyed
///
/// Thread safety:
/// - Uses concurrent queue with barrier for writes
/// - File handles dictionary protected by queue
/// - OSLog instances cached per service
class WebViewLogger: NSObject {
    /// Shared singleton instance
    static let shared = WebViewLogger()
    
    /// Concurrent queue for thread-safe file operations
    /// Barrier flag used for writes to ensure consistency
    private let logQueue = DispatchQueue(label: "com.hyperchat.webviewlogger", attributes: .concurrent)
    
    /// Cached OSLog instances per service to avoid recreation
    private var loggers: [String: OSLog] = [:]
    
    /// Open file handles for active log files
    /// Key: service name, Value: handle to service's current log file
    private var fileHandles: [String: FileHandle] = [:]
    
    /// Date formatter for consistent timestamp formatting
    private let dateFormatter: DateFormatter
    
    override init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        super.init()
        setupLogDirectory()
    }
    
    private func setupLogDirectory() {
        let logDirectory = getLogDirectory()
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }
    
    private func getLogDirectory() -> URL {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return libraryPath.appendingPathComponent("Logs/Hyperchat")
    }
    
    private func getLogFile(for service: String) -> URL {
        let logDir = getLogDirectory().appendingPathComponent(service)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        return logDir.appendingPathComponent("\(dateString).log")
    }
    
    /// Logs a message for a specific service.
    ///
    /// Called by:
    /// - All handle* methods after processing WebKit messages
    /// - Navigation delegate methods in extensions
    /// - External code for custom logging needs
    ///
    /// Process:
    /// 1. Formats message with timestamp
    /// 2. Writes to system console via OSLog
    /// 3. Persists to service-specific log file
    /// 4. Uses barrier for thread safety
    ///
    /// - Parameters:
    ///   - message: The log message to write
    ///   - service: Service name (e.g., "chatgpt", "claude")
    ///   - type: Log severity level
    func log(_ message: String, for service: String, type: LogType = .info) {
        logQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let timestamp = self.dateFormatter.string(from: Date())
            let logEntry = LogEntry(
                timestamp: timestamp,
                type: type,
                service: service,
                message: message
            )
            
            // Log to system console
            if loggers[service] == nil {
                loggers[service] = OSLog(subsystem: "com.hyperchat", category: service)
            }
            
            if let logger = loggers[service] {
                os_log("%{public}@", log: logger, type: type.osLogType, logEntry.formatted)
            }
            
            // Write to file
            self.writeToFile(logEntry, service: service)
        }
    }
    
    private func writeToFile(_ entry: LogEntry, service: String) {
        let logFile = getLogFile(for: service)
        
        if fileHandles[service] == nil {
            if !FileManager.default.fileExists(atPath: logFile.path) {
                FileManager.default.createFile(atPath: logFile.path, contents: nil)
            }
            fileHandles[service] = FileHandle(forWritingAtPath: logFile.path)
            fileHandles[service]?.seekToEndOfFile()
        }
        
        if let data = (entry.jsonString + "\n").data(using: .utf8),
           let handle = fileHandles[service] {
            handle.write(data)
        }
    }
    
    func closeLogFile(for service: String) {
        logQueue.async(flags: .barrier) { [weak self] in
            self?.fileHandles[service]?.closeFile()
            self?.fileHandles[service] = nil
        }
    }
}

// MARK: - WKNavigationDelegate Logging
extension WebViewLogger {
    func logNavigation(_ navigation: WKNavigation?, request: URLRequest, service: String) {
        guard LoggingSettings.shared.navigation else { return }
        
        let message = """
        Navigation Started:
        URL: \(request.url?.absoluteString ?? "unknown")
        Method: \(request.httpMethod ?? "unknown")
        Headers: \(request.allHTTPHeaderFields ?? [:])
        """
        log(message, for: service, type: .info)
    }
    
    func logNavigationResponse(_ response: URLResponse?, service: String) {
        guard LoggingSettings.shared.navigation else { return }
        guard let httpResponse = response as? HTTPURLResponse else { return }
        
        let message = """
        Navigation Response:
        URL: \(httpResponse.url?.absoluteString ?? "unknown")
        Status: \(httpResponse.statusCode)
        Headers: \(httpResponse.allHeaderFields)
        """
        log(message, for: service, type: .info)
    }
    
    func logNavigationError(_ error: Error, service: String) {
        log("Navigation Error: \(error.localizedDescription)", for: service, type: .error)
    }
    
    func logPageLoad(start: Bool, service: String, url: URL?) {
        guard LoggingSettings.shared.navigation else { return }
        
        let status = start ? "Started" : "Finished"
        log("Page Load \(status): \(url?.absoluteString ?? "unknown")", for: service, type: .info)
    }
}

// MARK: - JavaScript Console Capture

/// Extension for capturing JavaScript console output from web pages.
extension WebViewLogger {
    /// JavaScript code that intercepts console.* methods.
    ///
    /// Injected by:
    /// - `WebViewFactory.createWebView()` during setup
    ///
    /// Captures:
    /// - console.log/warn/error/info/debug calls
    /// - Unhandled JavaScript errors
    /// - Unhandled promise rejections
    ///
    /// The script:
    /// 1. Saves original console methods
    /// 2. Wraps them to send messages to native code
    /// 3. Preserves original behavior (logs still appear in web inspector)
    /// 4. Serializes objects to JSON for native consumption
    var consoleLogScript: String {
        return """
        (function() {
            const originalLog = console.log;
            const originalWarn = console.warn;
            const originalError = console.error;
            const originalInfo = console.info;
            const originalDebug = console.debug;
            
            function sendToNative(level, args) {
                window.webkit.messageHandlers.consoleLog.postMessage({
                    level: level,
                    message: Array.from(args).map(arg => {
                        if (typeof arg === 'object') {
                            try {
                                return JSON.stringify(arg, null, 2);
                            } catch (e) {
                                return String(arg);
                            }
                        }
                        return String(arg);
                    }).join(' '),
                    timestamp: new Date().toISOString(),
                    url: window.location.href
                });
            }
            
            console.log = function() {
                originalLog.apply(console, arguments);
                sendToNative('log', arguments);
            };
            
            console.warn = function() {
                originalWarn.apply(console, arguments);
                sendToNative('warn', arguments);
            };
            
            console.error = function() {
                originalError.apply(console, arguments);
                sendToNative('error', arguments);
            };
            
            console.info = function() {
                originalInfo.apply(console, arguments);
                sendToNative('info', arguments);
            };
            
            console.debug = function() {
                originalDebug.apply(console, arguments);
                sendToNative('debug', arguments);
            };
            
            // Capture unhandled errors
            window.addEventListener('error', function(e) {
                sendToNative('error', [`Unhandled error: ${e.message} at ${e.filename}:${e.lineno}:${e.colno}`]);
            });
            
            // Capture unhandled promise rejections
            window.addEventListener('unhandledrejection', function(e) {
                sendToNative('error', [`Unhandled promise rejection: ${e.reason}`]);
            });
        })();
        """
    }
    
    func handleConsoleMessage(_ message: [String: Any], service: String) {
        let level = message["level"] as? String ?? "log"
        
        // Always log errors, check flag for other messages
        guard level == "error" || LoggingSettings.shared.consoleMessages else { return }
        
        let content = message["message"] as? String ?? ""
        let url = message["url"] as? String ?? ""
        
        let logMessage = "JS Console [\(level)]: \(content) (from: \(url))"
        let logType: LogType = level == "error" ? .error : level == "warn" ? .warning : .debug
        
        log(logMessage, for: service, type: logType)
    }
}

// MARK: - Network Monitoring

/// Extension for monitoring network requests from web pages.
extension WebViewLogger {
    /// JavaScript code that intercepts fetch() and XMLHttpRequest.
    ///
    /// Injected by:
    /// - `WebViewFactory.createWebView()` if network logging enabled
    ///
    /// Monitors:
    /// - All fetch() API calls
    /// - All XMLHttpRequest (XHR) calls
    /// - Request URLs, methods, and timing
    /// - Response status codes and timing
    ///
    /// Note: Headers and body content are not captured for privacy.
    /// Analytics requests are filtered based on domain list.
    var networkMonitorScript: String {
        return """
        (function() {
            const originalFetch = window.fetch;
            const originalXHROpen = XMLHttpRequest.prototype.open;
            const originalXHRSend = XMLHttpRequest.prototype.send;
            
            // Monitor fetch requests
            window.fetch = function(url, options = {}) {
                const requestData = {
                    url: url.toString(),
                    method: options.method || 'GET',
                    headers: options.headers || {},
                    timestamp: new Date().toISOString()
                };
                
                window.webkit.messageHandlers.networkRequest.postMessage(requestData);
                
                return originalFetch.apply(this, arguments).then(response => {
                    const responseData = {
                        url: response.url,
                        status: response.status,
                        statusText: response.statusText,
                        headers: {},
                        timestamp: new Date().toISOString()
                    };
                    
                    window.webkit.messageHandlers.networkResponse.postMessage(responseData);
                    return response;
                });
            };
            
            // Monitor XHR requests
            XMLHttpRequest.prototype.open = function(method, url) {
                this._url = url;
                this._method = method;
                return originalXHROpen.apply(this, arguments);
            };
            
            XMLHttpRequest.prototype.send = function(data) {
                const xhr = this;
                const requestData = {
                    url: xhr._url,
                    method: xhr._method,
                    timestamp: new Date().toISOString()
                };
                
                window.webkit.messageHandlers.networkRequest.postMessage(requestData);
                
                xhr.addEventListener('load', function() {
                    const responseData = {
                        url: xhr._url,
                        status: xhr.status,
                        statusText: xhr.statusText,
                        timestamp: new Date().toISOString()
                    };
                    
                    window.webkit.messageHandlers.networkResponse.postMessage(responseData);
                });
                
                return originalXHRSend.apply(this, arguments);
            };
        })();
        """
    }
    
    func handleNetworkRequest(_ data: [String: Any], service: String) {
        guard LoggingSettings.shared.networkRequests else { return }
        
        let url = data["url"] as? String ?? ""
        
        // Check analytics filter
        if LoggingSettings.shared.analyticsFilter {
            for domain in analyticsDomains {
                if url.contains(domain) {
                    return  // Skip logging analytics requests
                }
            }
        }
        
        let method = data["method"] as? String ?? ""
        log("Network Request: \(method) \(url)", for: service, type: .debug)
    }
    
    func handleNetworkResponse(_ data: [String: Any], service: String) {
        guard LoggingSettings.shared.networkRequests else { return }
        
        let url = data["url"] as? String ?? ""
        
        // Check analytics filter
        if LoggingSettings.shared.analyticsFilter {
            for domain in analyticsDomains {
                if url.contains(domain) {
                    return  // Skip logging analytics responses
                }
            }
        }
        
        let status = data["status"] as? Int ?? 0
        log("Network Response: \(status) \(url)", for: service, type: .debug)
    }
}

// MARK: - Supporting Types
enum LogType {
    case debug, info, warning, error, fault
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .fault: return .fault
        }
    }
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .fault: return "💥"
        }
    }
}

struct LogEntry {
    let timestamp: String
    let type: LogType
    let service: String
    let message: String
    
    var formatted: String {
        return "[\(timestamp)] \(type.emoji) \(message)"
    }
    
    var jsonString: String {
        let dict: [String: Any] = [
            "timestamp": timestamp,
            "type": String(describing: type),
            "service": service,
            "message": message
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        
        return formatted
    }
}

// MARK: - DOM Monitoring

/// Extension for monitoring DOM mutations in web pages.
extension WebViewLogger {
    /// JavaScript code that observes DOM changes via MutationObserver.
    ///
    /// Injected by:
    /// - `WebViewFactory.createWebView()` if DOM logging enabled
    ///
    /// Features:
    /// - Batches mutations to reduce message frequency
    /// - Limits queue size to prevent memory issues
    /// - Aggregates similar mutations into summaries
    /// - Only sends significant changes to native code
    ///
    /// Performance optimizations:
    /// - 10 mutations per batch maximum
    /// - 1 second delay between batches
    /// - Queue truncation at 1000 items
    /// - No old values captured (reduces memory)
    var domMonitorScript: String {
        return """
        (function() {
            let mutationQueue = [];
            let isProcessing = false;
            const MAX_MUTATIONS_PER_BATCH = \(LoggingLimits.maxMutationsPerBatch);
            const BATCH_DELAY_MS = \(Int(LoggingTimings.domMutationBatchDelay * 1000));
            
            // Throttled function to process mutations
            function processMutations() {
                if (isProcessing || mutationQueue.length === 0) return;
                
                isProcessing = true;
                const batch = mutationQueue.splice(0, MAX_MUTATIONS_PER_BATCH);
                
                // Aggregate similar mutations
                const summary = {
                    timestamp: new Date().toISOString(),
                    mutationCount: batch.length,
                    childListChanges: 0,
                    attributeChanges: 0,
                    characterDataChanges: 0,
                    totalAdded: 0,
                    totalRemoved: 0
                };
                
                batch.forEach(mutation => {
                    if (mutation.type === 'childList') {
                        summary.childListChanges++;
                        summary.totalAdded += mutation.addedNodes.length;
                        summary.totalRemoved += mutation.removedNodes.length;
                    } else if (mutation.type === 'attributes') {
                        summary.attributeChanges++;
                    } else if (mutation.type === 'characterData') {
                        summary.characterDataChanges++;
                    }
                });
                
                // Only send if there were significant changes
                if (summary.mutationCount > 0) {
                    window.webkit.messageHandlers.domChange.postMessage(summary);
                }
                
                setTimeout(() => {
                    isProcessing = false;
                    if (mutationQueue.length > 0) {
                        processMutations();
                    }
                }, BATCH_DELAY_MS);
            }
            
            // Create a mutation observer to track DOM changes
            const observer = new MutationObserver(function(mutations) {
                // Add mutations to queue
                mutationQueue.push(...mutations);
                
                // Limit queue size to prevent memory issues
                if (mutationQueue.length > \(LoggingLimits.maxMutationQueueSize)) {
                    mutationQueue = mutationQueue.slice(-\(LoggingLimits.truncatedQueueSize));
                }
                
                // Trigger processing
                processMutations();
            });
            
            // Start observing when DOM is ready
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', function() {
                    observer.observe(document.body, {
                        childList: true,
                        attributes: true,
                        characterData: true,
                        subtree: true,
                        attributeOldValue: false, // Disable to reduce data
                        characterDataOldValue: false // Disable to reduce data
                    });
                });
            } else {
                observer.observe(document.body, {
                    childList: true,
                    attributes: true,
                    characterData: true,
                    subtree: true,
                    attributeOldValue: false,
                    characterDataOldValue: false
                });
            }
        })();
        """
    }
    
    func handleDOMChange(_ data: [String: Any], service: String) {
        guard LoggingSettings.shared.domChanges else { return }
        
        // Handle new summary format
        let mutationCount = data["mutationCount"] as? Int ?? 0
        let childListChanges = data["childListChanges"] as? Int ?? 0
        let attributeChanges = data["attributeChanges"] as? Int ?? 0
        let characterDataChanges = data["characterDataChanges"] as? Int ?? 0
        let totalAdded = data["totalAdded"] as? Int ?? 0
        let totalRemoved = data["totalRemoved"] as? Int ?? 0
        
        var message = "DOM Change Summary: \(mutationCount) mutations"
        
        if childListChanges > 0 {
            message += " | \(childListChanges) childList (added: \(totalAdded), removed: \(totalRemoved))"
        }
        if attributeChanges > 0 {
            message += " | \(attributeChanges) attributes"
        }
        if characterDataChanges > 0 {
            message += " | \(characterDataChanges) text"
        }
        
        log(message, for: service, type: .debug)
    }
}

// MARK: - User Interaction Tracking

/// Extension for tracking user interactions with web pages.
extension WebViewLogger {
    /// JavaScript code that tracks user interactions.
    ///
    /// Injected by:
    /// - `WebViewFactory.createWebView()` if interaction logging enabled
    ///
    /// Tracks:
    /// - Click events (with element details)
    /// - Form submissions
    /// - Input field changes (debounced)
    /// - Focus events on form fields
    /// - Copy/paste operations
    ///
    /// Privacy considerations:
    /// - Input values are not logged, only length
    /// - Passwords fields are not tracked
    /// - Text content truncated to 100 characters
    var userInteractionScript: String {
        return """
        (function() {
            // Track clicks
            document.addEventListener('click', function(e) {
                const target = e.target;
                const data = {
                    type: 'click',
                    tagName: target.tagName,
                    id: target.id || null,
                    className: target.className || null,
                    text: target.textContent ? target.textContent.substring(0, \(LoggingLimits.maxElementTextLength)) : null,
                    href: target.href || null,
                    timestamp: new Date().toISOString()
                };
                window.webkit.messageHandlers.userInteraction.postMessage(data);
            }, true);
            
            // Track form submissions
            document.addEventListener('submit', function(e) {
                const form = e.target;
                const data = {
                    type: 'formSubmit',
                    formId: form.id || null,
                    formAction: form.action || null,
                    formMethod: form.method || null,
                    timestamp: new Date().toISOString()
                };
                window.webkit.messageHandlers.userInteraction.postMessage(data);
            }, true);
            
            // Track input changes
            let inputTimer = null;
            document.addEventListener('input', function(e) {
                clearTimeout(inputTimer);
                inputTimer = setTimeout(function() {
                    const target = e.target;
                    const data = {
                        type: 'input',
                        tagName: target.tagName,
                        inputType: target.type || null,
                        id: target.id || null,
                        name: target.name || null,
                        valueLength: target.value ? target.value.length : 0,
                        timestamp: new Date().toISOString()
                    };
                    window.webkit.messageHandlers.userInteraction.postMessage(data);
                }, \(Int(LoggingTimings.inputEventDebounce * 1000))); // Debounce for 1 second
            }, true);
            
            // Track focus events
            document.addEventListener('focus', function(e) {
                const target = e.target;
                if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') {
                    const data = {
                        type: 'focus',
                        tagName: target.tagName,
                        inputType: target.type || null,
                        id: target.id || null,
                        timestamp: new Date().toISOString()
                    };
                    window.webkit.messageHandlers.userInteraction.postMessage(data);
                }
            }, true);
            
            // Track copy events
            document.addEventListener('copy', function(e) {
                const selection = window.getSelection().toString();
                const data = {
                    type: 'copy',
                    selectionLength: selection.length,
                    timestamp: new Date().toISOString()
                };
                window.webkit.messageHandlers.userInteraction.postMessage(data);
            }, true);
            
            // Track paste events
            document.addEventListener('paste', function(e) {
                const data = {
                    type: 'paste',
                    target: e.target.tagName,
                    timestamp: new Date().toISOString()
                };
                window.webkit.messageHandlers.userInteraction.postMessage(data);
            }, true);
        })();
        """
    }
    
    func handleUserInteraction(_ data: [String: Any], service: String) {
        guard LoggingSettings.shared.userInteractions else { return }
        
        let type = data["type"] as? String ?? ""
        
        var message = "User Interaction: \(type)"
        
        switch type {
        case "click":
            if let tagName = data["tagName"] as? String {
                message += " on \(tagName)"
            }
            if let id = data["id"] as? String, !id.isEmpty {
                message += " #\(id)"
            }
            if let href = data["href"] as? String {
                message += " -> \(href)"
            }
            
        case "formSubmit":
            if let action = data["formAction"] as? String {
                message += " to \(action)"
            }
            
        case "input":
            if let tagName = data["tagName"] as? String,
               let inputType = data["inputType"] as? String {
                message += " \(tagName)[\(inputType)]"
            }
            if let valueLength = data["valueLength"] as? Int {
                message += " (length: \(valueLength))"
            }
            
        case "focus":
            if let tagName = data["tagName"] as? String {
                message += " on \(tagName)"
            }
            
        case "copy":
            if let length = data["selectionLength"] as? Int {
                message += " (\(length) chars)"
            }
            
        case "paste":
            if let target = data["target"] as? String {
                message += " into \(target)"
            }
            
        default:
            break
        }
        
        log(message, for: service, type: .info)
    }
}

// MARK: - Script Message Handler

/// Handles JavaScript messages sent from injected scripts.
///
/// Created by:
/// - `WebViewFactory` for each message type per WebView
///
/// Lifecycle:
/// 1. Created when WebView is configured
/// 2. Added to WKUserContentController
/// 3. Receives messages from JavaScript
/// 4. Routes to appropriate WebViewLogger handler
/// 5. Must be manually removed to prevent leaks
///
/// Memory management:
/// - Weak reference from JavaScript side
/// - Strong reference from WKUserContentController
/// - Must call markCleanedUp() before removal
/// - Tracks cleanup state to prevent use-after-free
class ConsoleMessageHandler: NSObject, WKScriptMessageHandler {
    /// Service name for routing (e.g., "chatgpt")
    let service: String
    
    /// Message type this handler processes
    let messageType: String
    
    /// Unique ID for debugging lifecycle
    private let instanceId = UUID().uuidString.prefix(8)
    
    /// Parent controller reference (unused but kept for future)
    private weak var parentController: WKUserContentController?
    
    /// Tracks if cleanup was called to prevent use-after-free
    private var isCleanedUp = false
    
    init(service: String, messageType: String) {
        self.service = service
        self.messageType = messageType
        super.init()
        let address = Unmanaged.passUnretained(self).toOpaque()
        let retainCount = CFGetRetainCount(self)
        print("🟢 [\(Date().timeIntervalSince1970)] ConsoleMessageHandler INIT \(instanceId) for \(service)/\(messageType) at \(address), retain count: \(retainCount)")
    }
    
    deinit {
        print("🔴 [\(Date().timeIntervalSince1970)] ConsoleMessageHandler DEINIT \(instanceId) for \(service)/\(messageType) - was cleaned up: \(isCleanedUp)")
    }
    
    func markCleanedUp() {
        isCleanedUp = true
        print("🧹 [\(Date().timeIntervalSince1970)] ConsoleMessageHandler \(instanceId) marked as cleaned up")
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard !isCleanedUp else {
            print("⚠️ [\(Date().timeIntervalSince1970)] ConsoleMessageHandler \(instanceId) received message after cleanup: \(message.name)")
            return
        }
        
        let address = Unmanaged.passUnretained(self).toOpaque()
        let retainCount = CFGetRetainCount(self)
        print("📨 [\(Date().timeIntervalSince1970)] ConsoleMessageHandler \(instanceId) (\(address)) received message: \(message.name), retain count: \(retainCount)")
        guard let body = message.body as? [String: Any] else { return }
        
        // Only handle the specific message type this handler was created for
        if message.name == messageType {
            switch messageType {
            case "consoleLog":
                WebViewLogger.shared.handleConsoleMessage(body, service: service)
            case "networkRequest":
                WebViewLogger.shared.handleNetworkRequest(body, service: service)
            case "networkResponse":
                WebViewLogger.shared.handleNetworkResponse(body, service: service)
            case "domChange":
                WebViewLogger.shared.handleDOMChange(body, service: service)
            case "userInteraction":
                WebViewLogger.shared.handleUserInteraction(body, service: service)
            default:
                print("⚠️ Unknown message type: \(messageType)")
            }
        } else {
            print("⚠️ Handler for \(messageType) received wrong message type: \(message.name)")
        }
    }
}