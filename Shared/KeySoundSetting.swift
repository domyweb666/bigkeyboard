import Foundation

/// 按鍵聲要哪一種，在 App 設定頁選。
/// 存在 App Group，鍵盤要開完全取用才讀得到；讀不到就是跟隨 iPhone 設定
enum KeySoundStyle: String, CaseIterable, Identifiable {
    /// 系統的按鍵聲：iPhone 的「設定 → 聲音與觸覺 → 鍵盤回饋 → 聲音」開著才響，關著就不出聲。
    /// 選單上原本叫「系統預設」，2026-11-17 多米選了它卻沒聲音，改成看名字就知道是跟著 iPhone 的開關
    case system
    /// 字母、刪除、功能鍵各一種（系統鍵盤的那三種聲音）
    case distinct
    /// 機械鍵盤聲音包：有「喀」一聲的
    case crisp
    /// 機械鍵盤聲音包：有段落感、比較悶的
    case thick
    /// 機械鍵盤聲音包：1986 年的老鍵盤
    case vintage
    /// 不出聲
    case off

    static let storageKey = "keySoundStyle"

    var id: String {
        rawValue
    }

    /// 選單上的名字。聲音包照聽起來的感覺取名：不知道錄的是哪家的軸，也不拿別人的商標當選項名
    var title: String {
        switch self {
        case .system: "跟隨 iPhone 設定"
        case .distinct: "三種按鍵聲"
        case .crisp: "機械鍵盤・清脆"
        case .thick: "機械鍵盤・厚實"
        case .vintage: "機械鍵盤・復古"
        case .off: "關閉"
        }
    }

    /// 聲音包的音檔檔名用哪個字（keysound-<這個字>-01.wav）；不是聲音包為 nil
    var pack: String? {
        switch self {
        case .crisp: "clicky"
        case .thick: "tactile"
        case .vintage: "vintage"
        case .system, .distinct, .off: nil
        }
    }

    static var saved: KeySoundStyle {
        SpaceKeySetting.defaults?.string(forKey: storageKey).flatMap { KeySoundStyle(rawValue: $0) } ?? .system
    }
}
