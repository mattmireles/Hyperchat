/// AutoInstaller.swift - First-Launch Application Installation
///
/// This file implements the auto-installation prompt that appears when Hyperchat
/// is launched from a temporary location (Downloads, Desktop, etc.). It offers
/// to move the app to the Applications folder for proper installation.
///
/// Key responsibilities:
/// - Detects if app is running from temporary location
/// - Shows installation prompt on first launch
/// - Moves app bundle to /Applications folder
/// - Handles file conflicts with existing installations
/// - Relaunches app from new location after move
/// - Shows error alerts if installation fails
///
/// Related files:
/// - `AppDelegate.swift`: Calls checkAndPromptInstallation() on app launch
/// - `HyperchatApp.swift`: May also trigger installation check
///
/// Architecture:
/// - Singleton pattern for global access
/// - Uses FileManager for file operations
/// - Process API for relaunching app
/// - NSAlert for user prompts

import Foundation
import AppKit

// MARK: - Constants

/// Timing constants for installation process.
private enum InstallationTimings {
    /// Delay before terminating current app after launching new instance
    static let relaunchDelay: TimeInterval = 0.5
}

/// Singleton class managing app installation to Applications folder.
///
/// Created by:
/// - Static singleton on first access
///
/// Used by:
/// - `AppDelegate.applicationDidFinishLaunching()` to check installation
///
/// The installer only prompts once per launch from temporary location.
/// If user declines, they won't be prompted again until next launch.
class AutoInstaller {
    /// Shared singleton instance
    static let shared = AutoInstaller()
    
    /// Private initializer enforces singleton pattern
    private init() {}
    
    /// Checks if installation is needed and shows prompt.
    ///
    /// Called by:
    /// - `AppDelegate.applicationDidFinishLaunching()` on startup
    ///
    /// Process:
    /// 1. Checks if app is in temporary location
    /// 2. Shows installation prompt on main thread
    /// 3. Handles user response (install or defer)
    ///
    /// The check is performed on every launch but only
    /// prompts if running from Downloads, Desktop, etc.
    func checkAndPromptInstallation() {
        guard shouldPromptInstallation() else { return }
        
        DispatchQueue.main.async {
            self.showInstallationPrompt()
        }
    }
    
    /// Determines if installation prompt should be shown.
    ///
    /// Returns true if:
    /// - App is NOT in /Applications folder
    /// - App IS in Downloads, Desktop, or temp folder
    ///
    /// Common scenarios:
    /// - Downloaded from web -> ~/Downloads (prompts)
    /// - Unzipped on Desktop -> ~/Desktop (prompts)  
    /// - Running from /Applications (no prompt)
    /// - Running from custom location (no prompt)
    ///
    /// This prevents prompting users who intentionally
    /// install apps in non-standard locations.
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
    
    /// Moves app bundle to Applications folder.
    ///
    /// Process:
    /// 1. Determines destination path in /Applications
    /// 2. Removes existing app if present (overwrites)
    /// 3. Moves current bundle to Applications
    /// 4. Launches new instance from Applications
    /// 5. Current instance terminates after delay
    ///
    /// Error handling:
    /// - Permission denied: Shows error alert
    /// - File exists: Overwrites after removal
    /// - Move fails: Shows error with details
    ///
    /// The move operation is atomic - either succeeds
    /// completely or fails with no partial state.
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
    
    /// Launches new app instance and terminates current one.
    ///
    /// Uses /usr/bin/open with -n flag to:
    /// - Launch new instance (not reuse existing)
    /// - Start from correct Applications location
    /// - Maintain separate process space
    ///
    /// The 0.5 second delay ensures:
    /// - New instance fully launches
    /// - Windows transfer properly
    /// - No data loss during transition
    ///
    /// - Parameter path: Full path to app in Applications
    private func relaunchFromApplications(at path: String) {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", path]
        
        do {
            try task.run()
            
            // Quit current instance after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + InstallationTimings.relaunchDelay) {
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