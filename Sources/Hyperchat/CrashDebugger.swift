import Foundation

// Crash debugging helper that logs breadcrumbs to a file
class CrashDebugger {
    static let shared = CrashDebugger()
    
    private let logFile: URL
    private let dateFormatter: DateFormatter
    private var fileHandle: FileHandle?
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
    
    func logWindowClose(windowId: String) {
        log("WINDOW CLOSE STARTED: \(windowId)")
    }
    
    func logWebViewCleanup(service: String, address: String) {
        log("WEBVIEW CLEANUP: \(service) at \(address)")
    }
    
    func logHandlerCleanup(handlerId: String, messageType: String) {
        log("HANDLER CLEANUP: \(handlerId) for \(messageType)")
    }
    
    func logDelegateCallback(delegate: String, method: String) {
        log("DELEGATE CALLBACK: \(delegate).\(method)")
    }
    
    func flush() {
        queue.async(flags: .barrier) { [weak self] in
            self?.fileHandle?.synchronizeFile()
        }
    }
}