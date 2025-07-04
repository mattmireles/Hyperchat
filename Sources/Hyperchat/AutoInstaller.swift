import Foundation
import AppKit

class AutoInstaller {
    static let shared = AutoInstaller()
    private init() {}
    
    func checkAndPromptInstallation() {
        guard shouldPromptInstallation() else { return }
        
        DispatchQueue.main.async {
            self.showInstallationPrompt()
        }
    }
    
    private func shouldPromptInstallation() -> Bool {
        let bundlePath = Bundle.main.bundlePath
        let applicationsPath = "/Applications"
        
        // Check if already in Applications folder
        if bundlePath.hasPrefix(applicationsPath) {
            return false
        }
        
        // Check if running from Downloads, Desktop, or other temporary locations
        let temporaryLocations = [
            NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first ?? "",
            NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first ?? "",
            "/tmp",
            "/private/tmp"
        ]
        
        return temporaryLocations.contains { bundlePath.hasPrefix($0) }
    }
    
    private func showInstallationPrompt() {
        let alert = NSAlert()
        alert.messageText = "Install Hyperchat"
        alert.informativeText = "Would you like to move Hyperchat to your Applications folder? This will make it easier to launch and keep it up to date."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            moveToApplications()
        }
    }
    
    private func moveToApplications() {
        let bundlePath = Bundle.main.bundlePath
        let bundleName = (bundlePath as NSString).lastPathComponent
        let applicationsPath = "/Applications"
        let destinationPath = "\(applicationsPath)/\(bundleName)"
        
        do {
            let fileManager = FileManager.default
            
            // Remove existing app in Applications if it exists
            if fileManager.fileExists(atPath: destinationPath) {
                try fileManager.removeItem(atPath: destinationPath)
            }
            
            // Move the app
            try fileManager.moveItem(atPath: bundlePath, toPath: destinationPath)
            
            // Relaunch from new location
            relaunchFromApplications(at: destinationPath)
            
        } catch {
            showInstallationError(error)
        }
    }
    
    private func relaunchFromApplications(at path: String) {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", path]
        
        do {
            try task.run()
            
            // Quit current instance after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            showInstallationError(error)
        }
    }
    
    private func showInstallationError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Installation Failed"
        alert.informativeText = "Could not move Hyperchat to Applications folder: \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.runModal()
    }
}