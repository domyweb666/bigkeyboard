import UIKit

/// 跟著輸入框走的外觀：深淺色、換行鍵文字、鍵面（email、網址、數字欄）。
extension KeyboardViewController {
    /// 輸入框要求深色鍵盤 → 強制深色；否則跟系統。換行鍵依輸入框的 returnKeyType 顯示文字。
    func applyHostTraits() {
        let wantsDark = textDocumentProxy.keyboardAppearance == .dark
        view.overrideUserInterfaceStyle = wantsDark ? .dark : .unspecified
        keyboardView.setReturnLabel(Self.returnLabel(for: textDocumentProxy.returnKeyType))
    }

    /// 輸入框種類 → 該換哪張鍵面（nil = 照平常記住的）、英文底排用哪一種。
    /// 電話欄、密碼欄系統會強制換回原生鍵盤，輪不到這裡
    static func hostPlan(for type: UIKeyboardType) -> (mode: KeyboardMode?, field: HostField) {
        switch type {
        case .emailAddress: return (KeyboardMode.english, HostField.email)
        case .URL: return (KeyboardMode.english, HostField.url)
        case .numberPad, .decimalPad, .asciiCapableNumberPad: return (KeyboardMode.numpad, HostField.normal)
        default: return (nil, HostField.normal)
        }
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
