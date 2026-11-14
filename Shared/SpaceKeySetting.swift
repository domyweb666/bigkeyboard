import Foundation

/// 空白鍵在注音還沒打聲調時做什麼：預設當一聲；App 設定可以改成照舊送第一個候選。
/// 存在 App Group，鍵盤要開完全取用才讀得到；讀不到就用預設（當一聲）。
enum SpaceKeySetting {
    static let storageKey = "spaceSelectsFirstCandidate"
    static let defaults = UserDefaults(suiteName: UserDictionary.groupID)

    /// true：空白鍵一律送第一個候選；false（預設）：沒打聲調的音按空白當一聲
    static var selectsFirstCandidate: Bool {
        defaults?.bool(forKey: storageKey) ?? false
    }
}
