/// ButtonState.swift - Observable Button Enable/Disable State
///
/// This file defines a simple observable object for managing button enabled states.
/// It allows SwiftUI views to reactively update when button states change.
///
/// Key responsibilities:
/// - Holds enabled/disabled state for a button
/// - Publishes changes for SwiftUI observation
/// - Provides type-safe state management
///
/// Related files:
/// - `GradientToolbarButton.swift`: Observes this state for visual updates
/// - `BrowserViewController.swift`: Creates and updates button states
///
/// Architecture:
/// - ObservableObject for SwiftUI integration
/// - @Published for automatic change notifications
/// - Reference type for shared state

import Foundation

/// Observable state container for button enable/disable.
///
/// Created by:
/// - `BrowserViewController` for navigation buttons
///
/// Used by:
/// - `GradientToolbarButton` to determine visual state
///
/// Example:
/// - Back button disabled when no history
/// - Forward button disabled when no forward history
/// - Reload always enabled
///
/// The @Published wrapper ensures SwiftUI views
/// automatically update when isEnabled changes.
class ButtonState: ObservableObject {
    /// Whether the button is currently enabled
    @Published var isEnabled: Bool
    
    /// Creates button state with initial enabled value.
    ///
    /// - Parameter isEnabled: Initial enabled state
    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}