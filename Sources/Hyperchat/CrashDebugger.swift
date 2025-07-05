/// CrashDebugger.swift - Crash Debugging and Breadcrumb Logging
///
/// This file implements a lightweight crash debugging system that logs breadcrumbs
/// to help diagnose issues after crashes. It writes timestamped entries to a log
/// file for post-crash analysis.
///
/// Key responsibilities:
/// - Logs app lifecycle events (start/shutdown)
/// - Records window close operations
/// - Tracks WebView cleanup sequences
/// - Documents message handler removal
/// - Captures delegate callback timing
/// - Thread-safe file writing with barrier queue
///
/// Related files:
/// - `OverlayController.swift`: Logs window close events
/// - `ServiceManager.swift`: Logs WebView cleanup
/// - `WebViewFactory.swift`: May log handler cleanup
/// - `BrowserViewController.swift`: May log delegate callbacks
///
/// Architecture:
/// - Singleton pattern for global access
/// - Concurrent queue with barriers for thread safety
/// - File-based persistence in ~/Library/Logs/Hyperchat/
/// - Automatic file handle management

import Foundation
/// Singleton logger for crash debugging breadcrumbs.
///
/// Log file location:
/// ~/Library/Logs/Hyperchat/crash-breadcrumbs.log
///
/// The log persists between app launches to help
/// diagnose crashes that occurred in previous sessions.
class CrashDebugger {
    /// Shared singleton instance
    static let shared = CrashDebugger()
    
    /// URL of the breadcrumb log file
    private let logFile: URL
    
    /// Date formatter for consistent timestamps
    private let dateFormatter: DateFormatter
    
    /// File handle for appending to log
    private var fileHandle: FileHandle?
    
    /// Concurrent queue with barriers for thread safety
    private let queue = DispatchQueue(label: "com.hyperchat.crashdebugger", attributes: .concurrent)
    
    private init() {
        // Create log file in user's library
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let logDir = libraryPath.appendingPathComponent("Logs/Hyperchat")
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        
        self.logFile = logDir.appendingPathComponent("crash-breadcrumbs.log")
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // Create or append to file
        if !FileManager.default.fileExists(atPath: logFile.path) {
            FileManager.default.createFile(atPath: logFile.path, contents: nil)
        }
        
        self.fileHandle = FileHandle(forWritingAtPath: logFile.path)
        self.fileHandle?.seekToEndOfFile()
        
        // Log startup
        log("=== APP STARTED ===")
    }
    
    deinit {
        log("=== APP SHUTTING DOWN ===")
        fileHandle?.closeFile()
    }
    
    /// Logs a breadcrumb message with source location.
    ///
    /// Called by:
    /// - Any code needing to trace execution for debugging
    /// - Specialized log methods below
    ///
    /// Format:
    /// [timestamp] [filename:line] function - message
    ///
    /// The barrier flag ensures thread-safe file writes.
    ///
    /// - Parameters:
    ///   - message: The breadcrumb message
    ///   - file: Source file (auto-captured)
    ///   - function: Function name (auto-captured)
    ///   - line: Line number (auto-captured)
    func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let timestamp = self.dateFormatter.string(from: Date())
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            let logEntry = "[\(timestamp)] [\(fileName):\(line)] \(function) - \(message)\n"
            
            if let data = logEntry.data(using: .utf8) {
                self.fileHandle?.write(data)
                
                // Also print to console
                print("🍞 \(logEntry.trimmingCharacters(in: .newlines))")
            }
        }
    }
    
    // MARK: - Specialized Logging Methods
    
    /// Logs window close operation start.
    /// Called by: OverlayController when closing windows
    func logWindowClose(windowId: String) {
        log("WINDOW CLOSE STARTED: \(windowId)")
    }
    
    /// Logs WebView cleanup operation.
    /// Called by: ServiceManager during WebView destruction
    func logWebViewCleanup(service: String, address: String) {
        log("WEBVIEW CLEANUP: \(service) at \(address)")
    }
    
    /// Logs script message handler removal.
    /// Called by: WebViewFactory during handler cleanup
    func logHandlerCleanup(handlerId: String, messageType: String) {
        log("HANDLER CLEANUP: \(handlerId) for \(messageType)")
    }
    
    /// Logs delegate method callbacks.
    /// Called by: Various delegates for timing analysis
    func logDelegateCallback(delegate: String, method: String) {
        log("DELEGATE CALLBACK: \(delegate).\(method)")
    }
    
    /// Forces pending writes to disk.
    ///
    /// Called by:
    /// - Code needing to ensure logs are persisted
    /// - Before operations that might crash
    ///
    /// Uses synchronizeFile() to flush kernel buffers.
    func flush() {
        queue.async(flags: .barrier) { [weak self] in
            self?.fileHandle?.synchronizeFile()
        }
    }
}