import Foundation

class SettingsManager {
    static let shared = SettingsManager()
    
    private let userDefaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private let servicesKey = "com.hyperchat.services"
    private let floatingButtonEnabledKey = "com.hyperchat.floatingButtonEnabled"
    private let analyticsEnabledKey = "com.hyperchat.analyticsEnabled"
    
    private init() {}
    
    // MARK: - Service Management
    
    func getServices() -> [AIService] {
        // Try to load saved services
        if let savedData = userDefaults.data(forKey: servicesKey),
           let savedServices = try? JSONDecoder().decode([AIService].self, from: savedData) {
            
            // Log what we loaded from UserDefaults
            let sortedServices = savedServices.sorted { $0.order < $1.order }
            print("📖 SettingsManager.getServices() - Loaded from UserDefaults:")
            for service in sortedServices {
                print("   \(service.name): \(service.enabled ? "✅ enabled" : "❌ disabled") (order: \(service.order))")
            }
            
            return savedServices
        }
        
        // Return default services if none saved
        let sortedDefaults = defaultServices.sorted { $0.order < $1.order }
        print("📖 SettingsManager.getServices() - Using defaults (no saved data):")
        for service in sortedDefaults {
            print("   \(service.name): \(service.enabled ? "✅ enabled" : "❌ disabled") (order: \(service.order))")
        }
        
        return defaultServices
    }
    
    func saveServices(_ services: [AIService]) {
        // Log what we're about to save
        let sortedServices = services.sorted { $0.order < $1.order }
        print("💾 SettingsManager.saveServices() - Saving to UserDefaults:")
        for service in sortedServices {
            print("   \(service.name): \(service.enabled ? "✅ enabled" : "❌ disabled") (order: \(service.order))")
        }
        
        if let encoded = try? JSONEncoder().encode(services) {
            userDefaults.set(encoded, forKey: servicesKey)
            userDefaults.synchronize() // Force immediate write to disk
            print("💾 SettingsManager.saveServices() - Save completed successfully")
        } else {
            print("❌ SettingsManager.saveServices() - Failed to encode services")
        }
    }
    
    func updateService(_ service: AIService) {
        var services = getServices()
        if let index = services.firstIndex(where: { $0.id == service.id }) {
            services[index] = service
            saveServices(services)
        }
    }
    
    func reorderServices(_ services: [AIService]) {
        // Update order property based on array position
        var orderedServices = services
        for (index, _) in orderedServices.enumerated() {
            orderedServices[index].order = index
        }
        saveServices(orderedServices)
    }
    
    func updateServiceFavicon(serviceId: String, faviconURL: URL?) {
        var services = getServices()
        if let index = services.firstIndex(where: { $0.id == serviceId }) {
            services[index].faviconURL = faviconURL
            saveServices(services)
            
            // Post favicon-specific notification - don't trigger full UI reload
            NotificationCenter.default.post(name: .faviconUpdated, object: serviceId)
        }
    }
    
    // MARK: - Floating Button
    
    var isFloatingButtonEnabled: Bool {
        get {
            // Default to true if not set
            return userDefaults.object(forKey: floatingButtonEnabledKey) as? Bool ?? true
        }
        set {
            userDefaults.set(newValue, forKey: floatingButtonEnabledKey)
            NotificationCenter.default.post(name: .floatingButtonToggled, object: newValue)
        }
    }
    
    // MARK: - Analytics
    
    /// Whether analytics collection is enabled by the user.
    /// 
    /// Analytics is enabled by default to help improve the product.
    /// - Defaults to true (enabled by default)
    /// - Can be disabled at any time via settings
    /// - Triggers notification when changed for AnalyticsManager to respond
    var isAnalyticsEnabled: Bool {
        get {
            // Default to true - analytics is enabled by default
            return userDefaults.object(forKey: analyticsEnabledKey) as? Bool ?? true
        }
        set {
            let oldValue = isAnalyticsEnabled
            userDefaults.set(newValue, forKey: analyticsEnabledKey)
            userDefaults.synchronize() // Force immediate write
            
            // Only post notification if value actually changed
            if oldValue != newValue {
                NotificationCenter.default.post(name: .analyticsPreferenceChanged, object: newValue)
                print("📊 SettingsManager: Analytics preference changed to \(newValue)")
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let floatingButtonToggled = Notification.Name("com.hyperchat.floatingButtonToggled")
    static let servicesUpdated = Notification.Name("com.hyperchat.servicesUpdated")
    static let reloadOverlayUI = Notification.Name("com.hyperchat.reloadOverlayUI")
    static let faviconUpdated = Notification.Name("com.hyperchat.faviconUpdated")
    static let analyticsPreferenceChanged = Notification.Name("com.hyperchat.analyticsPreferenceChanged")
}

// MARK: - AIService Codable Extension

/// Makes AIService persistable via JSON encoding.
///
/// Encoding strategy:
/// - Only UI-relevant properties are saved
/// - ActivationMethod is NOT saved (reconstructed)
/// - This keeps settings file small and readable
///
/// The activation method is derived from service ID
/// to avoid complex enum encoding and maintainability.
extension AIService: Codable {
    /// Properties to encode/decode
    enum CodingKeys: String, CodingKey {
        case id, name, iconName, activationMethod, enabled, order, faviconURL
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        iconName = try container.decode(String.self, forKey: .iconName)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        order = try container.decode(Int.self, forKey: .order)
        faviconURL = try container.decodeIfPresent(URL.self, forKey: .faviconURL)
        
        // For activation method, use the actual configurations from ServiceConfigurations
        switch id {
        case "google":
            activationMethod = .urlParameter(baseURL: ServiceConfigurations.google.baseURL, parameter: ServiceConfigurations.google.queryParam)
        case "perplexity":
            activationMethod = .urlParameter(baseURL: ServiceConfigurations.perplexity.baseURL, parameter: ServiceConfigurations.perplexity.queryParam)
        case "chatgpt":
            activationMethod = .urlParameter(baseURL: ServiceConfigurations.chatGPT.baseURL, parameter: ServiceConfigurations.chatGPT.queryParam)
        case "claude":
            activationMethod = .clipboardPaste(baseURL: ServiceConfigurations.claude.baseURL)
        default:
            // Fallback to URL parameter method
            activationMethod = .urlParameter(baseURL: "https://\(id).com", parameter: "q")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(order, forKey: .order)
        try container.encodeIfPresent(faviconURL, forKey: .faviconURL)
        // Don't encode activationMethod as it's derived from id
    }
}