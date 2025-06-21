import Foundation
import WebKit
import os.log

class WebViewLogger: NSObject {
    static let shared = WebViewLogger()
    
    private let logQueue = DispatchQueue(label: "com.hyperchat.webviewlogger", attributes: .concurrent)
    private var loggers: [String: OSLog] = [:]
    private var fileHandles: [String: FileHandle] = [:]
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
        let message = """
        Navigation Started:
        URL: \(request.url?.absoluteString ?? "unknown")
        Method: \(request.httpMethod ?? "unknown")
        Headers: \(request.allHTTPHeaderFields ?? [:])
        """
        log(message, for: service, type: .info)
    }
    
    func logNavigationResponse(_ response: URLResponse?, service: String) {
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
        let status = start ? "Started" : "Finished"
        log("Page Load \(status): \(url?.absoluteString ?? "unknown")", for: service, type: .info)
    }
}

// MARK: - JavaScript Console Capture
extension WebViewLogger {
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
        let content = message["message"] as? String ?? ""
        let url = message["url"] as? String ?? ""
        
        let logMessage = "JS Console [\(level)]: \(content) (from: \(url))"
        let logType: LogType = level == "error" ? .error : level == "warn" ? .warning : .debug
        
        log(logMessage, for: service, type: logType)
    }
}

// MARK: - Network Monitoring
extension WebViewLogger {
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
        let url = data["url"] as? String ?? ""
        let method = data["method"] as? String ?? ""
        
        log("Network Request: \(method) \(url)", for: service, type: .debug)
    }
    
    func handleNetworkResponse(_ data: [String: Any], service: String) {
        let url = data["url"] as? String ?? ""
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
extension WebViewLogger {
    var domMonitorScript: String {
        return """
        (function() {
            let mutationQueue = [];
            let isProcessing = false;
            const MAX_MUTATIONS_PER_BATCH = 10;
            const BATCH_DELAY_MS = 1000;
            
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
                if (mutationQueue.length > 1000) {
                    mutationQueue = mutationQueue.slice(-500);
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
extension WebViewLogger {
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
                    text: target.textContent ? target.textContent.substring(0, 100) : null,
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
                }, 1000); // Debounce for 1 second
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
class ConsoleMessageHandler: NSObject, WKScriptMessageHandler {
    let service: String
    
    init(service: String) {
        self.service = service
        super.init()
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        
        switch message.name {
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
            break
        }
    }
}