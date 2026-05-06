import Foundation

struct DeviceIDProvider {
    private enum Key {
        static let deviceID = "victoryFairyDeviceID"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var deviceID: String {
        if let saved = defaults.string(forKey: Key.deviceID), !saved.isEmpty {
            return saved
        }
        // MVP에서는 UserDefaults에 저장하므로 앱 삭제 후에는 새 ID가 발급될 수 있습니다.
        let generated = UUID().uuidString
        defaults.set(generated, forKey: Key.deviceID)
        return generated
    }
}
