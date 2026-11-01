import UIKit

/// 打開豆鍵在「設定」app 裡的那一頁（加入鍵盤後，裡面有「鍵盤 → 允許完全取用」）
@MainActor
enum AppSettings {
    static func open() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
