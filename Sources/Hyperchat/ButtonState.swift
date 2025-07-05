import Foundation

class ButtonState: ObservableObject {
    @Published var isEnabled: Bool
    
    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}