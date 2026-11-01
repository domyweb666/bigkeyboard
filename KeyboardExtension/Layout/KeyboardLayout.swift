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
    }

    let label: String
    let action: Action
    /// 長按送出的替代字；nil 表示這顆鍵沒有
    let alt: String?
    /// 相對寬度，1 = 一般鍵
    let width: CGFloat
    let isFunction: Bool
    /// SF Symbol 名稱；有的話鍵帽畫圖示而不是 label
    let icon: String?
    /// 鍵帽底部小字（空白鍵用來顯示目前語言）
    let foot: String?

    init(
        _ label: String,
        _ action: Action,
        alt: String? = nil,
        width: CGFloat = 1,
        function: Bool = false,
        icon: String? = nil,
        foot: String? = nil
    ) {
        self.label = label
        self.action = action
        self.alt = alt
        self.width = width
        isFunction = function
        self.icon = icon
        self.foot = foot
    }

    /// 長按時實際送出的字
    var altText: String? {
        alt
    }
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
}

// MARK: - 注音（標準排法，照三星截圖；右上角小字＝長按）

enum BopomofoLayout {
    private static func keys(_ symbols: [String], _ alts: [String?]) -> KeyRow {
        symbols.enumerated().map { i, s in
            KeySpec(s, .bopomofo(s), alt: i < alts.count ? alts[i] : nil)
        }
    }

    static let rows: [KeyRow] = [
        keys(
            ["ㄅ", "ㄉ", "ˇ", "ˋ", "ㄓ", "ˊ", "˙", "ㄚ", "ㄞ", "ㄢ", "ㄦ"],
            ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", nil]
        ),
        keys(
            ["ㄆ", "ㄊ", "ㄍ", "ㄐ", "ㄔ", "ㄗ", "ㄧ", "ㄛ", "ㄟ", "ㄣ"],
            ["+", "×", "÷", "=", "/", "_", "<", ">", "[", "]"]
        ),
        keys(
            ["ㄇ", "ㄋ", "ㄎ", "ㄑ", "ㄕ", "ㄘ", "ㄨ", "ㄜ", "ㄠ", "ㄤ"],
            ["!", "@", "#", "¥", "%", "&", "*", "(", ")", nil]
        ),
        keys(
            ["ㄈ", "ㄌ", "ㄏ", "ㄒ", "ㄖ", "ㄙ", "ㄩ", "ㄝ", "ㄡ", "ㄥ"],
            [nil, "-", "'", "\"", ":", ";", ",", "?", nil, nil]
        )
            + [FunctionKeys.backspace()],
        [
            KeySpec("符", .switchMode(.symbols1), width: 1.3, function: true),
            FunctionKeys.toEnglish,
            KeySpec("，", .text("，")),
            FunctionKeys.space(foot: "注音"),
            KeySpec("。", .text("。")),
            KeySpec("123", .switchMode(.numpad), width: 1.3, function: true),
            FunctionKeys.newline,
        ],
    ]
}

// MARK: - 英文（QWERTY＋常駐數字列，照三星截圖）

enum EnglishLayout {
    private static func letters(_ s: String, _ alts: [String]) -> KeyRow {
        Array(s).enumerated().map { i, c in
            KeySpec(String(c), .letter(String(c)), alt: i < alts.count ? alts[i] : nil)
        }
    }

    static let rows: [KeyRow] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map { KeySpec($0, .text($0)) },
        letters("qwertyuiop", ["+", "×", "÷", "=", "/", "_", "<", ">", "[", "]"]),
        letters("asdfghjkl", ["!", "@", "#", "$", "%", "&", "*", "(", ")"]),
        [KeySpec("⇧", .shift, width: 1.4, function: true, icon: "shift")]
            + letters("zxcvbnm", ["-", "'", "\"", ":", ";", ",", "?"])
            + [FunctionKeys.backspace(width: 1.4)],
        [
            KeySpec("!#1", .switchMode(.symbols1), width: 1.3, function: true),
            FunctionKeys.toBopomofo,
            KeySpec(",", .text(",")),
            FunctionKeys.space(foot: "English"),
            KeySpec(".", .text(".")),
            FunctionKeys.newline,
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
