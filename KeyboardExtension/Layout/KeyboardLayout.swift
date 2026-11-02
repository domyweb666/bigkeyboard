import UIKit

/// 鍵盤目前在哪一張鍵面
enum KeyboardMode: String {
    case bopomofo
    case english
    case symbols1
    case symbols2
    case numpad

    /// 符號頁與數字鍵盤是「暫時離開」語言鍵面，要記得從哪個語言來的
    var isLanguage: Bool {
        self == .bopomofo || self == .english
    }
}

/// 一顆鍵的資料。鍵位表是資料，不是程式。
struct KeySpec {
    enum Action {
        case bopomofo(String) // 送注音符號進引擎
        case letter(String) // 英文字母（小寫；shift 時轉大寫）
        case text(String) // 直接送字到輸入框
        case space
        case backspace
        case newline
        case shift
        case toggleLanguage // 注音 ⇄ 英文（鍵上寫的是要去的那個語言；系統底排的地球是切換鍵盤，不能跟它用同一個圖示）
        case switchMode(KeyboardMode) // 去符號頁／數字鍵盤
        case backToLanguage // 從符號頁／數字鍵盤回到原本的語言鍵面
        case spacer // 不是鍵：只佔寬度，把一排左右錯開半顆（跟三星一樣）
    }

    let label: String
    let action: Action
    /// 相對寬度，1 = 一般鍵
    let width: CGFloat
    let isFunction: Bool
    /// SF Symbol 名稱；有的話鍵帽畫圖示而不是 label
    let icon: String?
    /// 鍵帽底部小字（空白鍵用來顯示目前語言）
    let foot: String?
    /// 長按改做另一個動作（不送字）；右上角小字顯示 longHint
    let longAction: Action?
    let longHint: String?
    /// 鍵帽底色；nil 照字鍵／功能鍵的預設色
    let tint: UIColor?
    /// 聲調這類筆畫細的符號：放大加粗
    let isTone: Bool
    /// 注音鍵屬於哪一類（動態鍵寬用）；不是注音鍵為 nil
    let zhuyin: ZhuyinGroup?

    enum ZhuyinGroup {
        case consonant
        case medial
        case final
        case tone
    }

    init(
        _ label: String,
        _ action: Action,
        width: CGFloat = 1,
        function: Bool = false,
        icon: String? = nil,
        foot: String? = nil,
        longAction: Action? = nil,
        longHint: String? = nil,
        tint: UIColor? = nil,
        isTone: Bool = false,
        zhuyin: ZhuyinGroup? = nil
    ) {
        self.label = label
        self.action = action
        self.width = width
        isFunction = function
        self.icon = icon
        self.foot = foot
        self.longAction = longAction
        self.longHint = longHint
        self.tint = tint
        self.isTone = isTone
        self.zhuyin = zhuyin
    }

    /// 半顆鍵寬的空位
    static let halfGap = KeySpec("", .spacer, width: 0.5)
}

typealias KeyRow = [KeySpec]

// MARK: - 共用的功能鍵

enum FunctionKeys {
    static func backspace(width: CGFloat = 1.2) -> KeySpec {
        KeySpec("⌫", .backspace, width: width, function: true, icon: "delete.left")
    }

    static let newline = KeySpec("↵", .newline, width: 1.3, function: true, icon: "return")
    static let toEnglish = KeySpec("ABC", .toggleLanguage, width: 1.3, function: true)
    static let toBopomofo = KeySpec("注音", .toggleLanguage, width: 1.3, function: true)

    static func space(width: CGFloat = 3.4, foot: String? = nil) -> KeySpec {
        KeySpec("", .space, width: width, foot: foot)
    }

    // 語言鍵面的底排：數字鍵盤收進符號鍵的長按，空白鍵與換行鍵讓出來的寬度
    static let languageSpace: CGFloat = 4.3
    static let languageNewline = KeySpec("↵", .newline, width: 1.6, function: true, icon: "return")

    static func symbols(_ label: String) -> KeySpec {
        KeySpec(
            label,
            .switchMode(.symbols1),
            width: 1.3,
            function: true,
            longAction: .switchMode(.numpad),
            longHint: "123"
        )
    }
}

// MARK: - 注音（標準排法，照三星截圖：第 2、3 排左右各縮半顆，⌫ 跟字鍵一樣寬）

enum BopomofoLayout {
    private static let tones: Set<String> = ["ˇ", "ˋ", "ˊ", "˙"]
    private static let medials: Set<String> = ["ㄧ", "ㄨ", "ㄩ"]
    private static let finals: Set<String> = [
        "ㄚ", "ㄛ", "ㄜ", "ㄝ", "ㄞ", "ㄟ", "ㄠ", "ㄡ", "ㄢ", "ㄣ", "ㄤ", "ㄥ", "ㄦ",
    ]

    /// 聲母白、介音淡藍、韻母淡暖、聲調淡灰
    private static func tint(_ s: String) -> UIColor? {
        if tones.contains(s) {
            return SamsungTheme.keyTone
        }
        if medials.contains(s) {
            return SamsungTheme.keyMedial
        }
        if finals.contains(s) {
            return SamsungTheme.keyFinal
        }
        return nil
    }

    private static func group(_ s: String) -> KeySpec.ZhuyinGroup {
        if tones.contains(s) {
            return .tone
        }
        if medials.contains(s) {
            return .medial
        }
        return finals.contains(s) ? .final : .consonant
    }

    private static func keys(_ symbols: [String]) -> KeyRow {
        symbols.map { s in
            KeySpec(s, .bopomofo(s), tint: tint(s), isTone: tones.contains(s), zhuyin: group(s))
        }
    }

