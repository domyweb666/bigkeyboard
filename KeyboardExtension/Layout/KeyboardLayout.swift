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
        case toggleLanguage // 🌐：注音 ⇄ 英文
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

    init(_ label: String, _ action: Action, alt: String? = nil, width: CGFloat = 1, function: Bool = false) {
        self.label = label
        self.action = action
        self.alt = alt
        self.width = width
        isFunction = function
    }

    /// 長按時實際送出的字
    var altText: String? {
        alt
    }
}

typealias KeyRow = [KeySpec]

// MARK: - 共用的功能鍵

enum FunctionKeys {
    static let backspace = KeySpec("⌫", .backspace, width: 1.2, function: true)
    static let newline = KeySpec("↵", .newline, width: 1.3, function: true)
    static let globe = KeySpec("🌐", .toggleLanguage, width: 1.3, function: true)

    static func space(width: CGFloat = 3.4) -> KeySpec {
        KeySpec("", .space, width: width)
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
        keys(["ㄅ", "ㄉ", "ˇ", "ˋ", "ㄓ", "ˊ", "˙", "ㄚ", "ㄞ", "ㄢ", "ㄦ"],
            ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", nil]),
        keys(["ㄆ", "ㄊ", "ㄍ", "ㄐ", "ㄔ", "ㄗ", "ㄧ", "ㄛ", "ㄟ", "ㄣ"],
            ["+", "×", "÷", "=", "/", "_", "<", ">", "[", "]"]),
        keys(["ㄇ", "ㄋ", "ㄎ", "ㄑ", "ㄕ", "ㄘ", "ㄨ", "ㄜ", "ㄠ", "ㄤ"],
            ["!", "@", "#", "¥", "%", "&", "*", "(", ")", nil]),
        keys(["ㄈ", "ㄌ", "ㄏ", "ㄒ", "ㄖ", "ㄙ", "ㄩ", "ㄝ", "ㄡ", "ㄥ"],
            [nil, "-", "'", "\"", ":", ";", ",", "?", nil, nil])
            + [FunctionKeys.backspace],
        [
            KeySpec("符", .switchMode(.symbols1), width: 1.3, function: true),
            FunctionKeys.globe,
            KeySpec("，", .text("，")),
            FunctionKeys.space(),
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
        [KeySpec("⇧", .shift, width: 1.4, function: true)]
            + letters("zxcvbnm", ["-", "'", "\"", ":", ";", ",", "?"])
            + [KeySpec("⌫", .backspace, width: 1.4, function: true)],
        [
            KeySpec("!#1", .switchMode(.symbols1), width: 1.3, function: true),
            FunctionKeys.globe,
            KeySpec(",", .text(",")),
            FunctionKeys.space(),
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
            FunctionKeys.globe,
            KeySpec(chinese ? "，" : ",", .text(chinese ? "，" : ",")),
            FunctionKeys.space(width: 2.6),
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
                + [KeySpec("⌫", .backspace, width: 1.3, function: true)],
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
                + [KeySpec("⌫", .backspace, width: 1.3, function: true)],
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
            [f("_"), n("1"), n("2"), n("3"), KeySpec("⌫", .backspace, width: 1.2, function: true)],
            [f("@"), n("4"), n("5"), n("6"), KeySpec(".", .text("."), width: 1.2)],
            [f(":"), n("7"), n("8"), n("9"), KeySpec(",", .text(","), width: 1.2)],
            [
                KeySpec("符", .switchMode(.symbols1), width: 1.2, function: true),
                KeySpec(chinese ? "中文" : "ABC", .backToLanguage, width: 1.6, function: true),
                n("0"),
                KeySpec("", .space, width: 1.6),
                KeySpec("↵", .newline, width: 1.2, function: true),
            ],
        ]
    }
}
