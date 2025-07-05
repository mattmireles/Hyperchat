import Foundation

class SettingsManager {
    static let shared = SettingsManager()
    
    private let userDefaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private let servicesKey = "com.hyperchat.services"
    private let floatingButtonEnabledKey = "com.hyperchat.floatingButtonEnabled"
    
    private init() {}
    
    // MARK: - Service Management
    
    func getServices() -> [AIService] {
        // Try to load saved services
        if let savedData = userDefaults.data(forKey: servicesKey),
           let savedServices = try? JSONDecoder().decode([AIService].self, from: savedData) {
            return savedServices
        }
        
        // Return default services if none saved
        return defaultServices
    }
    
    func saveServices(_ services: [AIService]) {
        if let encoded = try? JSONEncoder().encode(services) {
            userDefaults.set(encoded, forKey: servicesKey)
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
}

// MARK: - Notifications

extension Notification.Name {
    static let floatingButtonToggled = Notification.Name("com.hyperchat.floatingButtonToggled")
    static let servicesUpdated = Notification.Name("com.hyperchat.servicesUpdated")
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
        case id, name, iconName, activationMethod, enabled, order
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        iconName = try container.decode(String.self, forKey: .iconName)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        order = try container.decode(Int.self, forKey: .order)
        
        // For activation method, we'll use the default from the service configurations
        // since it's complex to encode/decode
        switch id {
        case "google", "perplexity", "chatgpt":
            activationMethod = .urlParameter(baseURL: "placeholder", parameter: "placeholder")
        case "claude":
            activationMethod = .clipboardPaste(baseURL: "placeholder")
        default:
            activationMethod = .urlParameter(baseURL: "placeholder", parameter: "placeholder")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(order, forKey: .order)
        // Don't encode activationMethod as it's derived from id
    }
}