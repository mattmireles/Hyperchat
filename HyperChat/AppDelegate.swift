import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingButtonManager: FloatingButtonManager?
    var overlayController: OverlayController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        overlayController = OverlayController()
        floatingButtonManager = FloatingButtonManager()
        floatingButtonManager?.overlayController = overlayController
        floatingButtonManager?.showFloatingButton()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
} 