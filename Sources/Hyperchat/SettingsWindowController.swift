import Cocoa
import SwiftUI

// MARK: - Settings Layout Constants

private enum SettingsLayout {
    static let serviceRowCornerRadius: CGFloat = 8
    static let sectionHorizontalPadding: CGFloat = 16
    static let floatingButtonRowPadding: CGFloat = 12
    static let floatingButtonBackgroundOpacity: Double = 0.05
}

// MARK: - Settings View Model

class SettingsViewModel: ObservableObject {
    @Published var services: [AIService] = []
    @Published var isFloatingButtonEnabled: Bool = true
    
    let settingsManager = SettingsManager.shared
    
    init() {
        loadSettings()
        
        // Listen for service updates to refresh the UI
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleServicesUpdated),
            name: .servicesUpdated,
            object: nil
        )
        
        // Listen for favicon updates separately to avoid full reload
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFaviconUpdated),
            name: .faviconUpdated,
            object: nil
        )
        
        // Prefetch missing favicons for all services
        prefetchMissingFavicons()
    }
    
    func loadSettings() {
        services = settingsManager.getServices().sorted(by: { $0.order < $1.order })
        isFloatingButtonEnabled = settingsManager.isFloatingButtonEnabled
    }
    
    func toggleService(at index: Int) {
        services[index].enabled.toggle()
        settingsManager.updateService(services[index])
        NotificationCenter.default.post(name: .servicesUpdated, object: nil)
    }
    
    func toggleFloatingButton() {
        isFloatingButtonEnabled.toggle()
        settingsManager.isFloatingButtonEnabled = isFloatingButtonEnabled
    }
    
    func moveService(from source: IndexSet, to destination: Int) {
        services.move(fromOffsets: source, toOffset: destination)
        settingsManager.reorderServices(services)
        NotificationCenter.default.post(name: .servicesUpdated, object: nil)
    }
    
    @objc private func handleServicesUpdated() {
        print("📱 Settings: Received servicesUpdated notification, reloading...")
        loadSettings()
    }
    
    @objc private func handleFaviconUpdated(_ notification: Notification) {
        guard let serviceId = notification.object as? String else { return }
        
        print("🖼️ Settings: Received faviconUpdated notification for service: \(serviceId)")
        
        // Update only the specific service's favicon without reloading everything
        if let index = services.firstIndex(where: { $0.id == serviceId }) {
            let updatedServices = settingsManager.getServices()
            if let updatedService = updatedServices.first(where: { $0.id == serviceId }) {
                services[index].faviconURL = updatedService.faviconURL
                print("✅ Updated favicon URL for \(serviceId): \(updatedService.faviconURL?.absoluteString ?? "nil")")
            }
        }
    }
    
    /// Prefetches favicons for all services that don't have one.
    ///
    /// Called during init to ensure all services show icons in settings,
    /// even if they've never been enabled.
    ///
    /// Process:
    /// 1. Check each service for missing favicon
    /// 2. Use FaviconFetcher to load favicon without WebView
    /// 3. Updates are handled via faviconUpdated notifications
    private func prefetchMissingFavicons() {
        print("🔍 Prefetching missing favicons for all services...")
        
        for service in services {
            if service.faviconURL == nil {
                print("🔄 Fetching favicon for \(service.name)...")
                
                // Use known URLs first for better reliability
                FaviconFetcher.shared.fetchFaviconWithKnownURL(for: service) { url in
                    if let url = url {
                        print("✅ Prefetched favicon for \(service.name): \(url)")
                    } else {
                        print("⚠️ Could not prefetch favicon for \(service.name)")
                    }
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Service Row View

// Helper function for service colors
private func serviceColor(for serviceId: String) -> Color {
    switch serviceId {
    case "chatgpt":
        return Color(red: 0.0, green: 0.7, blue: 0.5)  // Teal
    case "claude":
        return Color(red: 0.6, green: 0.4, blue: 0.8)  // Purple
    case "perplexity":
        return Color(red: 0.2, green: 0.5, blue: 0.9)  // Blue
    case "google":
        return Color(red: 0.9, green: 0.3, blue: 0.2)  // Red
    default:
        return Color.gray
    }
}

struct ServiceRowView: View {
    let service: AIService
    let isEnabled: Bool
    let onToggle: () -> Void
    
    @State private var isHovering = false
    
    private var coloredCircleFallback: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(isEnabled ? 0.3 : 0.15))
                .frame(width: 32, height: 32)
            
            Text(String(service.name.prefix(1)))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.primary.opacity(isEnabled ? 0.8 : 0.5))
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Drag handle indicator
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary.opacity(0.6))
                .frame(width: 20)
            
            // Service icon - TODO: Add actual icons later
            /*
            Image(service.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            */
            
            // Service icon - favicon if available, colored circle as fallback
            Group {
                if let faviconURL = service.faviconURL {
                    let _ = print("🖼️ Loading favicon for \(service.name): \(faviconURL)")
                    AsyncImage(url: faviconURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .saturation(0) // Remove all color saturation for monochrome effect
                            .opacity(isEnabled ? 0.8 : 0.5) // Adjust opacity based on enabled state
                    } placeholder: {
                        // Fallback to monochrome circle while loading
                        coloredCircleFallback
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    let _ = print("⚪ No favicon URL for \(service.name), using colored circle")
                    // No favicon URL, use colored circle
                    coloredCircleFallback
                }
            }
            
            // Service name
            Text(service.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isEnabled ? .primary : .secondary)
            
            Spacer()
            
            // Toggle switch
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: SettingsLayout.serviceRowCornerRadius)
                .fill(isHovering ? Color.gray.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var draggedService: AIService?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Personalize Hyperchat to suite you")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 24) {
                    // Floating Button Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Floating Button")
                            .font(.headline)
                            .padding(.horizontal, 16)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Show Floating Button")
                                    .font(.system(size: 14, weight: .medium))
                                
                                Text("Access Hyperchat from anywhere with a floating button")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $viewModel.isFloatingButtonEnabled)
                                .toggleStyle(SwitchToggleStyle())
                                .labelsHidden()
                                .onChange(of: viewModel.isFloatingButtonEnabled) { oldValue, newValue in
                                    viewModel.toggleFloatingButton()
                                }
                        }
                        .padding(.horizontal, SettingsLayout.sectionHorizontalPadding)
                        .padding(.vertical, SettingsLayout.floatingButtonRowPadding)
                        .background(
                            RoundedRectangle(cornerRadius: SettingsLayout.serviceRowCornerRadius)
                                .fill(Color.gray.opacity(SettingsLayout.floatingButtonBackgroundOpacity))
                        )
                        .padding(.horizontal, SettingsLayout.sectionHorizontalPadding)
                    }
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Services Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Services")
                            .font(.headline)
                            .padding(.horizontal, 16)
                        
                        Text("Drag to reorder • Toggle to enable/disable")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                        
                        // Services list with drag and drop
                        VStack(spacing: 4) {
                            ForEach(Array(viewModel.services.enumerated()), id: \.element.id) { index, service in
                                ServiceRowView(
                                    service: service,
                                    isEnabled: service.enabled,
                                    onToggle: {
                                        viewModel.toggleService(at: index)
                                    }
                                )
                                .onDrag {
                                    self.draggedService = service
                                    return NSItemProvider(object: service.id as NSString)
                                }
                                .onDrop(of: [.text], delegate: ServiceDropDelegate(
                                    service: service,
                                    services: $viewModel.services,
                                    draggedService: $draggedService,
                                    viewModel: viewModel
                                ))
                            }
                        }
                        .padding(.horizontal, 8)
                    }
            }
            .padding(.vertical, 20)
        }
        .frame(width: 400, height: 520)
        .background(Color.clear)
    }
}

