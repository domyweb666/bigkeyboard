import Foundation

/// 按鍵震動：預設關（跟系統鍵盤一樣），在 App 設定頁打開。
/// 存在 App Group，鍵盤要開完全取用才讀得到；讀不到就是關
enum KeyHapticSetting {
    static let storageKey = "keyHaptics"

    static var isOn: Bool {
        SpaceKeySetting.defaults?.bool(forKey: storageKey) ?? false
    }
}