    /// 左右各留半顆空位：鍵跟第一排一樣寬，位置錯開半顆
    private static func staggered(_ symbols: [String]) -> KeyRow {
        [KeySpec.halfGap] + keys(symbols) + [KeySpec.halfGap]
    }

    static let rows: [KeyRow] = [
        keys(["ㄅ", "ㄉ", "ˇ", "ˋ", "ㄓ", "ˊ", "˙", "ㄚ", "ㄞ", "ㄢ", "ㄦ"]),
        staggered(["ㄆ", "ㄊ", "ㄍ", "ㄐ", "ㄔ", "ㄗ", "ㄧ", "ㄛ", "ㄟ", "ㄣ"]),
        staggered(["ㄇ", "ㄋ", "ㄎ", "ㄑ", "ㄕ", "ㄘ", "ㄨ", "ㄜ", "ㄠ", "ㄤ"]),
        keys(["ㄈ", "ㄌ", "ㄏ", "ㄒ", "ㄖ", "ㄙ", "ㄩ", "ㄝ", "ㄡ", "ㄥ"])
            + [FunctionKeys.backspace(width: 1)],
        [
            FunctionKeys.symbols("符"),
            FunctionKeys.toEnglish,
            KeySpec("，", .text("，")),
            FunctionKeys.space(width: FunctionKeys.languageSpace, foot: "注音"),
            KeySpec("。", .text("。")),
            FunctionKeys.languageNewline,
        ],
    ]
}

// MARK: - 英文（QWERTY＋常駐數字列，照三星截圖；a 那排左右各縮半顆）

enum EnglishLayout {
    private static func letters(_ s: String) -> KeyRow {
        s.map { KeySpec(String($0), .letter(String($0))) }
    }

    static let rows: [KeyRow] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map {
            KeySpec($0, .text($0), tint: SamsungTheme.keyTone)
        },
        letters("qwertyuiop"),
        [KeySpec.halfGap] + letters("asdfghjkl") + [KeySpec.halfGap],
        [KeySpec("⇧", .shift, width: 1.4, function: true, icon: "shift")]
            + letters("zxcvbnm")
            + [FunctionKeys.backspace(width: 1.4)],
        [
            FunctionKeys.symbols("!#1"),
            FunctionKeys.toBopomofo,
            KeySpec(",", .text(",")),
            FunctionKeys.space(width: FunctionKeys.languageSpace, foot: "English"),
            KeySpec(".", .text(".")),
            FunctionKeys.languageNewline,
        ],
    ]
}

// MARK: - 符號頁 1/2、2/2（照三星截圖；中文模式用全形標點）

enum SymbolLayout {
    private static func texts(_ items: [String]) -> KeyRow {
        items.map { KeySpec($0, .text($0)) }
    }

    private static func bottom(chinese: Bool) -> KeyRow {
        [
            KeySpec(chinese ? "中文" : "ABC", .backToLanguage, width: 1.3, function: true),
            KeySpec(chinese ? "，" : ",", .text(chinese ? "，" : ",")),
            FunctionKeys.space(width: 3.9),
            KeySpec(chinese ? "。" : ".", .text(chinese ? "。" : ".")),
            KeySpec("123", .switchMode(.numpad), width: 1.3, function: true),
            FunctionKeys.newline,
        ]
    }

    static func page1(chinese: Bool) -> [KeyRow] {
        [
            texts(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]),
            texts(["+", "×", "÷", "=", "/", "_", "<", ">", "[", "]"]),
            texts(["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"]),
            [KeySpec("1/2", .switchMode(.symbols2), width: 1.3, function: true)]
                + texts(chinese
                    ? ["-", "‘’", "“”", "：", "；", "，", "？"]
                    : ["-", "'", "\"", ":", ";", ",", "?"])
                + [FunctionKeys.backspace(width: 1.3)],
            bottom(chinese: chinese),
        ]
    }

    static func page2(chinese: Bool) -> [KeyRow] {
        [
            texts(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]),
            texts(["`", "~", "、", "|", "{", "}", "€", "£", "¥", "₩"]),
            texts(["°", "•", "○", "●", "□", "■", "♠", "♡", "◇", "♣"]),
            [KeySpec("2/2", .switchMode(.symbols1), width: 1.3, function: true)]
                + texts(["☆", "▪", "¤", "《", "》", "……", "·"])
                + [FunctionKeys.backspace(width: 1.3)],
            bottom(chinese: chinese),
        ]
    }
}

// MARK: - 數字鍵盤 4×4（照三星截圖）

enum NumpadLayout {
    static func rows(chinese: Bool) -> [KeyRow] {
        let f: (String) -> KeySpec = { KeySpec($0, .text($0), width: 1.2, function: true) }
        let n: (String) -> KeySpec = { KeySpec($0, .text($0), width: 1.6) }
        return [
            [f("_"), n("1"), n("2"), n("3"), FunctionKeys.backspace()],
            [f("@"), n("4"), n("5"), n("6"), KeySpec(".", .text("."), width: 1.2)],
            [f(":"), n("7"), n("8"), n("9"), KeySpec(",", .text(","), width: 1.2)],
            [
                KeySpec("符", .switchMode(.symbols1), width: 1.2, function: true),
                KeySpec(chinese ? "中文" : "ABC", .backToLanguage, width: 1.6, function: true),
                n("0"),
                KeySpec("", .space, width: 1.6),
                KeySpec("↵", .newline, width: 1.2, function: true, icon: "return"),
            ],
        ]
    }
}
