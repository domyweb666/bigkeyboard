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

    // 顏色：淺色照三星截圖；深色跟系統（或輸入框要求深色鍵盤時）切換
    static let background = dynamic(light: rgb(0xE0DED8), dark: rgb(0x1C1C1E))
    static let keyWhite = dynamic(light: .white, dark: rgb(0x3A3A3C))
    static let keyGray = dynamic(light: rgb(0xC7C2BA), dark: rgb(0x2A2A2C))
    static let keyPressed = dynamic(light: rgb(0xE6E3DE), dark: rgb(0x55555A))
    static let keyText = dynamic(light: .black, dark: .white)
    static let hintText = dynamic(light: UIColor(white: 0.55, alpha: 1), dark: UIColor(white: 0.62, alpha: 1))

    private static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }

    private static func rgb(_ hex: Int) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    static func keyboardHeight(for screen: UIScreen) -> CGFloat {
        (screen.bounds.height * keyboardHeightRatio).rounded()
    }
}
