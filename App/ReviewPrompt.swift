import Foundation

/// 評分提示：什麼時候可以請系統跳評分視窗。設計見 .uiux/08-上架.md「評分提示」。
/// 只在 App 的字典頁問，不在鍵盤裡問（會打斷正在別的 app 打的字）。
/// 跳不跳、跳幾次最後由系統決定（同一人一年有上限），這裡只管「這時候問合不合適」
@MainActor
enum ReviewPrompt {
    /// 自動添加的詞至少這麼多個：代表鍵盤真的用了一陣子（門檻是猜的，上架後看評分數再調）
    static let minAutoWords = 10
    /// 第一次打開 App 後至少過這麼多天：不在安裝當天、設定流程裡問
    static let minDaysSinceFirstOpen = 3
    /// 兩次請求至少隔這麼多天：連著兩個小改版不要各用掉一次
    static let minDaysBetweenAsks = 90

    /// App Store Connect → App 資訊 → Apple ID（一串數字）。填了「使用說明」才會出現「到 App Store 寫評論」
    static let appStoreID: String? = nil

    private static let firstOpenKey = "review.firstOpen"
    private static let lastAskedVersionKey = "review.lastAskedVersion"
    private static let lastAskedDateKey = "review.lastAskedDate"

    /// 這次打開 App 出過錯或剛買了主題：這次都不問
    private static var heldThisLaunch = false

    private static var defaults: UserDefaults {
        .standard
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// App 啟動時呼叫：第一次打開的日期只記一次
    static func recordLaunch() {
        if defaults.object(forKey: firstOpenKey) == nil {
            defaults.set(Date.now, forKey: firstOpenKey)
        }
    }

    /// 購買失敗、回復失敗、字典存不進去、剛買完主題時呼叫：這次打開 App 都不問
    static func hold() {
        heldThisLaunch = true
    }

    /// 現在問合不合適。keyboardSeen 是 nil 代表鍵盤沒寫過字典（沒開完全取用），不問
    static func shouldAsk(autoWords: Int, keyboardSeen: Date?, now: Date = .now) -> Bool {
        guard !heldThisLaunch, keyboardSeen != nil, autoWords >= minAutoWords,
              let firstOpen = defaults.object(forKey: firstOpenKey) as? Date,
              days(from: firstOpen, to: now) >= minDaysSinceFirstOpen
        else { return false }
        if defaults.string(forKey: lastAskedVersionKey) == appVersion {
            return false
        }
        let last = defaults.object(forKey: lastAskedDateKey) as? Date
        if let last, days(from: last, to: now) < minDaysBetweenAsks {
            return false
        }
        return true
    }

    /// 請系統跳評分視窗之前呼叫：記下這個版本問過了
    static func markAsked(now: Date = .now) {
        defaults.set(appVersion, forKey: lastAskedVersionKey)
        defaults.set(now, forKey: lastAskedDateKey)
    }

    /// App Store 的寫評論頁；沒填 App Store ID 時是 nil
    static var writeReviewURL: URL? {
        guard let appStoreID else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    private static func days(from start: Date, to end: Date) -> Int {
        Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
    }
}
