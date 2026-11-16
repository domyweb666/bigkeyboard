import UIKit

/// 鍵盤的尺寸與配色常數。尺寸照三星截圖量、寫死；配色、字體、圓角照 App 裡選的主題（KeyboardTheme）。
enum SamsungTheme {
    /// 鍵盤總高度佔螢幕高度的比例（含工具列帶；不含系統在下方另加的地球／麥克風排）
    static let keyboardHeightRatio: CGFloat = 0.37
    /// 工具列帶（候選字）佔鍵盤總高的比例。候選字放大時加高這排，鍵區 0.37 × 0.866 跟原本 0.36 × 0.89 一樣大
    static let toolbarHeightRatio: CGFloat = 0.134

    // 鍵距：三星比 iOS 原生緊
    static let keyGap: CGFloat = 5
    static let rowGap: CGFloat = 7
    static let sideInset: CGFloat = 4

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
    /// 候選列右邊的展開鍵 ⌄
    static let expandIconPointSize: CGFloat = 24
    /// 候選列最右邊的收鍵盤鍵
    static let dismissIconPointSize: CGFloat = 21
    /// 候選列右邊的剪貼簿鍵
    static let clipboardIconPointSize: CGFloat = 20
    /// 展開鍵、收鍵盤鍵的寬（展開鍵排在收鍵盤鍵左邊，離開螢幕邊緣：邊緣的觸控會被系統延後或取消）
    static let barButtonWidth: CGFloat = 52

    /// 動態感應範圍：打了聲母後介音、韻母（打了介音後只剩韻母）多吃旁邊鍵這麼寬的邊；外觀不變
    static let likelyKeyTouchMargin: CGFloat = 10

    /// 落點往上修正：人按鍵習慣按在目標偏下方，算「離哪顆鍵最近」之前先把落點往上移這麼多 pt（原生鍵盤也這樣）。
    /// 真機調：覺得常按到上一排就調小，0 = 不修正
    static let touchLiftPoints: CGFloat = 3

    static let longPressSeconds: TimeInterval = 0.4
    /// 按下後移動不到這距離就放開，一律算按到這顆鍵（不管放開時在不在鍵上、觸控有沒有被系統取消）
    static let tapSlop: CGFloat = 20

    /// 刪除鍵按住後的連刪間隔
    static let repeatInterval: TimeInterval = 0.08
    /// 刪除鍵連刪這麼多下之後加速：改成一次刪一截（英文一個詞、中文最多幾個字，碰到標點停）。20 下 ≈ 按住 2 秒
    static let fastDeleteAfterRepeats = 20
    /// 加速後每幾下連刪間隔刪一截（3 × 0.08 秒：太快會來不及放手）
    static let fastDeleteEveryRepeats = 3
    /// 加速後中文一次最多刪幾個字
    static let fastDeleteMaxCharacters = 4
    /// 按鍵震動的力道（0～1，輕一點才像原生）
    static let keyHapticIntensity: CGFloat = 0.7

    // 按住空白鍵拖游標（手感參數，真機調）
    /// 左右拖這麼多 pt 移一個字（慢慢拖時）
    static let cursorPointsPerCharacter: CGFloat = 9
    /// 拖得比這快（pt／秒）開始加速：越快一次跳越多字
    static let cursorFastSpeed: CGFloat = 400
    /// 加速最多幾倍
    static let cursorMaxAcceleration: CGFloat = 3
    /// 上下拖這麼多 pt 跳一次（往上到這行開頭、往下到這行結尾）
    static let cursorPointsPerLine: CGFloat = 40
    /// 進入、離開觸控板時鍵上字淡出淡入的秒數
    static let cursorFadeSeconds: TimeInterval = 0.15

    // 顏色：照目前主題（KeyboardTheme），深色跟系統（或輸入框要求深色鍵盤時）切換

    /// 目前主題。鍵盤每次叫出來時重讀（KeyboardViewController.viewWillAppear）
    static var theme = KeyboardTheme.saved

    /// 鍵盤底透明：iOS 26 會在第三方鍵盤上方和底部系統排畫自己的底色，擴充畫不到那裡；
    /// 自己塗底色會被框成一塊，所以整個鍵盤共用系統那層底色
    static let background = UIColor.clear
    /// 鍵區的底：看起來透明，但全透明的地方系統不會把觸控送進來，鍵縫和空位會按了沒反應
    static let keyAreaBackground = UIColor(white: 0.5, alpha: 0.01)

    // 下面每個顏色畫的時候才照當下的主題與深淺色取值；每次取都是新物件，換主題後重新指定就會重畫

    static var keyWhite: UIColor {
        themed(\.key)
    }

    static var keyGray: UIColor {
        themed(\.function)
    }

    static var keyPressed: UIColor {
        themed(\.pressed)
    }

    static var keyText: UIColor {
        themed(\.text)
    }

    /// 長按提示小字：在字鍵與各分區底色上都要過 4.5:1
    static var hintText: UIColor {
        themed(\.hint)
    }

    // 注音分區底色：介音 ㄧㄨㄩ 剛好排成中間一直欄，把聲母（左）與韻母（右）隔開

    static var keyMedial: UIColor {
        themed(\.medial)
    }

    static var keyFinal: UIColor {
        themed(\.finals)
    }

    /// 聲調鍵；英文常駐數字列也用這色，跟字母分開
    static var keyTone: UIColor {
        themed(\.tone)
    }

    // 鍵盤外框用的產品色（剪貼簿面板的篩選、卡片上的標籤與圖釘、長按選單）：Domy 設計系統的鼠尾草綠。
    // 值抄自 domy-design 的 tokens.json（themes.sage、neutral），那邊改了這裡要跟著改。
    // 鍵盤擴充不載入 SwiftUI，所以不直接用 App 那份 DomyTokens.swift

    static let accent = brand(light: 0x4F6B57, dark: 0x9DC2A5)
    /// 壓在 accent 上的字
    static let onAccent = brand(light: 0xFFFFFF, dark: 0x12251A)
    /// 產品色的字（卡片上的標籤、勾選的標籤）
    static let accentStrong = brand(light: 0x3F5746, dark: 0xBFD9C4)
    /// 產品色淡底（勾選的標籤）
    static let accentSoft = brand(light: 0xE3ECE5, dark: 0x22322A)
    static let destructive = brand(light: 0xC4372C, dark: 0xFF6B5E)
    static let destructiveSoft = brand(light: 0xFBEDEB, dark: 0x3A1E1B)

    private static func brand(light: Int, dark: Int) -> UIColor {
        UIColor { trait in
            KeyboardTheme.color(trait.userInterfaceStyle == .dark ? dark : light)
        }
    }

    static var keyCornerRadius: CGFloat {
        theme.cornerRadius
    }

    /// 鍵帽、候選字、預覽泡泡的字
    static func keyFont(ofSize size: CGFloat, bold: Bool = false) -> UIFont {
        theme.font(ofSize: size, bold: bold)
    }

    private static func themed(_ color: KeyPath<KeyboardTheme.Colors, Int>) -> UIColor {
        UIColor { trait in
            let colors = trait.userInterfaceStyle == .dark ? theme.dark : theme.light
            return KeyboardTheme.color(colors[keyPath: color])
        }
    }

    static func keyboardHeight(for screen: UIScreen) -> CGFloat {
        (screen.bounds.height * keyboardHeightRatio).rounded()
    }
}