// MARK: - Drag and Drop Delegate

struct ServiceDropDelegate: DropDelegate {
    let service: AIService
    @Binding var services: [AIService]
    @Binding var draggedService: AIService?
    let viewModel: SettingsViewModel
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedService = draggedService else { return false }
        
        let fromIndex = services.firstIndex(where: { $0.id == draggedService.id })
        let toIndex = services.firstIndex(where: { $0.id == service.id })
        
        if let from = fromIndex, let to = toIndex, from != to {
            // Calculate the destination index for moveService
            let destination = to > from ? to + 1 : to
            
            // Use the viewModel's moveService method which handles everything properly
            viewModel.moveService(from: IndexSet(integer: from), to: destination)
        }
        
        self.draggedService = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Optional: Add visual feedback during drag
    }
}

// MARK: - Settings Window Controller

class SettingsWindowController: NSWindowController {
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Hyperchat Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor.clear
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        
        self.init(window: window)
        
        let contentView = NSHostingView(rootView: SettingsView())
        
        // Create container view to hold both background and content
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 520))
        containerView.autoresizingMask = [.width, .height]
        
        // Add visual effect background to settings window
        let backgroundEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 400, height: 520))
        backgroundEffectView.material = .hudWindow
        backgroundEffectView.blendingMode = .behindWindow
        backgroundEffectView.state = .active
        backgroundEffectView.autoresizingMask = [.width, .height]
        
        containerView.addSubview(backgroundEffectView)
        containerView.addSubview(contentView)
        
        // Set content view constraints
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: containerView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        window.contentView = containerView
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}