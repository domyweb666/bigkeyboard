import UIKit

/// 鍵盤的尺寸與配色常數。尺寸照三星截圖量；配色 2026-11-02 起改成跟 iOS 系統鍵盤底色搭的冷灰系。寫死，不做設定項。
enum SamsungTheme {
    /// 鍵盤總高度佔螢幕高度的比例（含工具列帶；不含系統在下方另加的地球／麥克風排）
    static let keyboardHeightRatio: CGFloat = 0.37
    /// 工具列帶（候選字）佔鍵盤總高的比例。候選字放大時加高這排，鍵區 0.37 × 0.866 跟原本 0.36 × 0.89 一樣大
    static let toolbarHeightRatio: CGFloat = 0.134

    // 鍵距：三星比 iOS 原生緊
    static let keyGap: CGFloat = 5
    static let rowGap: CGFloat = 7
    static let sideInset: CGFloat = 4
    static let keyCornerRadius: CGFloat = 7

    // 鍵帽字：三星字大
    static let keyFontSize: CGFloat = 26
    static let functionFontSize: CGFloat = 19
    static let hintFontSize: CGFloat = 10
    static let footFontSize: CGFloat = 11
    /// 聲調 ˇ ˋ ˊ ˙ 筆畫細，同字級在窄鍵上只剩一個點，放大加粗
    static let toneFontSize: CGFloat = 34
    static let previewFontSize: CGFloat = 40
    /// 候選字跟系統注音差不多大，比較好點，也不容易誤按到第一排的鍵
    static let candidateFontSize: CGFloat = 27
    static let iconPointSize: CGFloat = 20
    /// 候選列最右邊的展開鍵 ⌄
    static let expandIconPointSize: CGFloat = 24

    static let longPressSeconds: TimeInterval = 0.4

    // 往下拖收鍵盤：拖超過這距離就收；或放開時往下撥超過短距離、速度夠快也收。點鍵時手指滑不到這麼遠
    static let swipeDownDistance: CGFloat = 40
    static let flickDownDistance: CGFloat = 24
    /// 每秒幾 pt
    static let flickDownSpeed: CGFloat = 600
    /// 刪除鍵按住後的連刪間隔
    static let repeatInterval: TimeInterval = 0.08

    // 顏色：深色跟系統（或輸入框要求深色鍵盤時）切換

    /// 鍵盤底透明：iOS 26 會在第三方鍵盤上方和底部系統排畫自己的底色，擴充畫不到那裡；
    /// 自己塗底色會被框成一塊，所以整個鍵盤共用系統那層底色
    static let background = UIColor.clear
    // 鍵帽配合系統底色（淺色約 #E2E3E7）；深色時字鍵比功能鍵亮，功能鍵也要比系統底亮
    static let keyWhite = dynamic(light: .white, dark: rgb(0x5B5B5F))
    static let keyGray = dynamic(light: rgb(0xC0C4CC), dark: rgb(0x3B3B3E))
    static let keyPressed = dynamic(light: rgb(0xD3D6DC), dark: rgb(0x76767B))
    static let keyText = dynamic(light: .black, dark: .white)
    /// 長按提示小字：在白鍵與各分區底色上都要過 4.5:1
    static let hintText = dynamic(light: rgb(0x5E5E5E), dark: rgb(0xD8D8DC))
    /// 鍵盤頂端收鍵盤的拖曳條：淡一點、不搶眼（使用者 2026-11-02 要求），看得出有就好
    static let grabber = dynamic(light: rgb(0xAEB2BA), dark: rgb(0x636366))

    // 注音分區底色：介音 ㄧㄨㄩ 剛好排成中間一直欄，把聲母（左）與韻母（右）隔開
    static let keyMedial = dynamic(light: rgb(0xD3E3F8), dark: rgb(0x35557A))
    static let keyFinal = dynamic(light: rgb(0xFBE9D9), dark: rgb(0x5F4C40))
    /// 聲調鍵；英文常駐數字列也用這色，跟字母分開
    static let keyTone = dynamic(light: rgb(0xECEDF1), dark: rgb(0x4B4B4F))

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
