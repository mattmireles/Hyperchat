/// BrowserView.swift - NSView-based Browser Interface for WebKit
///
/// This file implements the custom NSView that hosts a WKWebView with navigation controls.
/// It provides the visual layout for each AI service's browser interface, including
/// navigation buttons and URL field.
///
/// Key responsibilities:
/// - Creates NSView hierarchy for WebView and toolbar
/// - Manages layout constraints for responsive design
/// - Handles special layout for first service (Google)
/// - Integrates SwiftUI buttons via NSHostingView
/// - Provides rounded corners and visual styling
/// - Manages URL field appearance and behavior
///
/// Related files:
/// - `BrowserViewController.swift`: Creates and manages BrowserView instances
/// - `GradientToolbarButton.swift`: SwiftUI button component used in toolbar
/// - `ServiceManager.swift`: Creates BrowserView for each service
/// - `ContentView.swift`: Contains BrowserView instances in layout
///
/// Architecture:
/// - Pure NSView (not layer-backed) for WebKit compatibility
/// - NSStackView for toolbar layout with flexible spacing
/// - SwiftUI buttons hosted via NSHostingView
/// - Auto Layout constraints for responsive sizing

import AppKit
import WebKit
import SwiftUI

// MARK: - Layout Constants

/// Layout constants for browser view components.
private enum BrowserLayout {
    /// Toolbar dimensions
    static let toolbarHeight: CGFloat = 32
    static let toolbarTopPadding: CGFloat = 8
    static let toolbarHorizontalPadding: CGFloat = 8
    static let toolbarSpacing: CGFloat = 6
    static let toolbarBottomPadding: CGFloat = 8
    
    /// URL field dimensions
    static let urlFieldWidth: CGFloat = 180
    static let urlFieldHeight: CGFloat = 20
    static let urlFieldFontSize: CGFloat = 11
    static let urlFieldAlpha: CGFloat = 0.3
    static let urlFieldTextAlpha: CGFloat = 0.4
    
    /// Button dimensions
    static let buttonSize: CGFloat = 20
    
    /// Traffic light spacing (macOS window controls)
    static let trafficLightWidth: CGFloat = 70
    
    /// View styling
    static let viewCornerRadius: CGFloat = 8
}

/// Custom NSView that hosts WebView with navigation controls.
///
/// Created by:
/// - `BrowserViewController.init()` for each service
///
/// Layout structure:
/// - Top toolbar with navigation buttons and URL field
/// - WKWebView filling remaining space below toolbar
/// - Special handling for first service (traffic lights)
///
/// The view uses NSStackView for flexible toolbar layout
/// and integrates SwiftUI buttons via NSHostingView.
class BrowserView: NSView {
    /// The WebKit web view instance
    let webView: WKWebView
    
    /// URL text field showing current page URL
    let urlField: NSTextField
    
    /// Navigation button references (unused but kept for compatibility)
    let backButton: NSButton
    let forwardButton: NSButton
    let reloadButton: NSButton
    let copyButton: NSButton
    
    /// Whether this is the first service (needs traffic light space)
    let isFirstService: Bool
    
    /// Stack view containing toolbar buttons and URL field
    var topToolbar: NSStackView!
    
    // SwiftUI button views added by controller
    var backButtonView: NSHostingView<GradientToolbarButton>!
    var forwardButtonView: NSHostingView<GradientToolbarButton>!
    var reloadButtonView: NSHostingView<GradientToolbarButton>!
    var copyButtonView: NSHostingView<GradientToolbarButton>!
    
