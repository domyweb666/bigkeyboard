import UIKit

/// 鍵盤主題：鍵帽配色、字體、圓角。在豆鍵 App 裡選，存進 App 與鍵盤共用的設定，鍵盤每次叫出來時讀。
/// 鍵位、尺寸、手感不跟著主題變。注音分區（聲母、介音、韻母、聲調）每款都要用深淺分得開
enum KeyboardTheme: String, CaseIterable, Identifiable {
    case gray
    case edamame
    case soymilk
    case redBean
    case blackBean
    case coffee
    case butterfly
    case jellyBean

    /// 一種深淺模式的配色
    struct Colors {
        let key: Int
        let medial: Int
        let finals: Int
        let tone: Int
        let function: Int
        let text: Int
        let hint: Int
        let pressed: Int

        /// 依序：字鍵 介音 韻母 聲調 功能鍵 鍵帽字 小字 按下，16 進位色碼以空白隔開
        init(_ hexes: String) {
            // 補 0 到至少 8 個，少寫了也不會超出範圍
            let v = hexes.split(separator: " ").map { Int($0, radix: 16) ?? 0 } + Array(repeating: 0, count: 8)
            key = v[0]
            medial = v[1]
            finals = v[2]
            tone = v[3]
            function = v[4]
            text = v[5]
            hint = v[6]
            pressed = v[7]
        }
    }

    var id: String {
        rawValue
    }

    /// App 內購的產品 ID（非消耗性，價格從 Apple 拿）；冷灰免費是 nil。要跟 App Store Connect 建的一字不差
    var productID: String? {
        self == .gray ? nil : "org.domyweb.bigkeyboard.theme." + rawValue.lowercased()
    }

    var name: String {
        switch self {
        case .gray: "冷灰"
        case .edamame: "毛豆"
        case .soymilk: "豆漿"
        case .redBean: "紅豆"
        case .blackBean: "黑豆"
        case .coffee: "咖啡豆"
        case .butterfly: "蝶豆花"
        case .jellyBean: "糖豆"
        }
    }

    var summary: String {
        switch self {
        case .gray: "預設，跟系統鍵盤底色搭的冷灰。"
        case .edamame: "嫩綠豆莢配淡黃豆仁，圓一點的鍵帽。"
        case .soymilk: "米白底、明體鍵帽字，像鉛字。"
        case .redBean: "紅豆沙和粉色，楷書鍵帽字。"
        case .blackBean: "深色模式最好看：黑鍵、琥珀韻母。"
        case .coffee: "拿鐵到深焙的咖啡色階。"
        case .butterfly: "介音藍、韻母淡紫，像蝶豆花茶。"
        case .jellyBean: "糖果色、大圓角、粗體字。"
        }
    }

    var light: Colors {
        switch self {
        case .gray: Colors("FFFFFF D3E3F8 FBE9D9 ECEDF1 C0C4CC 000000 5E5E5E D3D6DC")
        case .edamame: Colors("FBFCF4 CDE5B4 F0EAC2 E4E9D9 A8BD91 1E2B12 55623F D5DEC8")
        case .soymilk: Colors("FFFDF8 E8DCC6 F6EEDF EFEAE1 D3C5AE 3A2E22 75664F E3DACB")
        case .redBean: Colors("FFF8F5 F4D2CF E8C3A3 F1E4DF C88C82 3A1411 7D4A43 EBD5CF")
        case .blackBean: Colors("F5F3EF CBE0DC F1DCB2 E5E2DC 9C988F 141414 5A5750 D6D3CC")
        case .coffee: Colors("FBF6F0 D8C2AA F1E1CA ECE4D9 A5876B 2A1C11 6E5641 E2D6C7")
        case .butterfly: Colors("FBFBFF B7C6F7 EBDDF8 ECECF7 A7A3D8 1C1A4A 55528A DCDCF0")
        case .jellyBean: Colors("FFFFFF 8FD0F8 FFD3E3 FFF0A8 B6A2F2 2A2140 6A5E86 E6E0F5")
        }
    }

    var dark: Colors {
        switch self {
        case .gray: Colors("5B5B5F 35557A 5F4C40 4B4B4F 3B3B3E FFFFFF D8D8DC 76767B")
        case .edamame: Colors("525E47 2F5A22 77703A 3A4133 283022 F1F7E6 D3DEC4 6E7A62")
        case .soymilk: Colors("524A40 6A5C47 3F3A33 39352F 2E2A25 F6EEE2 D7CBB8 6F665A")
        case .redBean: Colors("5C3734 8A3F3D 6E4C33 46302D 2F1E1C FFF0EB E6C7C1 7A504C")
        case .blackBean: Colors("1E1E20 17423F 4F3A10 262628 121213 F2EDE3 BDB6A8 3A3A3D")
        case .coffee: Colors("4E3D31 73543B 5E4B2C 3A2E25 261C16 F7ECDF D6C3AE 6A574A")
        case .butterfly: Colors("34325A 2E43A0 7A52B3 29274B 1C1A3A F1EEFF C9C4EE 4F4C7E")
        case .jellyBean: Colors("3B3552 1E6390 9A3A6B 6E5A10 2B2442 FFFFFF D3CCEA 575073")
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .gray: 7
        case .edamame: 12
        case .soymilk: 4
        case .redBean: 9
        case .blackBean: 6
        case .coffee, .butterfly: 10
        case .jellyBean: 16
        }
    }

    /// 主題字體檔，放在鍵盤擴充的 Resources/Fonts（擴充的 Info.plist 用 UIAppFonts 載入；App 從擴充裡借來註冊）
    static let fontFiles = ["NotoSerifTC-Medium.otf", "LXGWWenKaiTC-Regular.ttf"]

    /// 鍵帽字體；nil 用系統字
    private var fontName: String? {
        switch self {
        case .soymilk: "NotoSerifTC-Medium"
        case .redBean: "LXGWWenKaiTC-Regular"
        default: nil
        }
    }

    private var weight: UIFont.Weight {
        switch self {
        case .gray, .soymilk, .redBean: .regular
        case .edamame, .blackBean, .coffee, .butterfly: .medium
        case .jellyBean: .bold
        }
    }

    /// 鍵帽、候選字、預覽泡泡用的字。字體載入失敗時退回系統字
    func font(ofSize size: CGFloat, bold: Bool = false) -> UIFont {
        if let fontName, let font = UIFont(name: fontName, size: size) {
            return font
        }
        return .systemFont(ofSize: size, weight: bold ? .bold : weight)
    }

    static func color(_ hex: Int) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    private static let storageKey = "keyboardTheme"
    private static let defaults = UserDefaults(suiteName: UserDictionary.groupID)

    /// 目前選的主題；沒選過是冷灰
    static var saved: KeyboardTheme {
        defaults?.string(forKey: storageKey).flatMap(KeyboardTheme.init(rawValue:)) ?? .gray
    }

    func save() {
        Self.defaults?.set(rawValue, forKey: Self.storageKey)
    }
}
