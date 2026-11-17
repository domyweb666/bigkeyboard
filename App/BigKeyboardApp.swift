import CoreText
import SwiftUI

@main
struct BigKeyboardApp: App {
    init() {
        ReadingLookup.warmUp()
        Self.registerThemeFonts()
        ThemePurchases.listenForUpdates()
        // 要在 recordLaunch 之前：靠「第一次打開」的紀錄分出新安裝和更新
        WhatsNew.prepare()
        ReviewPrompt.recordLaunch()
        DictionarySync.start()
    }

    /// 主題字體只放在鍵盤擴充裡一份；主題頁要用同一套字顯示主題名稱，從擴充借來註冊
    private static func registerThemeFonts() {
        let appex = Bundle.main.builtInPlugInsURL?.appendingPathComponent("KeyboardExtension.appex")
        guard let appex else { return }
        let urls = KeyboardTheme.fontFiles.map { appex.appendingPathComponent($0) }
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
