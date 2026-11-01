import UIKit

/// 跟著輸入框走的外觀：深淺色、換行鍵文字。
extension KeyboardViewController {
    /// 輸入框要求深色鍵盤 → 強制深色；否則跟系統。換行鍵依輸入框的 returnKeyType 顯示文字。
    func applyHostTraits() {
        let wantsDark = textDocumentProxy.keyboardAppearance == .dark
        view.overrideUserInterfaceStyle = wantsDark ? .dark : .unspecified
        keyboardView.setReturnLabel(Self.returnLabel(for: textDocumentProxy.returnKeyType))
    }

    static func returnLabel(for type: UIReturnKeyType?) -> String? {
        switch type {
        case .search, .google, .yahoo: "搜尋"
        case .send: "傳送"
        case .go: "前往"
        case .done: "完成"
        case .next: "下一個"
        case .join: "加入"
        case .route: "路線"
        case .continue: "繼續"
        case .emergencyCall: "緊急"
        default: nil
        }
    }
}
