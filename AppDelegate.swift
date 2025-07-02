import Cocoa
import SwiftUI
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {
    var floatingButtonManager: FloatingButtonManager
    var overlayController: OverlayController
    var promptWindowController: PromptWindowController
    var updaterController: SPUStandardUpdaterController!

    override init() {
        self.floatingButtonManager = FloatingButtonManager()
        self.overlayController = OverlayController()
        self.promptWindowController = PromptWindowController()
        super.init()
        self.updaterController = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Register custom fonts
        registerCustomFonts()
        
        floatingButtonManager.promptWindowController = promptWindowController
        floatingButtonManager.overlayController = self.overlayController
        floatingButtonManager.showFloatingButton()
        
        // Check for auto-installation on first launch
        AutoInstaller.shared.checkAndPromptInstallation()
        
        // Show the window in normal view on startup
        overlayController.showOverlay()
        
        // Start Sparkle updater after a delay to avoid startup conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.startUpdater()
        }
        
        // Listen for prompt submission to show overlay
        NotificationCenter.default.addObserver(forName: .showOverlay, object: nil, queue: .main) { [weak self] notification in
            if let prompt = notification.object as? String {
                self?.overlayController.showOverlay(with: prompt)
            }
        }
        
        // Listen for overlay hide to ensure floating button stays visible
        NotificationCenter.default.addObserver(forName: .overlayDidHide, object: nil, queue: .main) { [weak self] _ in
            self?.floatingButtonManager.ensureFloatingButtonVisible()
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    private func registerCustomFonts() {
        if let fontURL = Bundle.main.url(forResource: "Orbitron-Bold", withExtension: "ttf") {
            print("Found font file at: \(fontURL.path)")
            
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
                print("✅ Orbitron font registered successfully")
                
                // Try different font name variations
                let variations = ["Orbitron-Bold", "Orbitron Bold", "OrbitronBold", "Orbitron"]
                for name in variations {
                    if let _ = NSFont(name: name, size: 12) {
                        print("✅ Font available as: '\(name)'")
                    }
                }
            } else {
                if let error = error {
                    print("❌ Failed to register font: \(error.takeRetainedValue())")
                }
            }
        } else {
            print("❌ Failed to find Orbitron font file in bundle")
        }
    }
    
    @objc func checkForUpdates(_ sender: Any?) {
        // Ensure updater is started before checking for updates
        if !updaterController.updater.sessionInProgress {
            do {
                try updaterController.updater.start()
            } catch {
                print("Sparkle: Failed to start updater - \(error.localizedDescription)")
                return
            }
        }
        updaterController.checkForUpdates(sender)
    }
    
    private func startUpdater() {
        do {
            try updaterController.updater.start()
            print("Sparkle: Updater started successfully")
        } catch {
            print("Sparkle: Failed to start updater - \(error.localizedDescription)")
        }
    }
    
    // MARK: - SPUUpdaterDelegate
    
    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        print("Sparkle: Successfully loaded appcast")
    }
    
    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        print("Sparkle: No update found - \(error.localizedDescription)")
    }
    
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        print("Sparkle: Update aborted - \(error.localizedDescription)")
    }
    
    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        print("Sparkle: Failed to download update - \(error.localizedDescription)")
    }
}