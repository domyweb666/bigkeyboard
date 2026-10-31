import UIKit

/// 一顆鍵的資料。鍵位表是資料，不是程式。
struct KeySpec {
    enum Action {
        case bopomofo(String) // 送注音符號進引擎
        case text(String) // 直接送字到輸入框（送之前先把組字中的第一候選送出）
        case space
        case backspace
        case newline
        case placeholder(String) // 這片還沒實作的功能鍵，顯示灰鍵、按了沒反應
    }

    let label: String
    let action: Action
    /// 相對寬度，1 = 一般鍵
    let width: CGFloat
    let isFunction: Bool

    static func key(_ s: String) -> KeySpec {
        KeySpec(label: s, action: .bopomofo(s), width: 1, isFunction: false)
    }
}

typealias KeyRow = [KeySpec]

enum BopomofoLayout {
    /// 標準注音排法，照三星截圖
    static let rows: [KeyRow] = [
        ["ㄅ", "ㄉ", "ˇ", "ˋ", "ㄓ", "ˊ", "˙", "ㄚ", "ㄞ", "ㄢ", "ㄦ"].map(KeySpec.key),
        ["ㄆ", "ㄊ", "ㄍ", "ㄐ", "ㄔ", "ㄗ", "ㄧ", "ㄛ", "ㄟ", "ㄣ"].map(KeySpec.key),
        ["ㄇ", "ㄋ", "ㄎ", "ㄑ", "ㄕ", "ㄘ", "ㄨ", "ㄜ", "ㄠ", "ㄤ"].map(KeySpec.key),
        ["ㄈ", "ㄌ", "ㄏ", "ㄒ", "ㄖ", "ㄙ", "ㄩ", "ㄝ", "ㄡ", "ㄥ"].map(KeySpec.key)
            + [KeySpec(label: "⌫", action: .backspace, width: 1.2, isFunction: true)],
        [
            KeySpec(label: "符", action: .placeholder("符"), width: 1.3, isFunction: true),
            KeySpec(label: "🌐", action: .placeholder("🌐"), width: 1.3, isFunction: true),
            KeySpec(label: "，", action: .text("，"), width: 1, isFunction: false),
            KeySpec(label: "", action: .space, width: 3.4, isFunction: false),
            KeySpec(label: "。", action: .text("。"), width: 1, isFunction: false),
            KeySpec(label: "123", action: .placeholder("123"), width: 1.3, isFunction: true),
            KeySpec(label: "↵", action: .newline, width: 1.3, isFunction: true),
        ],
    ]
}
