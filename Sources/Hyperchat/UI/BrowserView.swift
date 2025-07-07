import AppKit
import WebKit
import SwiftUI


class BrowserView: NSView {
    let webView: WKWebView
    let urlField: NSTextField
    let backButton: NSButton
    let forwardButton: NSButton
    let reloadButton: NSButton
    let copyButton: NSButton
    let isFirstService: Bool
    
    var topToolbar: NSStackView!
    
    // SwiftUI button views
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
        
        // BrowserView is now a plain content container - no visual styling
        // Visual appearance is handled by parent browserContainer in OverlayController
        
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLayout() {
        // URL field configuration
        urlField.isEditable = true
        urlField.cell?.sendsActionOnEndEditing = true
        urlField.placeholderString = "Enter URL..."
        urlField.font = NSFont.systemFont(ofSize: 11)
        urlField.bezelStyle = .roundedBezel
        urlField.focusRingType = .none
        urlField.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3)
        urlField.textColor = NSColor.secondaryLabelColor.withAlphaComponent(0.4)
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
            trafficLightSpacer.widthAnchor.constraint(equalToConstant: 70).isActive = true
            
            // Note: Button views will be set up by the controller
            topToolbar = NSStackView(views: [trafficLightSpacer, flexibleSpacer])
        } else {
            // Standard toolbar for other services
            topToolbar = NSStackView(views: [flexibleSpacer])
        }
        topToolbar.orientation = .horizontal
        topToolbar.spacing = 6
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
            topToolbar.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            topToolbar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            topToolbar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            topToolbar.heightAnchor.constraint(equalToConstant: 32),
            
            // WebView fills remaining space
            webView.topAnchor.constraint(equalTo: topToolbar.bottomAnchor, constant: 8),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
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
            urlField.widthAnchor.constraint(equalToConstant: 180),
            urlField.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        for buttonView in [backButtonView, forwardButtonView, reloadButtonView, copyButtonView] {
            buttonView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            NSLayoutConstraint.activate([
                buttonView.widthAnchor.constraint(equalToConstant: 20),
                buttonView.heightAnchor.constraint(equalToConstant: 20)
            ])
        }
    }
    
}