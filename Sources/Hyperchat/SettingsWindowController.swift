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
    
    var body: some View {
        HStack(spacing: 12) {
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
            
            // Temporary placeholder - colored circle with first letter
            ZStack {
                Circle()
                    .fill(serviceColor(for: service.id))
                    .frame(width: 32, height: 32)
                
                Text(String(service.name.prefix(1)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
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
                
                Text("Customize your Hyperchat experience")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
                                    onReorder: { viewModel.settingsManager.reorderServices(viewModel.services) }
                                ))
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
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
                }
                .padding(.vertical, 20)
            }
        }
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Drag and Drop Delegate

struct ServiceDropDelegate: DropDelegate {
    let service: AIService
    @Binding var services: [AIService]
    @Binding var draggedService: AIService?
    let onReorder: () -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedService = draggedService else { return false }
        
        let fromIndex = services.firstIndex(where: { $0.id == draggedService.id })
        let toIndex = services.firstIndex(where: { $0.id == service.id })
        
        if let from = fromIndex, let to = toIndex, from != to {
            withAnimation {
                services.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
            onReorder()
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
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Hyperchat Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        self.init(window: window)
        
        let contentView = NSHostingView(rootView: SettingsView())
        window.contentView = contentView
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}