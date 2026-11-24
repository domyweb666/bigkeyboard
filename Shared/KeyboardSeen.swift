import Foundation

/// 鍵盤最後一次用到字典的時間（App 用來顯示「自動學習中」、決定要不要問評分）。
/// 以前寫在字典檔裡，每次叫出鍵盤都要為了它把整本字典重寫一遍（2026-11-25 手感審查 #1），改存 App Group 的設定。
/// 要開完全取用，鍵盤才寫得進去；沒開過就一直是 nil
enum KeyboardSeen {
    static let storageKey = "keyboardSeen"

    /// 鍵盤叫：記下現在
    static func mark() {
        SpaceKeySetting.defaults?.set(Date(), forKey: storageKey)
    }

    /// App 看：剛從舊版更新上來、鍵盤還沒叫出來過的，用字典檔裡舊的那個
    static func date(in file: UserDictionary.File) -> Date? {
        let saved = SpaceKeySetting.defaults?.object(forKey: storageKey) as? Date
        return [saved, file.keyboardSeen].compactMap { $0 }.max()
    }
}
