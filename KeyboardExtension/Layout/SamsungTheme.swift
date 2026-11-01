import UIKit

/// 三星鍵盤的尺寸與配色，照截圖量出來的常數。寫死，不做設定項。
enum SamsungTheme {
    /// 鍵盤總高度佔螢幕高度的比例（含工具列帶；不含系統在下方另加的地球／麥克風排）
    static let keyboardHeightRatio: CGFloat = 0.36
    /// 工具列帶（候選字）佔鍵盤總高的比例
    static let toolbarHeightRatio: CGFloat = 0.11

    // 鍵距：三星比 iOS 原生緊
    static let keyGap: CGFloat = 5
    static let rowGap: CGFloat = 7
    static let sideInset: CGFloat = 4
    static let keyCornerRadius: CGFloat = 7

    // 鍵帽字：三星字大
    static let keyFontSize: CGFloat = 26
    static let functionFontSize: CGFloat = 19
    static let hintFontSize: CGFloat = 11
    static let footFontSize: CGFloat = 11
    static let previewFontSize: CGFloat = 40
    static let candidateFontSize: CGFloat = 22
    static let iconPointSize: CGFloat = 20

    static let longPressSeconds: TimeInterval = 0.4
    /// 刪除鍵按住後的連刪間隔
    static let repeatInterval: TimeInterval = 0.08

    static let background = UIColor(red: 0.878, green: 0.871, blue: 0.847, alpha: 1) // #E0DED8
    static let keyWhite = UIColor.white
    static let keyGray = UIColor(red: 0.78, green: 0.76, blue: 0.73, alpha: 1)
    static let keyPressed = UIColor(red: 0.90, green: 0.89, blue: 0.87, alpha: 1)
    static let keyText = UIColor.black
    static let hintText = UIColor(white: 0.55, alpha: 1)

    static func keyboardHeight(for screen: UIScreen) -> CGFloat {
        (screen.bounds.height * keyboardHeightRatio).rounded()
    }
}