    init(webView: WKWebView, isFirstService: Bool = false) {
        self.webView = webView
        self.isFirstService = isFirstService
        
        // Create controls
        self.backButton = NSButton()
        self.forwardButton = NSButton()
        self.reloadButton = NSButton()
        self.copyButton = NSButton()
        self.urlField = NSTextField()
        
        super.init(frame: .zero)
        
        // Add visual styling
        self.wantsLayer = true
        self.layer?.cornerRadius = BrowserLayout.viewCornerRadius
        self.layer?.masksToBounds = true
        
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Sets up the view hierarchy and layout constraints.
    ///
    /// Called by:
    /// - `init()` during view creation
    ///
    /// Layout logic:
    /// 1. Configures URL field appearance
    /// 2. Creates toolbar with appropriate spacing
    /// 3. Adds traffic light spacer for first service
    /// 4. Sets up Auto Layout constraints
    ///
    /// The toolbar uses NSStackView for flexible layout
    /// that adapts to window resizing.
    private func setupLayout() {
        // URL field configuration
        urlField.isEditable = true
        urlField.cell?.sendsActionOnEndEditing = true
        urlField.placeholderString = "Enter URL..."
        urlField.font = NSFont.systemFont(ofSize: BrowserLayout.urlFieldFontSize)
        urlField.bezelStyle = .roundedBezel
        urlField.focusRingType = .none
        urlField.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(BrowserLayout.urlFieldAlpha)
        urlField.textColor = NSColor.secondaryLabelColor.withAlphaComponent(BrowserLayout.urlFieldTextAlpha)
        urlField.maximumNumberOfLines = 1
        urlField.lineBreakMode = .byTruncatingTail
        urlField.alignment = .left
        urlField.toolTip = ""
        
        // Create top toolbar - all services use same layout with flexible spacer
        let flexibleSpacer = NSView()
        flexibleSpacer.setContentHuggingPriority(.init(1), for: .horizontal)
        flexibleSpacer.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        
        let topToolbar: NSStackView
        if isFirstService {
            // For Google: add fixed spacing for traffic lights
            let trafficLightSpacer = NSView()
            trafficLightSpacer.widthAnchor.constraint(equalToConstant: BrowserLayout.trafficLightWidth).isActive = true
            
            // Note: Button views will be set up by the controller
            topToolbar = NSStackView(views: [trafficLightSpacer, flexibleSpacer])
        } else {
            // Standard toolbar for other services
            topToolbar = NSStackView(views: [flexibleSpacer])
        }
        topToolbar.orientation = .horizontal
        topToolbar.spacing = BrowserLayout.toolbarSpacing
        topToolbar.distribution = .fill
        topToolbar.alignment = .centerY
        
        // Add views
        addSubview(topToolbar)
        addSubview(webView)
        
        self.topToolbar = topToolbar
        
        // Layout constraints
        topToolbar.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Top toolbar with URL - add padding to show rounded corners
            topToolbar.topAnchor.constraint(equalTo: topAnchor, constant: BrowserLayout.toolbarTopPadding),
            topToolbar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: BrowserLayout.toolbarHorizontalPadding),
            topToolbar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -BrowserLayout.toolbarHorizontalPadding),
            topToolbar.heightAnchor.constraint(equalToConstant: BrowserLayout.toolbarHeight),
            
            // WebView fills remaining space
            webView.topAnchor.constraint(equalTo: topToolbar.bottomAnchor, constant: BrowserLayout.toolbarBottomPadding),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    /// Adds SwiftUI toolbar buttons to the view hierarchy.
    ///
    /// Called by:
    /// - `BrowserViewController.setupToolbarButtons()` after view loads
    ///
    /// Process:
    /// 1. Stores button view references
    /// 2. Adds buttons to toolbar in navigation order
    /// 3. Sets up size constraints for consistent appearance
    ///
    /// Button order: [traffic lights] back|forward|reload|url|copy
    ///
    /// - Parameters:
    ///   - backButtonView: SwiftUI back navigation button
    ///   - forwardButtonView: SwiftUI forward navigation button
    ///   - reloadButtonView: SwiftUI page reload button
    ///   - copyButtonView: SwiftUI URL copy button
    func setupToolbarButtons(_ backButtonView: NSHostingView<GradientToolbarButton>,
                             _ forwardButtonView: NSHostingView<GradientToolbarButton>,
                             _ reloadButtonView: NSHostingView<GradientToolbarButton>,
                             _ copyButtonView: NSHostingView<GradientToolbarButton>) {
        self.backButtonView = backButtonView
        self.forwardButtonView = forwardButtonView
        self.reloadButtonView = reloadButtonView
        self.copyButtonView = copyButtonView
        
        // Add buttons to toolbar in the correct order
        topToolbar.addArrangedSubview(backButtonView)
        topToolbar.addArrangedSubview(forwardButtonView)
        topToolbar.addArrangedSubview(reloadButtonView)
        topToolbar.addArrangedSubview(urlField)
        topToolbar.addArrangedSubview(copyButtonView)
        
        // Set constraints for buttons and URL field
        NSLayoutConstraint.activate([
            urlField.widthAnchor.constraint(equalToConstant: BrowserLayout.urlFieldWidth),
            urlField.heightAnchor.constraint(equalToConstant: BrowserLayout.urlFieldHeight)
        ])
        
        // Apply consistent sizing to all toolbar buttons
        // High hugging priority prevents buttons from stretching
        for buttonView in [backButtonView, forwardButtonView, reloadButtonView, copyButtonView] {
            buttonView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            NSLayoutConstraint.activate([
                buttonView.widthAnchor.constraint(equalToConstant: BrowserLayout.buttonSize),
                buttonView.heightAnchor.constraint(equalToConstant: BrowserLayout.buttonSize)
            ])
        }
    }
}