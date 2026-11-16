import Foundation

/// 按鍵聲要哪一種，在 App 設定頁選。
/// 存在 App Group，鍵盤要開完全取用才讀得到；讀不到就是系統預設
enum KeySoundStyle: String, CaseIterable, Identifiable {
    /// 系統的按鍵聲（跟著「設定 → 聲音與觸覺 → 鍵盤回饋 → 聲音」）
    case system
    /// 字母、刪除、功能鍵各一種（系統鍵盤的那三種聲音）
    case distinct
    /// 不出聲
    case off

    static let storageKey = "keySoundStyle"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system: "系統預設"
        case .distinct: "三種按鍵聲"
        case .off: "關閉"
        }
    }

    static var saved: KeySoundStyle {
        SpaceKeySetting.defaults?.string(forKey: storageKey).flatMap { KeySoundStyle(rawValue: $0) } ?? .system
    }
}
