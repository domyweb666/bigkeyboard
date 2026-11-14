import Foundation

// 蔬菜家族共用元素（規格：《蔬菜家族 App 共用基本元素規格》2026-11-14）。
// 先做在豆鍵裡，等第二個 app 要用時再搬成獨立的 VeggieKit 套件；搬的時候只帶走 App/Veggie/ 這個資料夾，
// 每個 app 改的只有下面的 VeggieConfig.current。

/// 每個 app 一份的設定檔。值是 nil 的那一列在設定頁整列隱藏
struct VeggieConfig {
    let name: String
    let slug: String
    let tagline: String
    /// App Store Connect → App 資訊 → Apple ID（一串數字）。填了才出現評分、分享
    let appStoreID: String?
    /// 意見回饋的收件信箱（全系列共用一個）。填了才出現意見回饋
    let supportEmail: String?
    /// 用在「所有詞都會刪除」「將匯入 12 個詞」
    let dataNoun: String
    /// 用在「將匯入 12 個詞」的量詞
    let dataCounter: String
    /// 清除所有資料會刪掉什麼，用在「所有詞和剪貼簿都會刪除」
    let resetScope: String
    /// 隱私權政策網頁（要跟 App Store Connect 填的同一頁）。nil 時那一列隱藏
    let privacyURL: URL?

    var appStoreURL: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)") }
    }

    var writeReviewURL: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }

    /// 「豆鍵 1.0 (73)」
    var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return "\(name) \(version) (\(build))"
    }
}

extension VeggieConfig {
    static let current = VeggieConfig(
        name: "豆鍵",
        slug: "doujian",
        tagline: "字大鍵緊，少按錯的注音鍵盤",
        appStoreID: "6829152938",
        supportEmail: "charlie@domyweb.org",
        dataNoun: "詞",
        dataCounter: "個",
        resetScope: "所有詞和剪貼簿",
        // 豆鍵上架時的網頁在 /tools/bigkeyboard/，不是規格寫的 /apps/{slug}/
        privacyURL: URL(string: "https://domyweb.org/tools/bigkeyboard/privacy/")
    )
}

/// 蔬菜家族的其他 app。豆鍵預設不連網，只用這份內建清單（規格是讀網路上的 apps.json；2026-11-14 多米選內建）。
/// 沒有 App Store ID 也沒有網頁的不顯示；一個都沒有時，設定頁整列隱藏
struct VeggieApp: Identifiable {
    let slug: String
    let name: String
    let tagline: String
    let appStoreID: String?
    let webURL: URL?

    var id: String {
        slug
    }

    var link: URL? {
        if let appStoreID {
            return URL(string: "https://apps.apple.com/app/id\(appStoreID)")
        }
        return webURL
    }

    static let family: [VeggieApp] = [
        VeggieApp(slug: "qieji", name: "茄記", tagline: "想到就記", appStoreID: "6829151838", webURL: nil),
        VeggieApp(slug: "doujia", name: "豆莢", tagline: "番茄鐘", appStoreID: nil, webURL: nil),
    ]

    /// 設定頁要列出來的：有連結、而且不是自己
    static var others: [VeggieApp] {
        family.filter { $0.slug != VeggieConfig.current.slug && $0.link != nil }
    }
}

/// 共用文案庫：全系列同一個東西叫同一個名字
enum VeggieText {
    static let appearance = "外觀"
    static let appearanceSystem = "跟隨系統"
    static let appearanceLight = "淺色"
    static let appearanceDark = "深色"
    static let sync = "iCloud 同步"
    static let export = "匯出資料"
    static let importData = "匯入資料"
    static let reset = "清除所有資料"
    static let restore = "恢復購買"
    static let feedback = "意見回饋"
    static let rate = "在 App Store 給我們評分"
    static let share = "分享給朋友"
    static let whatsNew = "新功能"
    static let family = "蔬菜家族的其他 app"
    static let privacy = "隱私權政策"
    static let licenses = "開源授權"
    static let resetTitle = "要清除所有資料嗎？"
    static let resetConfirm = "刪除所有資料"
    static let restoreSuccess = "已恢復你的購買"
    static let restoreNone = "沒有找到購買紀錄"
    static let diagnosticsCopied = "已複製版本資訊"
    static let errorGeneric = "出了點問題，請再試一次"
    static let madeBy = "Made by DOMYWEB"

    static func resetBody(_ scope: String) -> String {
        "\(scope)都會刪除，無法復原。建議先匯出一份備份。"
    }

    static func importPreview(_ count: Int, counter: String, noun: String) -> String {
        "將匯入 \(count) \(counter)\(noun)"
    }
}
